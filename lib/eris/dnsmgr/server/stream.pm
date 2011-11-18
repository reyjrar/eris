package eris::dnsmgr::server::stream;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Net::IP::Resolver;
use POE qw(
	Component::Server::TCP
);

=head1 NAME

eris::dnsmgr::server::stream - Network Streamed DNS Updates

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

POE session for integration with the eris DNS Management engine.

    use eris::dnsmgr::server::stream;

    my $eris_sess_id = eris::dnsmgr::server::stream->spawn(
			secret			=> 'dns secret', # REQUIRED
			authorized_updaters => [ qw( 1.2.3.4 ) ], #REQUIRED
			zonemap	=> {
				10.0.0.0/8 => 'internal.example.com',
			},  # REQUIRED
			cb_session		=> 'processor', #REQUIRED
			cb_prefix		=> 'dhcp_', #default
			bind_addr		=> 'localhost', 	#default
			bind_port		=> '9053',		 	#default
	);
    ...
	POE::Kernel->run();

cb_session must be able to dispatch the following events:

	$cb_prefix . '_error'	=> Arguments( Class, Updater IP, Message ),
	$cb_prefix . '_add'		=> Arguments( Zone, IP, Hostname ),
	$cb_prefix . '_del'		=> Arguments( Zone, IP, Hostname ),
	$cb_prefix . '_old'		=> Arguments( Zone, IP, Hostname ),

=head1 EXPORT

eris::dnsmgr::server::stream does not export any symbols.

=head1 FUNCTIONS

=head2 spawn

Creates the POE::Session for the Net Stream Updater

Parameters:

	secret			=> 'dns secret', # REQUIRED
	authorized_updaters => [ qw( 1.2.3.4 ) ], #REQUIRED
	zonemap	=> {
		10.0.0.0/8 => 'internal.example.com',
	},  # REQUIRED
	cb_session		=> 'processor', #REQUIRED
	cb_prefix		=> 'dhcp_', #default
	bind_addr		=> 'localhost', 	#default
	bind_port		=> '9053',		 	#default

=cut


sub spawn {
	my $type = shift;


	#
	# Param Setup
	my %args = (
		cb_prefix		=> 'dhcp_', #default
		bind_addr		=> 'localhost', 	#default
		bind_port		=> '9053',		 	#default
		@_
	);

	# Validation
	my @required = qw( secret authorized_updaters zonemap );
	foreach my $p (@required) {
		die "__PACAKGE__ requires parameter $p to be set!\n" unless defined $args{$p};
	}

	#------------------------------------------------------------------------#
	# Server
	my $alias = 'dnsmgr-stream-' . join( '-', @args{qw(bind_addr bind_port)} );
	my $session_id = POE::Component::Server::TCP->new(
		Alias			=> $alias,
		Address			=> $args{bind_addr},
		Port			=> $args{bind_port},

		ClientConnected		=> sub {
			my ($kernel,$heap ) = @_[KERNEL,HEAP];
			_server_build_client_heap( $kernel, $heap, %args );
		},
		ClientDisconnected	=> \&server_client_term,
		ClientError			=> \&server_client_term,
		ClientInput			=> \&server_client_input,
	);
}

#------------------------------------------------------------------------#
# Server Functionality
sub _server_build_client_heap {
	my ($kern,$heap,%args) = @_;

	$heap->{dnsmgr}{secret} = $args{secret};
	$heap->{dnsmgr}{cb_session} = $args{cb_session};
	$heap->{dnsmgr}{cb_prefix} = $args{cb_prefix};
	$heap->{dnsmgr}{authorized_updaters} =  { 
		map { $_ => 1 } ref $args{authorized_updaters} eq 'ARRAY' ? 
				@{ $args{authorized_updaters} } : $args{authorized_updaters}
	};
	$heap->{dnsmgr}{netres} = Net::IP::Resolver->new();

	my %nets = ();
	foreach my $range ( keys %{ $args{zonemap} } ) {
		push @{ $nets{$args{zonemap}->{$range}} }, $range;
	}
	foreach my $net (keys %nets) {
		$heap->{dnsmgr}{netres}->add( $net, @{ $nets{$net} } );
	}

}

sub server_client_term {
	my ($kernel,$heap,$ses) = @_[KERNEL,HEAP,SESSION];
}

sub server_client_input {
	my ($kernel,$heap,$sess,$msg) = @_[KERNEL,HEAP,SESSION,ARG0];

	my $cbpre = $heap->{dnsmgr}{cb_prefix};
	my $cbses = $heap->{dnsmgr}{cb_session};

	my %actions = map { $_ => 1 } qw( add del old );

	print Dumper( $heap );

	if( exists $heap->{dnsmgr}{authorized_updaters}{ $heap->{remote_ip} } ) {
		my ($act,$host,$ip,$sum) = split /;;/, $msg;

		return unless defined $host and length $host;

		my $zone = $heap->{dnsmgr}{netres}->find_first( $ip );
		my $name = lc $host;

		if (!exists $actions{$act} ) {
			$kernel->post( $cbses, $cbpre . '_error'  => 'bad_action', $heap->{remote_ip}, $msg );
		}
		elsif ( defined $zone && $zone ne 'ignore' ) {
			my $str = join(';;', $heap->{dnsmgr}{secret}, $act, $ip, $host);
			my $chkSum = md5_hex( $str );
			if( $chkSum eq $sum  ) {
				$kernel->post( $cbses, $cbpre . $act => $zone, $ip, $name );
			}
			else {
				$kernel->post( $cbses, $cbpre . 'error' => 'bad_checksum', $heap->{remote_ip}, "($msg) [expected: $chkSum]" );
			}
		}
		else {
			$kernel->post( $cbses, $cbpre . 'error' => 'out_of_net', $heap->{remote_ip}, "act:$act / host:$host / ip:$ip" );
		}
	}
	else {
		$kernel->post( $cbses, $cbpre . 'error' => 'unauthorized', $heap->{remote_ip}, $msg );
	}
}


1;
