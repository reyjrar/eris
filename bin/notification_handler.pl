#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use YAML;
use MIME::Lite;
use DBI;
use Data::Dumper;

#sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE qw(
    Component::Cron
    Component::Daemon
    Component::Logger
);

use lib "$FindBin::Bin/../lib";

use eris::schema;

my $ETC = "$FindBin::Bin/../etc";
my $CFG = YAML::LoadFile( qq{$ETC/eris.cfg} );

#------------------------------------------------------------------------#
# Session Creation
#------------------------------------------------------------------------#
#POE::Component::Daemon->spawn( detach => 1, babysit => 600, max_children => 5 );

POE::Session->create(
    inline_states => {
            _start          => \&main_start,
            _stop           => \&main_stop,
            log             => \&log_wrapper,
            connect_db      => \&main_connect_db,

            queue_build     => \&queue_build,
            queue_process   => \&queue_process,

            orig_user_email => \&orig_user_email,
            orig_admin_email => \&orig_admin_email,

            summary_user_email => \&summary_user_email,
            summary_admin_email => \&summary_admin_email,

            send_email      => \&send_email,
    },
);

# Start the Kernel!
POE::Kernel->run();

#------------------------------------------------------------------------#
# Main Session
#------------------------------------------------------------------------#
sub main_start {
    my ($kernel,$heap) = @_[KERNEL,HEAP];

    # Alias our session for maintainable dispatch
    $kernel->alias_set('main');

    # Enable Logging:
    POE::Component::Logger->spawn(
        Alias   => 'logger',
        ConfigFile => qq{$ETC/logging.conf},
    );

    $kernel->yield( 'log' => 'notice' =>  qq{$0 starting up .} );

    # Connect to the Database
    $kernel->yield( 'connect_db' );

    # Every 10 Minutes, check the database.
    #POE::Component::Cron->from_cron('*/10 * * * *' => main => 'connect_db');

    # Every Hour, build the queue
    #POE::Component::Cron->from_cron('15 * * * *' => main => 'queue_build');

    # Queue is processed daily at 6:45 am
    #POE::Component::Cron->from_cron('45 6 * * *' => main => 'queue_process');
    $kernel->yield('queue_build');
    $kernel->yield('queue_process');
}

sub main_stop {
    my ($kernel) = $_[KERNEL];
    $kernel->yield('log' => 'notice' => qq{$0 stopping});
}

#------------------------------------------------------------------------#
# Build the Queue
sub queue_build {
    my ($kernel,$heap) = @_[KERNEL,HEAP];

    $kernel->yield('connect_db');
    return unless $heap->{db_ok};

    # Prepared SQL Statements
    my %SQL = (
        known_sel   => q{
            select
                case
                    when src_user_id is not null then src_user_id
                    else dst_user_id
                end as user_id,
                count(1) as events,
                min(event_ts) as first_ts,
                max(event_ts) as last_ts
            from security_events se
                inner join security_signatures sig on se.sig_id = sig.sig_id
            where ( src_user_id is not null or dst_user_id is not null )
                and sig.evt_type_id = ?
                and event_ts > ?
            group by case when src_user_id is not null then src_user_id
                    else dst_user_id end
        },
        user_ntf_sel => q{
            select queue_no from
                notification_queue
            where to_user_id = ?
                and notification_id = ?
                and expire_ts > NOW()
        },

    );
    my %STH = ();
    foreach my $s (keys %SQL) {
        $STH{$s} = $heap->{dbh}->prepare( $SQL{$s} );
    }

    # Result Set of all Active Notifications
    my $ntf_rs = $heap->{model}->resultset('notification')->search(
        { is_enabled => 'true' },
        { prefetch => [ qw(event_type notify_admins) ]}
    );

    # Go through each notification
    while( my $ntf = $ntf_rs->next ) {
        my $evt_rs = $STH{known_sel}->execute( $ntf->evt_type_id, $ntf->last_interval_ts );
        while ( my $evt = $STH{known_sel}->fetchrow_hashref ) {
            next unless $evt->{events} >= $ntf->min_events_trigger;
            my $qobj = undef;
            my $rc = $STH{user_ntf_sel}->execute( $evt->{user_id}, $ntf->notification_id );
            if( defined $rc && $STH{user_ntf_sel}->rows ) {
                my ( $qid ) = $STH{user_ntf_sel}->fetchrow_array();
                $qobj = $heap->{model}->resultset('notification::queue')->find( $qid );
            }
            else {
                $qobj = $heap->{model}->resultset('notification::queue')->create(
                    {
                        notification_id => $ntf->notification_id,
                        to_user_id      => $evt->{user_id},
                        first_ts        => $evt->{first_ts}
                    }
                );
            }
            $qobj->last_ts( $evt->{last_ts} );
            $qobj->events( $evt->{events} );
            $qobj->update();
        }
    }
}

#------------------------------------------------------------------------#
# Process the Queue
sub queue_process {
    my ($kernel,$heap) = @_[KERNEL,HEAP];

    $kernel->yield('connect_db');
    return unless $heap->{db_ok};
    # Prepared SQL Statements
    my %SQL = (
        orig_email_select => q{
            select queue_no from notification_queue
            where notification_id = ?
                and orig_email_id is null
                and first_ts > ?
        },
        summary_email_select => q{
            select queue_no from notification_queue
                where notification_id = ?
                and first_ts > ?
        },
    );
    my %STH = ();
    foreach my $s (keys %SQL) {
        $STH{$s} = $heap->{dbh}->prepare( $SQL{$s} );
    }
    # Load Origination Events
    my $orig_rs = $heap->{model}->resultset('notification')->search(
        { is_enabled => 'true', -OR => { orig_admin_alert => 'true', orig_user_alert => 'true' } },
    );
    # Process Origination Events
    while( my $ntf = $orig_rs->next ) {
        $STH{orig_email_select}->execute( $ntf->notification_id, $ntf->last_interval_ts );
        while( my ($qid) = $STH{orig_email_select}->fetchrow_array ) {
            # Retrieve the Queue Object
            my $queue = $heap->{model}->resultset('notification::queue')->find( $qid,
                { prefetch => 'to_user' } );
            # Send the Necessary Alerts
            if( $ntf->orig_user_alert ) {
                $kernel->yield( 'orig_user_email', $ntf, $queue );
            }
            if( $ntf->orig_admin_alert ) {
                $kernel->yield( 'orig_admin_email', $ntf, $queue );
            }
        }
    }
    # Load Summary Events
    my $summ_rs = $heap->{model}->resultset('notification')->search(
        { 'is_enabled' => 'true', notification_interval => \q{< NOW() - last_interval_ts}  }
    );
    # Process Summary Events
    while( my $ntf = $summ_rs->next ) {
        # Retrieve Queued Events
        my @details = ();
        $STH{summary_email_select}->execute( $ntf->notification_id, $ntf->last_interval_ts );
        while( my( $qid ) = $STH{summary_email_select}->fetchrow_array ) {
            my $queue = $heap->{model}->resultset('notification::queue')->find( $qid,
                { prefetch => 'to_user' } );
            # Send User Alerts
            if( $ntf->summary_user_alert ) {
                $kernel->yield( 'summary_user_email', $ntf, $queue );
            }
            # Send Admin Alerts
            if( $ntf->summary_admin_alert ) {
                push @details, {
                    events      => $queue->events,
                    username    => $queue->to_user->username,
                    first_ts    => $queue->first_ts->strftime('%F %T'),
                    last_ts     => $queue->last_ts->strftime('%F %T'),
                };
            }
        }
        $kernel->yield( 'summary_admin_email', $ntf, \@details ) if @details;

        $ntf->last_interval_ts(\q{NOW()});
        $ntf->update;
    }
}

#------------------------------------------------------------------------#
# Origination User Alerts
sub orig_user_email {
    my ($kernel,$heap,$ntf,$queue) = @_[KERNEL,HEAP,ARG0,ARG1];

    # Body and Subject Templates
    my $body = $ntf->orig_user_message;
    my $subject = $ntf->orig_user_subject;

    # Message with no body is useless, skip!
    if( !length $body || !length $subject ) {
        return;
    }


    my $email_rec = $heap->{model}->resultset('notification::email')->create(
        {
            notification_id => $ntf->notification_id,
            user_id         => $queue->to_user_id,
            email_type      => 'origination',
            email_subject   => $subject,
            email_message   => $body,
        },
    );
    $email_rec->update();

    my %VARS = (
        TYPE        => $ntf->event_type->name,
        USERNAME    => $queue->to_user->username,
        DISPLAYNAME => $queue->to_user->display_name,
        EMAIL       => $queue->to_user->email,
        EVENTS      => $queue->events,
        FIRST_TS    => $queue->first_ts->strftime('%F %T'),
        DETAILS     => '',
        ACK_CODE    => $email_rec->ack_code,
    );

    $body =~ s/\#\#([\w\d]+)\#\#/$VARS{$1}/meg;
    $subject =~ s/\#\#([\w\d]+)\#\#/$VARS{$1}/meg;

    my %opts = (
            to  => 'lhotskyb@mail.nih.gov',
            subject => $subject,
            from => $ntf->alert_from_address
    );

    $email_rec->email_subject( $subject );
    $email_rec->email_message( $body );
    $email_rec->update;

    $queue->orig_email_id( $email_rec->email_id );
    $queue->update;

    $kernel->yield( 'send_email' => \%opts => $body );
}

#------------------------------------------------------------------------#
# Origination Admin Alerts
sub orig_admin_email {
    my ($kernel,$heap,$ntf,$queue) = @_[KERNEL,HEAP,ARG0,ARG1];

    # Body and Subject Templates
    my $body = $ntf->orig_admin_message;
    my $subject = $ntf->orig_admin_subject;

    # Message with no body is useless, skip!
    if( !length $body || !length $subject ) {
        return;
    }

    my $DETAILS = <<"   EOF";
    New ##TYPE## Events from ##USERNAME##

     - ##EVENTS## events since ##FIRST_TS##

    ##EMAIL_INFO##

    --
    eris notifications
    EOF
    $DETAILS =~ s/^\t//mg;

    $body =~ s/##DETAILS##/$DETAILS/m;

    my @admins = map { $_->email } $ntf->admins;

    my $email = $queue->orig_email();
    my $EMAILINFO = ref $email
            ?   'Email sent to ' . $email->rcpt->email . ' at ' . $email->sent_ts->strftime('%F %T')
            : 'Origination Email not sent.';
    $EMAILINFO .= qq{\nAdministrators: } . join(', ', @admins);

    my %VARS = (
        TYPE        => $ntf->event_type->name,
        USERNAME    => $queue->to_user->username,
        DISPLAYNAME => $queue->to_user->display_name,
        EMAIL       => $queue->to_user->email,
        EVENTS      => $queue->events,
        FIRST_TS    => $queue->first_ts->strftime('%F %T'),
        LAST_TS     => $queue->last_ts->strftime('%F %T'),
        EMAIL_INFO  => $EMAILINFO,
    );

    $body =~ s/\#\#([\w\d]+)\#\#/$VARS{$1}/meg;
    $subject =~ s/\#\#([\w\d]+)\#\#/$VARS{$1}/meg;


    my $to = shift @admins;
    my %opts = (
            to  => $to,
            cc  => \@admins,
            subject => $subject,
            from => $ntf->alert_from_address
    );

    $kernel->yield( 'send_email' => \%opts => $body );
}

#------------------------------------------------------------------------#
# Email Handing Functionality
sub send_email {
    my ($kernel,$heap,$opts,$body) = @_[KERNEL,HEAP,ARG0,ARG1];

    my $msg = MIME::Lite->new(
        From    => $opts->{from},
        To      => $opts->{to},
        Cc      => exists $opts->{cc} ? $opts->{cc} : undef,
        Subject => $opts->{subject},
        Type    => 'TEXT',
    );
    my %headers = (
            'X-Automation'              => 'true',
            'X-Automation-Function'     => 'eris-notification',
            'X-Automation-Program'      => $0,
    );
    while ( my ($k,$v) = each %headers ) {
        $msg->add($k,$v);
    }

    $msg->data( $body );
    $msg->scrub;
    $msg->send;
    $kernel->yield('log' => 'notice', qq{Email sent to $opts->{to}  ($opts->{subject})} );
}

#------------------------------------------------------------------------#
# Connect to database, setup model
sub main_connect_db {
    my ($kernel,$heap) = @_[KERNEL,HEAP];

    $heap->{db_ok} = 0;

    if( defined $heap->{dbh} && $heap->{dbh}->ping) {
        $heap->{db_ok} = 1;
    }
    else {
        eval {
            # Connect to the database, use a custom Error Handler
            $heap->{dbh} = DBI->connect( $CFG->{db_dsn}, $CFG->{db_user}, $CFG->{db_pass},
                {
                    RaiseError => 0, PrintError => 0,
                    HandleError => sub {
                        $kernel->yield( 'log' => 'warning' => 'DB ERROR: ' . shift );
                    }
                }
            );
            # Instantiate the Model
            $heap->{model} = eris::schema->connect( sub { $heap->{dbh} } );
        };
        if( my $error = $@ ) {
            $kernel->yield( 'log' => 'error' => qq{Database Setup Failure: $@} );
        }
        else {
            $heap->{db_ok} = 1;
        }
    }

    return;
}

#------------------------------------------------------------------------#
# Wrap all the log calls in the function of this script
sub log_wrapper {
    my ($kernel,$level,$message) = @_[KERNEL,ARG0,ARG1];

    $kernel->post( 'logger' => $level => q{(notification_handler)} . $message );
}
