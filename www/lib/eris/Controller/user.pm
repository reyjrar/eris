package eris::Controller::user;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

eris::Controller::user - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched eris::Controller::user in user.');
}

sub search :Path('search') :Args(0) {
	my ($self,$c) = @_;

	my $qs = lc $c->req->param('qs');
	$qs =~ s/[^a-z]//gi;

	my $rs = $c->model('DB::user')->search( { display_name => \qq{ILIKE '\%$qs\%'} } );

	$c->stash->{template} = '/user/list.mas';
	$c->stash->{user_rs} = $rs;
	$c->stash->{qs} = $qs;
}

=head2 user_base

=cut

sub user_base :Chained('/') :PathPart('user') :CaptureArgs(1) {
	my ( $self, $c, $user_id ) = @_;

	my $user = $c->model('DB::user')->find( $user_id );

	if( ! defined $user ) {
		$c->error( "Unknown user: $user_id" );
		$c->detach( '/index' );
	}

	$c->stash->{user_id} = $user_id;
	$c->stash->{user} = $user;
}

=head2 user_view

=cut

sub user_view :Chained('user_base') :PathPart('view') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{template} = '/user/view.mas';
}

=head2 search

=cut

sub user_search :Chained('/') :PathPart('user/search') :CaptureArgs(0) {
	my ($self, $c) = @_;
	
	my $str = $c->req->param('q');
	$str =~ s/[^\w\d]+//g;
	$c->stash->{query_str} = $str;

	if( defined $str && length $str ) {
		my $key = join(',', 'user::search', $str );
		my $cached = $c->cached->get( $key );
		if( ref $cached eq 'ARRAY' ) {
			$c->stash->{list} = $cached;
		}
		else {
			my $rs = $c->model('DB::user')->search(
				{
					username => { 'LIKE' => lc $str . '%' },
				},
				{
					order_by	=> 'username',
					rows		=> 25,
				},
			);

			my @list = ();
			while( my $user = $rs->next ) {
				push @list, $user->username;
			}
			$c->stash->{list} = \@list;
			$c->cached->set( $key, \@list );
		}
	}
}

sub ajax_search :Chained('user_search') :PathPart('ajax') :Args(0) {
	my ( $self,$c ) = @_;

	my @list = @{ $c->stash->{list} };
	$c->response->body( scalar @list ? join("\n", @list) : $c->stash->{query_str} );
	
}

sub json_search :Chained('user_search') :PathPart('json') :Args(0) {
	my ($self,$c) = @_;

	$c->stash->{json_data} = $c->stash->{list};
	$c->forward('View::JSON');
}

=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

