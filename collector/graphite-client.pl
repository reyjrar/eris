#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use File::Basename;
use File::Spec;
use Daemon::Daemonize qw( check_pidfile write_pidfile daemonize );
use YAML;
use Socket;
use Try::Tiny;
use Getopt::Std;
use IO::Socket::INET;
use POE qw(
    Component::Logger
    Component::Client::eris
);

#--------------------------------------------------------------------------#
# Argument Handling
my %OPTS=();
getopts('d',\%OPTS);

#--------------------------------------------------------------------------#
# Path Determiniation
my @BasePath = File::Spec->splitdir( $FindBin::Bin );
pop @BasePath;  # Strip collector directory

my $BASEDIR = File::Spec->rel2abs( File::Spec->catdir( @BasePath ) );
my $ETC = File::Spec->catdir( $BASEDIR, 'etc' );

#--------------------------------------------------------------------------#
# Config Files
my $CFG = YAML::LoadFile( File::Spec->catfile($ETC,'eris.cfg') );
my $LOGCONF = File::Spec->catfile($ETC,'logging.conf');
my $STATEDIR = $CFG->{statedir};

#--------------------------------------------------------------------------#
# Daemonize if Necessary
if( !$OPTS{d} ) {
    my $base = basename $0;

    mkdir $STATEDIR, 0755 unless -d $STATEDIR;
    my $PIDFILE = File::Spec->catfile( $STATEDIR, $base . '.pid' );

    my $pid = check_pidfile( $PIDFILE );
    if( $pid > 0 ) {
        warn "$base - another process is currently running ($pid)\n";
        exit 1;
    }

    daemonize( chdir => $BASEDIR, close => 'std' );
    write_pidfile( $PIDFILE );
    $poe_kernel->has_forked();
}
#-------------------------------------------------------------------------#
# Barewords
# ---------
#  Key is Metric, value is an array of strings
my %BAREWORD = ();
foreach my $key ( keys %{ $CFG->{collector}{graphite}{keywords} } ) {
    $BAREWORD{$key} = $CFG->{collector}{graphite}{keywords}{$key};
}

#--------------------------------------------------------------------------#
# Main Program Loops
POE::Component::Logger->spawn(
    Alias       => 'log',
    ConfigFile  => $LOGCONF,
);

POE::Session->create(
    inline_states => {
        _start                  => \&storage_start,
        _stop                   => sub { },
        _child                  => sub { },
        process_message         => \&process_message,
        send_to_carbon          => \&send_to_carbon,
    },
);

POE::Component::Client::eris->spawn(
    Subscribe       => [ qw(fullfeed) ],
    MessageHandler  => sub {
        my $msg = shift;
        $poe_kernel->post('storage' => 'process_message' => $msg);
    },
);

POE::Kernel->run();
exit 0;
#--------------------------------------------------------------------------#

#--------------------------------------------------------------------------#
# Startup the Storage Environment
sub storage_start {
    my ($kernel,$heap) = @_[KERNEL,HEAP];

    $kernel->alias_set('storage');
    $kernel->post( 'log' => 'notice' => '(carboncli) Carbon Client Startup.' );
    my %stats = ();
    $heap->{stats} = \%stats;
    $kernel->delay_add( send_to_carbon => 60 );

}

#--------------------------------------------------------------------------#
# Process Message
sub process_message {
    my ($kernel,$heap,$msg) = @_[KERNEL,HEAP,ARG0];

    # Increment Total Messages
    $heap->{stats}{messages} = 0 unless exists $heap->{stats}{messages};
    $heap->{stats}{messages}++;

    # Process Facility Priority Program
    $msg->{program} = $msg->{program_name};
    foreach my $field (qw(host facility priority program)) {
        my $val = $msg->{$field};
        next unless defined $val;
        $val =~ s/\./_/g;
        $val = lc $val if $field eq 'host';
        increment_stat( $heap->{stats}, $field, $val );
    }

    # Keyword Processing
    my $keyword = undef;
    foreach my $test ( keys %BAREWORD ) {
        last if defined $keyword;
        last unless $msg->{content};
        my $norm = lc $msg->{content};
        my $type = ref $BAREWORD{$test};
        if( not defined $type ) {
            if( index( $norm, $BAREWORD{$test} ) >= 0 ) {
                $keyword = $test;
                last;
            }
        }
        elsif( $type eq 'ARRAY' ) {
            foreach my $subtest ( @{ $BAREWORD{$test} } ) {
                if( index( $norm, $subtest ) >= 0 ) {
                    $keyword = $test;
                    last;
                }
            }
        }
    }
    if( defined $keyword ) { increment_stat( $heap->{stats}, 'keyword', $keyword ); }
}

sub increment_stat {
    my ($stats,$field,$val) = @_;

    $stats->{$field} = {} unless exists $stats->{$field};
    $stats->{$field}{$val} = 0 unless exists $stats->{$field}{$val};

    $stats->{$field}{$val}++;
}

sub send_to_carbon {
    my ($kernel,$heap) = @_[KERNEL,HEAP];

    my $sock = IO::Socket::INET->new(
        PeerAddr => $CFG->{collector}{graphite}{carbon}{host},
        PeerPort => $CFG->{collector}{graphite}{carbon}{port},
        Proto    => 'tcp'
    );
    return unless $sock->connected;

    # Time of update:
    my $time = time;
    # Grab our statistics
    my $stats_ref = delete $heap->{stats};
    $heap->{stats} = {};

    # Store the updates
    my @updates = ();

    # Total messages received;
    push @updates, "syslog.messages $stats_ref->{messages} $time";

    foreach my $type ( qw(facility priority program host keyword) ) {
        if( exists $stats_ref->{$type} && ref $stats_ref->{$type} eq 'HASH' ) {
            foreach my $metric ( keys %{ $stats_ref->{$type} } ) {
                $metric = $metric if $type eq 'host';
                push @updates, "syslog.$type.$metric $stats_ref->{$type}{$metric} $time";
            }
        }
    }

    # do the send
    foreach my $update (@updates) {
        $sock->send( "$update\n" );
    }
    my $updates = scalar @updates;
    $kernel->call( log => debug => "Sent $updates updates to the carbon server" );

    $kernel->delay_add( send_to_carbon => 60 );
}
