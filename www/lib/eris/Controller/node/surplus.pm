package eris::Controller::node::surplus;
use Try::Tiny;
use DateTime;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

eris::Controller::node::surplus - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path() :Args(0) {
	my ($self,$c) = @_;
	$c->stash->{template} = '/node/surplus/index.mas';
}

=head2 lookup

=cut

sub lookup :Path('lookup') :Args(0) {
	my ($self,$c) = @_;

	# Grab Tags
	my $tags = $c->req->param('property_tags');
	my @tags = split /\s+/, $tags;

	# Redirect if we're missing tags
	if( @tags < 1 ) {
		push @{ $c->flash->{errors} }, "Please specify a property tag(s).";
		$c->res->redirect( $c->uri_for('/node/surplus') );
		$c->detach();
	}

	# Build the Entries Array
	my @entries = ();
	foreach my $tag ( @tags ) {
		# Vivify
		my %data = (
			property_tag => $tag,
			mac_address => '',
			make_model => '',
			serial_no => '',
			primary_user => '',
		);
		my $det = $c->model('DB::device::details')->find( {property_tag => $tag} );
		if( defined $det ) {
			try {
				$data{mac_address} = $det->device->mac_addr;
			};
			$data{make_model} = $det->make_model;
			$data{serial_no} = $det->serial_no;
			try {
				$data{primary_user} = $det->primary_user->username;
			};
		}
		push @entries, \%data;
	}
	
	$c->stash->{entries} = \@entries;
	$c->stash->{template} = '/node/surplus/lookup.mas';
}

sub process :Path('process') :Args(0) {
	my ( $self, $c ) = @_;

	my @tag		= $c->req->param('property_tag');
	my @mac		= $c->req->param('mac_address');
	my @model	= $c->req->param('make_model');
	my @serial	= $c->req->param('serial_no');
	my @user	= $c->req->param('primary_user');

	my @list = ();
	while( my $tag = shift @tag ) {
		# Grab the set of elements we're processing
		my $mac = shift @mac;
		my $model = shift @model;
		my $serial = shift @serial;
		my $username = shift @user;

		# create fake MAC if needed
		if( length($mac) != 17 ) {
			$mac = $c->controller('node')->_get_fake_mac( $c );
		}

		my $device = $c->model('DB::device')->find_or_create( { mac_addr => $mac } );
		my $user = $c->model('DB::user')->find( { username => $username } );	

		my $details = $c->model('DB::device::details')->find_or_create( { device_id => $device->device_id } );
		$details->property_tag( $tag );
		$details->make_model( $model );
		$details->serial_no( $serial );
		$details->mod_user_id( $c->user->user_id );		

		if( $user ) {
			$details->primary_user_id( $user->user_id );
		}
		$details->update();

		# Info Hash
		my %info = (
			device_id => $device->device_id,
			property_tag => $tag,
			mac_address => $mac,
			make_model => $model,
			serial_no => $serial,
			primary_user => $username,
		);
		push @list, \%info;

		# Do the Surplus
		my $status = $c->model('DB::device::status')->find({ name => 'surplus'});
		my $surplus = $c->model('DB::map::device::status')->create({
				mod_user_id		=> $c->user->user_id,
				device_id		=> $device->device_id,
				status_id		=> $status->status_id,
		});
	}

	$c->stash->{entries} = \@list;
	$c->stash->{template} = '/node/surplus/process.mas';
}

sub print :Path('print') :Args(0) {
	my ( $self, $c ) = @_;

	my $status = $c->model('DB::device::status')->find({ name => 'surplus'});

	my @sheets = ();
	my $NAME = $c->config->{surplus}{name} || 'John Doe, PHB';
	my $DATE = DateTime->today->ymd('-');
	
	foreach my $device_id ( $c->req->param('device_id') ) {
		# Check to make sure the device is being surplussed
		my $surplussing = $c->model('DB::map::device::status')->find({
			status_id => $status->status_id,
			device_id => $device_id,
			is_archived => q{false},
		});
		next unless $surplussing;

		# Check to make sure we have details
		my $details = $c->model('DB::device::details')->find({ device_id => $device_id });
		next unless $details;
		next unless length $details->property_tag;

		my ($make,$model) = split(/\s+/, $details->make_model, 2);

		my %info = (
			name => $NAME, date => $DATE,
			property_tag => $details->property_tag,
			make => $make,
			model => $model,
			serial_no => $details->serial_no || 'n/a',
		);

		push @sheets, \%info;
	}

	$c->stash->{sheet_info} = \@sheets;
	$c->forward('PDF::SurplusSheet::Avery');
}

=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
