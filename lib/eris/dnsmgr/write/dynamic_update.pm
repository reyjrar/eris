package eris::dnsmgr::write::dynamic_update;

use strict;
use warnings;

use CHI;
use Net::DNS;
use Time::HiRes;
use POE;

=head1 NAME

eris::dnsmgr::write::dynamic_update - Network DNS Updates

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

POE session for integration with the eris DNS Management engine.

    use eris::dnsmgr::write::dynamic_update;

    my $eris_sess_id = eris::dnsmgr::write::dynamic_update->spawn(
            autoflush       => 1,                       # default
            zone            => 'test.example.com',      # REQUIRED
            server          => 'ns.test.example.com',   # REQUIRED
            interval        => 180                      # default
            alias_prefix    => 'ddns',                  # default
            cache_dir       => '/tmp/dnsmgr/dynamic_update' # default
            log_sid         => 'log',                   # default
            key_name        => undef,                   # default
            key             => undef,                   # default
    );
    ...
    POE::Kernel->run();

=head1 EXPORT

eris::dnsmgr::write::dynamic_update does not export any symbols.

=head1 FUNCTIONS

=head2 spawn

Creates the POE::Session for the DNS Updater

Parameters:

    autoflush       => 1,                       # default
    zone            => 'test.example.com',      # REQUIRED
    server          => 'ns.test.example.com',   # REQUIRED
    interval        => 180                      # default
    alias_prefix    => 'ddns',                  # default
    cache_dir       => '/tmp/dnsmgr/dynamic_update', # default
    log_sid         => 'log'                    # default
    key_name        => undef,                   # default
    key             => undef,                   # default

=cut


sub spawn {
    my $type = shift;

    #
    # Param Setup
    my %args = (
        autoflush           => 1,
        alias_prefix        => 'ddns_',
        cache_dir           => '/tmp/dnsmgr/dynamic_update',
        interval            => undef,
        log_sid             => 'log',
        key_name            => undef,
        key                 => undef,
        @_
    );

    # Validation
    my @required = qw( zone server );
    foreach my $p (@required) {
        die "__PACAKGE__ requires parameter $p to be set!\n" unless defined $args{$p};
    }

    #------------------------------------------------------------------------#
    # Server
    my $session_id = POE::Session->create(
        inline_states       => {
            _start          => sub {
                    my ($kernel,$heap) = @_[KERNEL,HEAP];

                    $kernel->yield('build', \%args);
            },
            _stop           => sub { },

            build           => \&ddns_build,
            flush_queue     => \&ddns_flush_queue,
            queue_update    => \&ddns_queue_update,
            handle_error    => \&ddns_handle_error,
            log             => \&ddns_log,
        }
    );
}

#------------------------------------------------------------------------#
# Server Functionality
sub ddns_build {
    my ($kernel,$heap,$args) = @_[KERNEL,HEAP,ARG0];

    $kernel->alias_set( $args->{alias_prefix} . $args->{zone} );

    $heap->{zone} = $args->{zone};
    $heap->{server} = $args->{server};
    $heap->{interval} = $args->{interval};
    $heap->{log_sid} = $args->{log_sid};
    $heap->{key_name} = $args->{key_name};
    $heap->{key} = $args->{key};
    $heap->{autoflush} = $args->{autoflush};

    if( !$heap->{autoflush} && !$heap->{interval} ) {
        $heap->{interval} = 180;
    }

    $heap->{cache} = CHI->new(
        driver      => 'File',
        root_dir    => $args->{cache_dir},
        namespace   => $heap->{zone},
    );

    $kernel->yield('log', 'debug' => "Dynamic Updater created for $args->{zone}");

    # Set the Queue to be flushed (written)
    $kernel->delay_add( 'flush_queue', $heap->{interval} ) unless $heap->{autoflush};
}


sub ddns_log {
    my ($kernel,$heap,$level,$msg) = @_[KERNEL,HEAP,ARG0,ARG1];

    return unless defined $heap->{log_sid} && $heap->{log_sid};

    $kernel->post( $heap->{log_sid}, $level, $msg );
}
sub ddns_handle_error {
    my ($kernel,$heap,$msg) = @_[KERNEL,HEAP,ARG0];

    $kernel->yield('log', error => $msg );
}

sub ddns_flush_queue {
    my ($kernel,$heap) = @_[KERNEL,HEAP];

    my @updates = $heap->{cache}->get_keys();

    my $resolver = Net::DNS::Resolver->new();
    $resolver->nameservers( $heap->{server} );

    foreach my $ts ( sort @updates ) {
        my $update = Net::DNS::Update->new( $heap->{zone} );
        my $records = $heap->{cache}->get( $ts );

        foreach my $rec ( @{ $records } ) {
            my $is_valid = 0;
            if( $rec->{op} eq 'add' ) {
                $update->push(update =>  rr_add( $rec->{txt} ) );
                $is_valid=1;
            }
            elsif( $rec->{op} eq 'del' ) {
                my ($host,$type) = (split /\s+/, $rec->{txt})[0,1];
                $update->push(pre => yxrrset("$host $type"));
                $update->push(update =>  rr_del( $rec->{txt} ) );
                $is_valid=1;
            }

            if( $is_valid ) {
                if(defined $heap->{key_name} && defined $heap->{key}) {
                    $update->sign_tsig($heap->{key_name}, $heap->{key});
                }
                my $reply = $resolver->send( $update );

                if( $reply ) {
                    if( $reply->header->rcode ne 'NOERROR' ) {
                        $kernel->yield( 'handle_error', "Update ($ts) Failed: " . $reply->header->rcode );
                    }
                }
                else {
                    $kernel->yield( 'handle_error', "Update ($ts) Failed: " . $resolver->errorstring );
                }
            }
        }
        $heap->{cache}->remove( $ts );
    }
    $kernel->yield('log', 'debug', "queue flushed for $heap->{zone}");

    # Reset the Queue to be flushed (written)
    $kernel->delay_add( 'flush_queue', $heap->{interval} ) unless $heap->{autoflush};
}

=head2 queue_update

Example:

    $poe_kernel->post( 'ddns_updater', queue_update =>
        { op => 'add', txt => 'blah.zone.com IN A 1.2.3.4' }
    );

    .. or ..

    $poe_kernel->post( 'ddns_updater', queue_update =>
        { op => 'del', txt => 'blah.zone.com IN A 1.2.3.4' },
        { op => 'add', txt => 'blah.zone.com IN A 1.2.3.5' }
    );

=cut

sub ddns_queue_update {
    my ($kernel,$heap,@updates) = @_[KERNEL,HEAP,ARG0..$#_];

    my $key = Time::HiRes::time();

    $heap->{cache}->set( $key, \@updates );

    foreach my $update( @updates ) {
        $kernel->yield('log', 'info', qq{added to queue: [$update->{op}] $update->{txt} } );
        $kernel->yield( 'flush_queue' ) if $heap->{autoflush};
    }
}


1;
