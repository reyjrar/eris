#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use File::Basename;
use File::Spec;
use Daemon::Daemonize qw( check_pidfile write_pidfile daemonize );
use YAML;
use Socket;
use DBIx::Connector;
use Try::Tiny;
use Getopt::Std;
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
pop @BasePath; 	# Strip collector directory

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
#--------------------------------------------------------------------------#
# SQL Stuff
my %SQL = (
	sigid	=> q{select sp_get_signature_id( ?, ?, ? )},
	insert	=> q{
			insert into security_events ( sig_id, sensor, event_ts, 
				src_ip, src_port, dst_ip, dst_port, message )
				values ( ?, ?, ?, ?, ?, ?, ?, ? )
	},
);
# Optimized Regex, not perfect, but "good enough"
my %RE = (
	IPv4	=> qr/(?:[0-9]{1,3}\.){3}[0-9]{1,3}/,
);
my %COOKED = (
	date		=> qr/(\w+\s+\d+\s+\d+:\d+:\d+)/,
	host		=> qr/\s+\d+:\d+:\d+\s+(\S+)/,
	facility	=> qr/\s+\d+:\d+:\d+\s+\S+\s+([^:]+):/,
	sigid		=> qr/\[\d+\:(\d+\:\d+)\]/,
	sigmsg		=> qr/\[\d+\:\d+\:\d+\]\s+([^\[]+)\s+\[/,

	mesg		=> qr/\[\d+\:\d+\:\d+\]\s+(.*)\s+\{[A-Z]+\}/,
	srcAddr		=> qr/($RE{IPv4})(:\d+)?\s+-\>/,
	dstAddr		=> qr/-\>\s+($RE{IPv4})/,
	srcPort		=> qr/$RE{IPv4}:(\d+)\s+-\>/,
	dstPort		=> qr/-\>\s+$RE{IPv4}:(\d+)/,
);

#--------------------------------------------------------------------------#
# Main Program Loops
POE::Component::Logger->spawn(
	Alias		=> 'log',
	ConfigFile	=> $LOGCONF,
);

POE::Session->create(
	inline_states => {
		_start					=> \&storage_start,
		_stop					=> sub { },
		_child					=> sub { },
		store_message			=> \&store_message,
		check_db				=> \&check_db,
	},
);

POE::Component::Client::eris->spawn(
	Subscribe		=> [ qw(snort) ],
	MessageHandler	=> sub {
		my $msg = shift;
		$poe_kernel->post('storage' => 'store_message' => $msg);
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
	$kernel->post( 'log' => 'notice' => '(seccli) Security Client Startup.' );

	$heap->{dbh} = DBIx::Connector->new( @{ $CFG }{qw(db_dsn db_user db_pass)} );
}

#--------------------------------------------------------------------------#
# Message Handler
sub store_message {
	my ($kernel,$heap,$msg) = @_[KERNEL,HEAP,ARG0];

	my %details = ();
	foreach my $re (keys %COOKED) {
		($details{$re}) = ($msg->{content} =~ /$COOKED{$re}/);
	}

	if( !$details{mesg} ) {
		# Return unless we have a message to store.
		return;
	}

	my $eris_sigid = undef;	
	try {
		my $sth = $heap->{dbh}->run( fixup => sub {
			my $lsh = $_->prepare( $SQL{sigid} );
			return $lsh;
		});

		$sth->execute( 'snort', $details{sigid}, $details{sigmsg} );

		if( $sth->rows > 0 ) {
			($eris_sigid) = $sth->fetchrow_array;
		}
	} catch {
		$kernel->post( log => error => "(seccli) - Could not find signature id($details{sigid}) - $_" );
	};

	if( defined $eris_sigid && $eris_sigid > 0 ) {
		my $error = 0;
		try {
			my $sth = $heap->{dbh}->run( fixup => sub {
				my $lsh = $_->prepare( $SQL{insert} );
				return $lsh;
			});
			$sth->execute(
				$eris_sigid,
				$msg->{host},
				$msg->{datetime_str},
				$details{srcAddr},	
				$details{srcPort},	
				$details{dstAddr},	
				$details{dstPort},	
				$details{mesg}
			);
		} catch {
			$error++;
			$kernel->post( log => error => "(seccli) - Insert failed: $_" );
		};
		# Debug Logging
		$kernel->post( log => debug => "(seccli) - Event logged( $details{srcAddr} -> $details{dstAddr} $details{mesg}" )
			unless $error > 0;
	}
}
