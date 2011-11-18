package eris::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

eris::Controller::Root - Root Controller for eris

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

	$c->stash->{template} = '/index.mas';
}

sub credits :Path('/credits') :Args(0) {
	my ($self,$c) = @_;
	$c->stash->{template} = '/credits.mas';
}

sub auto :Private {
	my ($self,$c) = @_;

	return 1 if $c->controller eq $c->controller('auth');
	my $params = $c->req->params;

	if( $c->user_exists) {
		# Setup Debug
		if( exists $params->{debug} ) {
			if( $params->{debug} eq 'enable' ) {
				$c->session->{debug} = 1;
			}
			elsif( $params->{debug} eq 'disable' ) {
				$c->session->{debug} = 0;
			}
		}
		# Check Authorization
		if( $c->check_user_roles('eris::login') ) {
			return 1;
		}
		else {
			$c->forward( '/auth/unauthorized' );
			return 0;
		}
	}
	else {
		# Unauthenticated Requests
		$c->log->debug('***Root::auto User not found, forwarding to /auth/login');
		$c->session->{prelogin_uri} = $c->req->uri;	

		$c->forward( '/auth/login' );
		return 0;
	}
}

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
