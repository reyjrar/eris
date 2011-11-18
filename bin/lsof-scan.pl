#!/usr/bin/env perl 

use strict;
use warnings;

use CHI;
use File::Spec;
use File::Basename;
use Regexp::Common qw(net);
use POE qw(
	Wheel::Run
	Filter::Line
	Component::Daemon
	Component::Logger
);

#------------------------------------------------------------------------#
# Find our ETC Directory
my $PROGRAM = $0;
my $BINDIR = File::Spec->rel2abs( (fileparse( $PROGRAM ))[1] );
my @BINDIR = File::Spec->splitdir( $BINDIR );
pop @BINDIR;
my $ROOT_DIR = File::Spec->catdir( @BINDIR );
my $ETC_DIR = File::Spec->catdir( $ROOT_DIR, 'etc' );
my $LOGCONF = File::Spec->catfile( $ETC_DIR, 'logging.conf');

print "LOGGING on $LOGCONF\n";sleep 1;

#------------------------------------------------------------------------#
POE::Component::Daemon->spawn( detach => 1, babysit => 600, max_children => 5 );

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
