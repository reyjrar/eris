package eris::Controller::signatures;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

eris::Controller::signatures - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

	$c->forward( '/signatures/signatures_list', [ 1 ]  );
}


sub signatures_list :Path('') :Args(1) {
	my ($self,$c,$id) = @_;

	# Default to Unknown Signatures
	$id ||= 1;

	my $sig = $c->model('DB::event::type')->find( $id );
	
	if( !defined $sig ) {
		$c->flash->{error} = "Unknown Event Type ID: $id";
		$c->res->redirect( $c->uri_for( '/' ) );
		$c->detach
	}

	my $sth = $c->dbconn->run( fixup => sub {
		my $sth = $_->prepare(q{
			select
				sig.sig_id,
				evtype.evt_type_id,
				evtype.name,
				sig.description

			from security_event_types evtype
				left join security_signatures sig on evtype.evt_type_id = sig.evt_type_id
			where evtype.evt_type_id = ?
		});
		$sth->execute( $id );
		$sth;
	});

	$c->stash->{evt_type_id} = $id;
	$c->stash->{res_sth} = $sth;
	$c->stash->{evt_type_rs} = $c->model('DB::event::type')->search( undef, { order_by => 'name' });
	$c->stash->{template} = '/signatures/list.mas';
}

sub signatures_classify :Path('classify') :Args(0) {
	my ($self,$c) = @_;

	my $type_id = $c->req->param('evt_type_id');
	$type_id =~ s/[^0-9]+//g;

	my @sigs = $c->req->param('sig_id');
	my @new = $c->req->param('new_evt_type_id');
	my @old = $c->req->param('old_evt_type_id');

	my %updates = ();
	foreach my $sig_id (@sigs) {
		my $new_type_id = shift @new;
		my $old_type_id = shift @old;
		if( $new_type_id != $old_type_id ) {
			my $sig = $c->model('DB::event::signature')->find( $sig_id );
			if( !defined $sig ) {
				push @{ $c->flash->{errors} }, "Invalid Signature ID: $sig_id";
				next;
			}
			my $evt = $c->model('DB::event::type')->find( $new_type_id );
			if( !defined $evt ) {
				push @{ $c->flash->{errors} }, "Invalid Event Type ID: $new_type_id";
				next;
			}
			# Update
			$sig->evt_type_id( $new_type_id );	
			$sig->update;
			$updates{$evt->name}++;
		}
	}

	my @updates = ();
	while( my ($k,$v) = each %updates ) {
		push @updates, "$v updated to $k";	
	}
	if( @updates ) {
		$c->flash->{notice} = 'Changes saved: ' . join(', ', @updates);
	}

	my $action = defined $type_id && $type_id ? qq{/signatures/$type_id} : '/signatures';

	$c->res->redirect( $c->uri_for( $action ) );
	$c->detach;
}

=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
