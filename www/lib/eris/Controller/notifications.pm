package eris::Controller::notifications;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

eris::Controller::notifications - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

	my $rs = $c->model('DB::notification')->search(
		undef,
		{ prefetch => 'event_type', order_by => 'me.name' }
	);
	$c->stash->{template} = '/notifications/index.mas';
	$c->stash->{notification_rs} = $rs;
}

=head2 create

Interface for creating notifications

=cut

sub add :Path('add') :Args(0) {
	my ( $self, $c ) = @_;

	$c->stash->{template} = '/notifications/edit.mas';
	$c->stash->{data_ref} = {
		notification_id			=> 0,
		is_enabled				=> 1,
		notification_interval	=> '30 days',
		min_events_trigger		=> 5,
		admins					=> [ $c->user->uid ],
	};
}

sub view :Path('view') :Args(1) {
	my ($self,$c,$notify_id) = @_;

	my $ntf = $c->model('DB::notification')->find( $notify_id );

	my %data = (
		notification_id			=> $notify_id,
	);
	
	if( $ntf ) {
		my @fields = qw(
			notification_id name evt_type_id min_events_trigger alert_from_address is_enabled
			notification_interval
			orig_admin_alert orig_admin_subject orig_admin_message
			orig_user_alert orig_user_subject orig_user_message
			summary_admin_alert summary_admin_subject summary_admin_message
			summary_user_alert summary_user_subject summary_user_message
		);
		foreach my $f (@fields) {
			$data{$f} = $ntf->get_column( $f );
		}
		my @admins = ();
		foreach my $adm ( $ntf->admins ) {
			push @admins, $adm->username;
		}
		$data{admins} = \@admins;
	}
	else {
		$c->flash->{error} = "No such notification_id = $notify_id";
		$c->res->redirect( $c->uri_for('/notifications/') );
		$c->detach;
	}

	$c->stash->{template} = '/notifications/edit.mas';
	$c->stash->{data_ref} = \%data;	
}

=head2 save

POST Method to save Objects

=cut 

sub save :Path('save') :Args(0) {
	my ( $self, $c ) = @_;

	my $params = $c->req->params();

	my @required = qw( name evt_type_id min_events_trigger mod_user_id alert_from_address
						notification_interval );
	my @optional = qw(
			orig_admin_alert orig_admin_subject orig_admin_message
			orig_user_alert orig_user_subject orig_user_message


			summary_admin_alert summary_admin_subject summary_admin_message
			summary_user_alert summary_user_subject summary_user_message
	);

	my %notification = ();
	my %errors = ();
	foreach my $k ( @required ) {
		if( exists $params->{$k} && defined $params->{$k} ) {
			$notification{$k} = $params->{$k};
		}
		else {
			$errors{$k} = "required field missing";
		}
	}
	foreach my $k ( @optional ) {
		if( exists $params->{$k} && defined $params->{$k} ) {
			$notification{$k} = $params->{$k};
		}
	}

	if( scalar keys %errors == 0 ) {
		my $note = $c->model('DB::notification')->create(\%notification);
		$note->update();

		if( ref $params->{admin_users} eq 'ARRAY' ) {
			my @admins = ();
			foreach my $username (@{ $params->{admin_users} }) {
				my $user = $c->model('DB::user')->find( { username => $username } );
				push @admins, $user if defined $user;
			}
			if( scalar @admins ) {
				$note->set_admins( @admins );
				$note->update();
			}
		}
	}
	else {
		$c->flash->{field_errors} = \%errors;
		$c->flash->{errors} = [ "Missing required data." ];
		$c->detach( '/notifications/create' );
	}

	$c->res->redirect( $c->uri_for( '/notifications' ) );
	$c->detach;
}


=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

