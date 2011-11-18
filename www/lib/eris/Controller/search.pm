package eris::Controller::search;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Regexp::Common qw(net);

=head1 NAME

eris::Controller::search - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 search 

=cut

sub search :Global {
    my ( $self, $c ) = @_;
	my %scrub = (
		ip	=> sub { local $_=shift; my ($ret)=(/$RE{net}{IPv4}{-keep}/); return $ret; },
		mac	=> sub { local $_=shift; my ($ret)=(/$RE{net}{MAC}{-keep}/); return $ret; },
		username => sub { local $_=shift; s/[^a-z0-9]+//gi; return $_; },
		clientid => sub { local $_=shift; s/\..*//; s/[^a-z0-9\-_]+//gi; return $_; },
	);

	my $context = $c->req->param('query_context');
	my $str = $c->req->param('query_str');
	my $interval = $c->req->param('query_interval');
	
	$interval =~ s/[^a-z0-9]+//g;
	$context =~ s/[^a-z]+//g;
	my $scrubbed = 0;

	if( exists $scrub{$context} ) {
		$str = $scrub{$context}->( $str );
		$scrubbed = 1;
	}

	if( !$scrubbed || length $str < 1)  {
		$c->flash->{errors} = [ "Search : unable to complete search of type $context" ];
		$c->res->redirect('/');
		$c->detach;
	}

	$c->stash->{template} = '/search/results.mas';
	$c->stash->{query_str} = $str;
	$c->stash->{query_context} = $context;
	$c->stash->{query_interval} = $interval;
}

sub locate :Global {
	my ($self,$c) = @_;

	my $qs = $c->req->param('query_str');

	# Sanitize
	$qs =~ s/[^a-z0-9\-\_\.\:]//ig;

	my %req = (
		uri => '',
		params => {}
	);
	# Tests to run
	my @tests = (
		{
			name => 'MAC Address Search',
			type => 'mac',
			check => sub {
				my $qs = shift;
				my ($mac) = ($qs =~ /$RE{net}{MAC}{-keep}/);
				return $mac;
			},
			handler => sub {
				my $mac = shift;
				my $rs = $c->model('DB::device')->single( { mac_addr => $mac } );
				if( defined $rs && $rs->device_id > 0 ) {
					$req{uri} = '/node/' . $rs->device_id . '/view';	
					return 1;
				}
				return 0;
			},
		},
		{
			name => 'IP Address Search',
			type => 'ip',
			check => sub {
				my $qs = shift;
				my ($ip) = ($qs =~ /$RE{net}{IPv4}{-keep}/);
				return $ip;
			},
			handler => sub {
				my $ip = shift;
				$req{uri} = '/search';	
				$req{params} = { query_str => $ip, query_context => 'ip', query_interval => '1m' };
				return 1;
			},
		},
		{
			name => 'Property Tag Search',
			type => 'property_tag',
			check => sub {
				my $qs = shift;
				my ($str) = ($qs =~ /^([0-9]{6,8})$/);
				return $str;
			},
			handler => sub {
				my $str = shift;
				my $padding = 8 - length( $str );
				$str = '0'x$padding . $str;
				my $rs = $c->model('DB::device::details')->single( { property_tag => $str } );
				if( defined $rs && $rs->device_id > 0 ) {
					$req{uri} = '/node/' . $rs->device_id . '/view';	
					return 1;
				}
				return 0;
			},
		},
		{
			name => 'Host or Username',
			check => sub {
				my $qs = shift;
				my ($str) = ($qs =~ /^([a-z0-9\-\_]+)$/i);
				return lc $str;
			},
			handler => sub {
				my $str = shift;
				my $rs = $c->model('DB::device')->single( { clientid => $str } );
				if( defined $rs && $rs->device_id > 0 ) {
					$req{uri} = '/node/' . $rs->device_id . '/view';
					return 1;
				}
				$rs = $c->model('DB::user')->single( { username => $str } );
				if( defined $rs && $rs->user_id > 0 ) {
					$req{uri} = '/user/' . $rs->user_id . '/view';
					return 1;
				}
				return 0;
			},
		},
		{
			name => 'First or Last Name',
			check => sub {
				my $qs = shift;
				my ($str) = ($qs =~ /^([a-z]+)$/i);
				return lc $str;
			},
			handler => sub {
				my $str = shift;
				my $rs = $c->model('DB::user')->search( { display_name => \qq{ILIKE '\%$str\%'} }, { rows => 2 } );
				if( defined $rs && $rs->count > 0 ) {
					$req{uri} = '/user/search';	
					$req{params}->{qs} = $str;
					return 1;
				}
			},
		},
	);

	foreach my $test ( @tests ) {
		if(my $value = $test->{check}->( $qs ) ) {
			last if $req{handled} = $test->{handler}->( $value );
		}
	}

	if( $req{uri} ) {
		$c->res->redirect( $c->uri_for( $req{uri}, $req{params} ) );
		$c->detach;
	}
	$c->flash->{errors} = [ 'Search : Nothing found for ' . $qs ];	
	$c->forward( '/index' );
}


=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
