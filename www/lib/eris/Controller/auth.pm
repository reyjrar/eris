package eris::Controller::auth;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

eris::Controller::auth - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 login 

=cut

sub login :Global ActionClass('REST') { }

sub login_GET {
    my ( $self, $c ) = @_;

	$c->stash->{template} = '/auth/login.mas'
}

sub login_POST {
	my ($self,$c) = @_;

	my $user = $c->req->params->{username} || "";
	my $pass = $c->req->params->{password} || "";

	if( $user && $pass ) {
		if( $c->authenticate( { username=>$user, password=>$pass }, 'dbic'  ) ) {
			$c->persist_user();

			# Forward to PreLogin URI
			my $uri = delete $c->session->{prelogin_uri};
			$uri ||= $c->uri_for( '/' );
			$c->res->redirect( $uri );
			$c->detach;
		}
		else {
			$c->flash->{errors} = [ 'Authentication Failure' ];
			$c->res->redirect( $c->uri_for('/login') );
			$c->detach;
		}
	}
}

sub logout :Global {
	my ($self,$c) = @_;

	if( $c->user_exists ) {
		$c->logout;
	}

	$c->res->redirect( $c->uri_for( '/' ) );
	$c->detach;
}

sub unauthorized :Global {
	my ($self, $c) = @_;
	
	$c->stash->{template} = '/auth/unauthorized.mas';
}

=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
