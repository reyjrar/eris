package eris;

use strict;
use warnings;

use feature 'state';

use Catalyst::Runtime '5.80';
use Moose;
use DBIx::Connector;
use Exception::Class::DBI;
use CHI;
use Net::DNS;
use Digest::SHA1 qw(sha1_hex);

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root 
#                 directory

use parent qw/Catalyst/;
use Catalyst qw/
		ConfigLoader
		Static::Simple

		StackTrace

		Authentication
		Authorization::Roles

		Session
		Session::Store::DBIC
		Session::State::Cookie
/;
our $VERSION = '0.2';

# Application Configuration
__PACKAGE__->config({ 
	name => 'eris',
	disable_component_resolution_regex_fallback => 1,
	default_view => 'Mason',
	'View::JSON' => { expose_stash => 'json_data' },
 });

# Start the application
__PACKAGE__->setup();

has dbconn => ( is => 'ro', lazy => 1, default => sub {
		DBIx::Connector->new(
			__PACKAGE__->config->{db}{dsn},
			__PACKAGE__->config->{db}{user},
			__PACKAGE__->config->{db}{pass},
		{
			PrintError => 0,
			RaiseError => 0,
			HandleError => Exception::Class::DBI->handler,
			AutoCommit => 1,
			pg_enable_utf8 => 1,
		});
});

has cached => ( is => 'ro', lazy => 1, default => sub {
		CHI->new(
			driver		=> 'File',
			namespace	=> 'eris-web-cache',
			expires_in	=> 3600,
		);
	}
);

sub dns_resolve {
	my $self = shift;
	state $resolver = Net::DNS::Resolver->new(
		tcp_timeout	=> 1,
		udp_timeout => 1,
		persistent_tcp => 1,	
		persistent_udp => 1,	
	);
	my ($question,$nameserver) = @_;

	return unless defined $question && length $question > 3;

	$nameserver ||= __PACKAGE__->config->{dnsmgr}{preferred_nameserver};
	$nameserver ||= '8.8.8.8';

	my $key = sha1_hex( $nameserver . $question );

	my @answers = ();
	my $ref = $self->cached->get( $key );
	if( ref $ref ) {
		@answers = @{ $ref };
	}
	else {
		$resolver->nameservers( $nameserver );
		my $query = $resolver->query( $question );
		if( defined $query ) {
			my $ttl = undef;
			foreach my $rr ( $query->answer ) {
				my $value = undef;
				$ttl ||= $rr->ttl;
				if( $rr->type eq 'A' ) {
					$value = 'A ' . $rr->address;
				}
				elsif( $rr->type eq 'CNAME' ) {
					$value = 'CNAME ' . $rr->cname;
				}
				elsif( $rr->type eq 'MX' ) {
					$value = join(' ', 'MX', $rr->preference, $rr->exchange);
				}
				elsif( $rr->type eq 'PTR' ) {
					$value = 'PTR ' . $rr->ptrdname;
				}
				push @answers, join('=', $rr->name, $value) if defined $value;
			}
			$self->cached->set( $key, \@answers, $ttl );
		}
		else {
			$self->cached->set( $key, [] );
		}
	}
	return \@answers;
}


=head1 NAME

eris - Catalyst based application

=head1 SYNOPSIS

    script/eris_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<eris::C::Root>, L<Catalyst>

=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
