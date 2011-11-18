#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use File::Basename;
use File::Spec;
use YAML;
use Try::Tiny;
use DBIx::Connector;
use File::Pid;
use Daemon::Daemonize qw( check_pidfile write_pidfile daemonize );
use POE qw(
	Component::Logger
	Component::Client::eris
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
# Parser Setup
my %RE = (
	ip => qr/[0-9]{1,3}(?:\.[0-9]{1,3}){3}/,
	mac => qr/[a-fA-F0-9]{1,2}(?:[:.\-][a-fA-F0-9]{1,2}){5}/,
);

my %COOKED = (
	dhcpd_extract_ip	=> qr/DHCPACK on ($RE{ip})/,
	evtlog_user_extract => qr/User Name: ([a-zA-Z0-9]+)\s+Domain/,
	sshd_accepted_from	=> qr/Accepted \S+ for [a-zA-Z0-9]+ from $RE{ip}/,
	arpwatch_new_station => qr/new station ($RE{ip}) ($RE{mac})/,
	arpwatch_changed_eth => qr/changed ethernet address ($RE{ip}) $RE{mac} \(($RE{mac})\)/,
);
my %HANDLERS = (
	dhcpd	=> {
		sql => qq|
			select sp_handle_dhcpack( ?, ?, ? )
		|,
		check => sub {
			my($str) = @_;
			return index( $str, 'DHCPACK' ) >= 0;
		},
		extract => [
			$COOKED{dhcpd_extract_ip},				# IP
			qr/ to ($RE{mac})/,			# MAC
			qr/ to $RE{mac}\s+\(([^)]+)\)/,	# clientID
		],
	},
	'==UserAtHost==' => {
		sql => q{
			select sp_handle_authentication( ?, ?, 'userAtHost' )
		},
		extract	=> [
			qr/[^@]+\@($RE{ip})/,
			qr/([^@]+)\@$RE{ip}/,
		],
	},
	smbtrack => {
		sql	=> q{
			select sp_handle_authentication( ?, ?, 'smbtrack' );
		},
		extract => [
			qr/DISCOVER [^:]+:($RE{ip})/,
			qr/DISCOVER ([^:]+)/,
		],
	},
	'MSWinEventLog' => {
		check => sub {
			my ($str) = @_;
			return 0 unless index( $str, 'Logon Type: 3') > 0;
			my ($user) = ($str =~ /$COOKED{evtlog_user_extract}/);
			return 0 unless defined $user && length $user;
			return 0 if( substr( $user, -1, 1) eq '$' );
			return 1;
		},
		sql => q{
			select sp_handle_authentication( ?, ?, 'mswinevtlog' );
		},
		extract => [
			qr/Source Network Address:\s+($RE{ip})/,
			$COOKED{evtlog_user_extract},
		],
	},
	sshd => {
		check => sub {
			my($str) = @_;
			return 0 unless $str =~ /$COOKED{sshd_accepted_from}/;
			return 1;
		},
		sql => q{ select sp_handle_authentication( ?, ?, 'sshd' ) },
		extract => [
			qr/from ($RE{ip})/,
			qr/Accepted \S+ for ([0-9a-zA-Z]+)/,
		]
	},
	arpwatch => {
		sql => q{ select sp_handle_arpwatch( ?, ? ) },
		extract => [
			sub {
				my ($str) = @_; my @vals = ();
				if(@vals = ($str =~ /$COOKED{arpwatch_new_station}/)) {
					return $vals[0];
				}
				if(@vals = ($str =~ /$COOKED{arpwatch_changed_eth}/)) {
					return $vals[0];
				}
			},
			sub {
				my ($str) = @_; my @vals = ();
				if(@vals = ($str =~ /$COOKED{arpwatch_new_station}/)) {
					return $vals[1];
				}
				if(@vals = ($str =~ /$COOKED{arpwatch_changed_eth}/)) {
					return $vals[1];
				}
			},
		]
	},
);
#--------------------------------------------------------------------------#
# Main Progam Loop
POE::Component::Logger->spawn(
	Alias		=> 'log',
	ConfigFile	=> $LOGCONF,
);

POE::Session->create(
	inline_states => {
		_start					=> \&storage_start,
		_stop					=> \&storage_stop,
		_child					=> sub { },
		store_message			=> \&store_message,
	},
);

POE::Component::Client::eris->spawn(
	Subscribe		=> [ keys %HANDLERS ],
	MessageHandler	=> sub {
		my $msg = shift;
		$poe_kernel->post('storage' => 'store_message' => $msg);
	},
);

POE::Kernel->run();

exit 0;
#--------------------------------------------------------------------------#

#--------------------------------------------------------------------------#
# Stop the Storage Environment
sub storage_stop {
	my ($kernel,$heap) = @_[KERNEL,HEAP];
}
#--------------------------------------------------------------------------#

#--------------------------------------------------------------------------#
# Startup the Storage Environment
sub storage_start {
	my ($kernel,$heap) = @_[KERNEL,HEAP];
	
	$kernel->alias_set('storage');

	# Complete Startup
	$kernel->post('log' => 'notice' => '(invcli) Inventory Client startup.' );
	$heap->{dbh} = DBIx::Connector->new( @{ $CFG }{qw(db_dsn db_user db_pass)} );

}

#--------------------------------------------------------------------------#
# Message Handler
sub store_message {
	my ($kernel,$heap,$msg) = @_[KERNEL,HEAP,ARG0];

	#
	# Remove the unneeded hash marks:
	foreach my $k (qw(datetime_obj date time host_raw message_raw program_raw datetime_raw) ) {
		delete $msg->{$k};
	}

	my $prog = $msg->{program_name};
	if( exists $HANDLERS{ $prog } ) {
		if( exists $HANDLERS{$prog}->{check} && ref $HANDLERS{$prog}->{check} eq 'CODE' ) {
			my $check = $HANDLERS{$prog}->{check}->( $msg->{content} );
			return unless $check;
		}
		my @vals = ();
		foreach my $extractor (@{ $HANDLERS{$prog}->{extract} } ) {
			if( ref $extractor eq 'CODE' ) {
				push @vals, $extractor->( $msg->{content} );
			}
			else {
				my ($val) = ($msg->{content} =~ /$extractor/);
				next unless defined $val;
				push @vals, $val;
			}
		}

		# Attempt to insert:
		try {
			my $sth = $heap->{dbh}->run( fixup => sub {
					my $lsh = $_->prepare( $HANDLERS{$prog}->{sql} );
					$lsh;
				}
			); 
			if( scalar(@vals) == scalar(@{ $HANDLERS{$prog}->{extract} }) ) {
				$sth->execute( @vals ) unless $OPTS{n};
				$kernel->post('log' => 'debug' => qq{(invcli) $prog: } . join(', ', @vals));
			}
		} catch {
			# Execeptions handled here
			# IGNORED for now.
			$kernel->post('log' => 'notice' => qq{(invcli) $prog: $_});
		};
	}
}
