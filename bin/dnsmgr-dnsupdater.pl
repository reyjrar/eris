#!/usr/bin/env perl 

use strict;
use warnings;

use FindBin;
use Net::IP::Resolver;
use File::Basename;
use File::Spec;
use Regexp::Common qw(net);
use MIME::Lite;
use YAML;
use Try::Tiny;
use Getopt::Std;
use Daemon::Daemonize qw( check_pidfile write_pidfile daemonize );

sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE qw(
	Component::Logger
);
use lib "$FindBin::Bin/../lib";

#------------------------------------------------------------------------#
# Argument handling
my %OPTS=();
getopts('d',\%OPTS);

#------------------------------------------------------------------------#
# Determine Path
my @BasePath = File::Spec->splitdir( $FindBin::Bin );
pop @BasePath;
my $BASE = File::Spec->rel2abs( File::Spec->catdir(@BasePath) );
my $ETC = File::Spec->catdir($BASE,"etc");
my $CFG = YAML::LoadFile( File::Spec->catfile($ETC,'dnsmgr.cfg')  );
my $STATEDIR = $CFG->{statedir};

#------------------------------------------------------------------------#
# Daemonize
if( !$OPTS{d} ) {
	my $base = basename $0;
	mkdir $STATEDIR, 0755 unless -d $STATEDIR;
	my $PIDFILE = File::Spec->catfile( $STATEDIR, $base . '.pid' );

	my $pid = check_pidfile( $PIDFILE );
	if( $pid > 0 ) {
		warn "$base - another process is currently running ($pid)\n";
		exit 1;
	}
	
	daemonize( chdir => $BASE, close => 'std' );
	write_pidfile( $PIDFILE );
	$poe_kernel->has_forked();
}

#------------------------------------------------------------------------#
# Enable Logging
my $log_sess_id = POE::Component::Logger->spawn(
	Alias		=> 'log',
	ConfigFile	=> File::Spec->catfile($CFG->{log_config}),
);

# POE Sessions
my $proc_sess_id = POE::Session->create(
	inline_states => {
		_start		=> \&processor_build,
		_stop		=> sub { },
		_child		=> \&processor_child,
		dnswrite_add	=> \&dnswrite_add,
		dnswrite_upd	=> \&dnswrite_add,
		dnswrite_del	=> \&dnswrite_del,
	}
);

# Start the POE::Kernel
POE::Kernel->run();
#------------------------------------------------------------------------#



#------------------------------------------------------------------------#
# Processor Functions
sub processor_build {
	my ($kernel,$heap) = @_[KERNEL,HEAP];

	$kernel->alias_set( 'processor' );

	# Get Data from these Sessions
	while( my ($name, $opts) = each %{ $CFG->{sources} } ) {
		next unless exists $opts->{enabled} && $opts->{enabled};
		$kernel->post( 'log' => debug => "setting up $name reader: $opts->{engine}" );
		my $error = undef;
		try {
			eval "require $opts->{engine};";
			die $@ if $@;
		} catch {
			$error = $_;
			$kernel->post( 'log' => error => "error loading engine: $opts->{engine} for $name" );
		};
		next if $error;

		my $sid = undef;
		try {
			$sid = $opts->{engine}->spawn( %{ $opts } );
		} catch {
			$error = $_;
			$kernel->post( 'log' => error => "error instantiating $opts->{engine} for $name, spawn failed. '$_'" );
		};
		next if $error;

		foreach my $zone ( @{ $opts->{zones} } ) {
			$heap->{zones}{$zone}{reader} = $sid;
		}

	}

	# Send Data to these Sessions
	while ( my ($name, $opts) = each %{ $CFG->{zones} } ) {
		$kernel->post( 'log' => debug => "setting up $name writer: $opts->{engine}" );
		my $error = undef;
		try {
			eval "require $opts->{engine};";
			die $@ if $@;
		} catch {
			$error = $_;
			$kernel->post( 'log' => error => "error loading engine: $opts->{engine} for $name" );
		};
		next if $error;

		my $sid = undef;
		try {
			$sid = $opts->{engine}->spawn( %{ $opts }, zone => $name );
		} catch {
			$error = $_;
			$kernel->post( 'log' => error => "error instantiating $opts->{engine} for $name, spawn failed. '$_'" );
		};
		next if $error;

		$heap->{zones}{$name}{writer} = $sid;
	}

	# Ensure there is a reader and writer for all zones;
	my $ZONES_LOADED_PROPERLY = 0;
	foreach my $zone ( keys %{ $heap->{zones} } ) {
		if( exists $heap->{zones}{$zone}{reader} && exists $heap->{zones}{$zone}{writer} ) {
			$ZONES_LOADED_PROPERLY++;
		}
		else {
			$kernel->post( 'log' => 'error' => "Zone $zone failed to initialize both readers and writers, skipping" );
		}
	}

	if( $ZONES_LOADED_PROPERLY == 0 ) {
		$kernel->post( 'log' => 'critical' => "No Zones Loaded, exitting" );
		$kernel->stop();
	}
}

sub dnswrite_add {
	my ($kernel,$heap,$zone,$record,$upd) = @_[KERNEL,HEAP,ARG0,ARG1,ARG2];

	$kernel->post( 'log' => notice => "adding '$record' for $zone" );

	$kernel->post( $heap->{zones}{$zone}{writer}, queue_update =>
		{ op => 'add', txt => $record }
	);
}

sub dnswrite_del {
	my ($kernel,$heap,$zone,$record,$upd) = @_[KERNEL,HEAP,ARG0,ARG1,ARG2];

	$kernel->post( 'log' => notice => "deleting '$record' for $zone" );

	$kernel->post( $heap->{zones}{$zone}{writer}, queue_update =>
		{ op => 'del', txt => $record }
	);
}


=head2 processor_child

handle SIGCHLD for the main POE::Session

=cut 

sub processor_child {
	my ($kernel,$action,$child,$rc) = @_[KERNEL,ARG0,ARG1,ARG2];
	$rc = $rc >> 8;
	my $pid = $child->ID;
	$kernel->post( log => notice => "Caught $action for pid:$pid, rc:$rc");
}
