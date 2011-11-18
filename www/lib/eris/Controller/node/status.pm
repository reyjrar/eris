package eris::Controller::node::status;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

eris::Controller::node::status - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
	$c->detach( '/node/status/list', [ 'all' ] );
}


sub list :Path :Args(1) {
	my ( $self,$c, $status ) = @_;

	my %status = ();
	foreach my $stat ( $c->model('DB::device::status')->all ) {
		$status{ $stat->name } = { 
			desc	=> $stat->description,
			id		=> $stat->status_id,
		};
	}

	my $condition = undef;
	if( $status eq 'all' ) {
		$condition = undef;
	}
	else {
		if( exists $status{$status} ) {
			$condition = { 'me.status_id' => $status{$status}->{id} };
		}
	}

	$c->stash->{log_rs} = $c->model('DB::map::device::status')->search(
		$condition,
		{ order_by => { -desc => 'mod_ts' }, prefetch => [qw(device status mod_user) ], limit => 1000 }
	);	

	$c->stash->{status} = $status;
	$c->stash->{status_href} = \%status;
	$c->stash->{template} = '/node/status/list.mas';
}



=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
