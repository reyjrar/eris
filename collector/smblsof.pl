#!/usr/bin/env perl 
#
# Uses data in the LSOF to map IP's to Usernames
#
use strict;
use warnings;

use CHI;
use FindBin;
use File::Basename;
use File::Spec;
use Daemon::Daemonize qw( check_pidfile write_pidfile daemonize );
use YAML;
use Regexp::Common qw(net);
use POE qw(
	Wheel::Run
	Filter::Line
	Component::Logger
);
use Getopt::Std;
#------------------------------------------------------------------------#
# Argument Handling
my %OPTS;
getopts('dn', \%OPTS);

#------------------------------------------------------------------------#
# Path Setup
my @BasePath = File::Spec->splitdir("$FindBin::Bin");
pop @BasePath;	# Strip Binary Directory

my $BASEDIR = File::Spec->rel2abs( File::Spec->catdir(@BasePath) );
my $ETC = File::Spec->catdir( $BASEDIR, 'etc' );
# Configs
my $CFG = YAML::LoadFile( File::Spec->catfile($ETC, 'eris.cfg') );
my $LOGCONF = File::Spec->catfile( $ETC, 'logging.conf' );
my $STATEDIR = $CFG->{statedir};

#------------------------------------------------------------------------#
# Daemonize if necessary:
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


#------------------------------------------------------------------------#
# Main POE Sessions
POE::Component::Logger->spawn( ConfigFile => $LOGCONF );

POE::Session->create( inline_states => {
	_start		=> \&processor_start,
	_stop		=> sub  { },

	run_lsof	=> \&processor_run_lsof,
	lsof_line	=> \&processor_read_line,
	lsof_close	=> \&processor_lsof_close,
	reg_user	=> \&processor_reg_user,
});

POE::Kernel->run();
#------------------------------------------------------------------------#

sub processor_start {
	my ($kernel,$heap) = @_[KERNEL,HEAP];

	$kernel->alias_set( 'processor' );

	$heap->{cache} = CHI->new(
		driver		=> 'File',
		namespace	=> 'lsofUserScan',	
		expires_in	=> 3600
	);

	$kernel->yield( 'run_lsof' );
}

sub processor_run_lsof {
	my ($kernel,$heap) = @_[KERNEL,HEAP];
	my @CMD = qw(/usr/bin/sudo /usr/sbin/lsof -i -n);

	$kernel->post( 'logger', 'notice' => "Running @CMD" );
	$heap->{lsof_job} = POE::Wheel::Run->new(
		Conduit => 'pty-pipe',
		Program			=> \@CMD,
		StdioFilter		=> POE::Filter::Line->new(),
		StderrFilter	=> POE::Filter::Line->new(),
		StdoutEvent		=> 'lsof_line',
		StderrEvent		=> 'lsof_line',
		CloseEvent		=> 'lsof_close',
	);
	$kernel->post('logger', 'notice' =>  "Job Started" );
}

sub processor_read_line {
	my ($kernel,$heap,$line) = @_[KERNEL,HEAP,ARG0];

	if( $line =~ /^imap\s+/ || $line =~ /^smbd\s+/ ) {
		if( $line =~ /\s+\(ESTABLISHED\)/ ) {
				#  Process the line
				my ($user, $ipstring) = (split /\s+/, $line)[2,7];
				my ($ip) = ($ipstring =~ /->$RE{net}{IPv4}{-keep}:\S+/);	
				$kernel->yield( 'reg_user', $user => $ip );
		}
	}
}

sub processor_reg_user {
	my ($kernel,$heap,$user,$ip) = @_[KERNEL,HEAP,ARG0,ARG1];

	return if $user eq 'root';
	my $id = join( '@', $user, $ip );
	my $cached = $heap->{cache}->get( $id );

	if( defined $cached && $cached > 0 ) {
		$heap->{cache}->set( $id, $cached+1 );
	}
	else {
		$heap->{cache}->set( $id, 1 );
		$kernel->post( 'logger', 'warning' => qq{DISCOVER $user:$ip} );
	}
}

sub processor_show_line {
	my ($kernel,$heap,$line) = @_[KERNEL,HEAP,ARG0];

	$kernel->post('logger', 'debug' => "smbtrack got: $line" );
}

sub processor_lsof_close {
	my ($kernel,$heap) = @_[KERNEL,HEAP];

	$kernel->post('logger', 'notice' => 'Job Done');
	$kernel->delay_add( 'run_lsof', 60 );
}
