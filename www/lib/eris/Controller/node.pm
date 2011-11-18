package eris::Controller::node;
use Moose;
use Try::Tiny;
use namespace::autoclean;
use Regexp::Common qw(net);

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

eris::Controller::node - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path() :Args(0) {
	my ( $self, $c, $page ) = @_;

	$page ||= 1;
	my $search = { device_ts => \q{> NOW() - interval '4 months'} };

	my $params = $c->req->params;

	my %args = ();

	if( exists $params->{clientid} && length $params->{clientid} ) {
		$search->{clientid} = { 'like' => '%' . $params->{clientid} . '%' };
		$args{clientid} = $params->{clientid};
	}
	elsif( exists $params->{device_type} ) {
		my %types = (
			'unknown'	=> [ -or => \q{device_type is null}, { device_type => 'Unknown' } ],
		);

		if( exists $types{ $params->{device_type} } ) {
			$search = $types{ $params->{device_type} };
		}
		else {
			$search->{device_type} = ucfirst lc $params->{device_type};
		}
		$args{device_type} = $params->{device_type};
	}


	my $rs = $c->model('DB::device::overview')->search($search);
	$c->stash->{template} = '/node/list.mas';
	$c->stash->{devices} = $rs;
	$c->stash->{args} = \%args;
}

=head2 base_node

=cut

sub base_node :Chained('/') :PathPart('node') :CaptureArgs(1) {
	my ( $self,$c,$id ) = @_;

	# ID Can Only be Digits
	$id =~ s/\D//g;
	my $params = $c->req->params;

	if( $id > 0 ) {
		my $dev = $c->model('DB::device')->find($id);
		if( $dev ) {
			$c->stash->{device} = $dev;
			$c->stash->{device_id} = $id;
		}
	}
	elsif( $id == 0  && exists $params->{save_node} ) {
		$c->log->debug( "creating a new node object" );
		# Creating a Node
		my $mac = $params->{mac_addr} =~ /$RE{net}{MAC}/ ? $params->{mac_addr} : $self->_get_fake_mac( $c );
		# Create the Device
		my $dev = $c->model('DB::device')->find_or_create({ mac_addr => $mac });
		$dev->clientid( '__eris_node_creation' );
		$dev->discovery_method('manual');
		# Update
		$dev->update;
		# Store in the Stash
		$c->stash->{device} = $dev;
		$c->stash->{device_id} = $dev->device_id;
		# Overwrite Clientid:
		$c->req->param('overwrite_clientid' => 1 );
	}

}

sub view :Chained('base_node') :PathPart('view') :Args(0) {
	my ( $self, $c ) = @_;


	$c->stash->{template} = '/node/view.mas';
}

sub edit :Chained('base_node') :PathPart('edit') :Args(0) {
	my ($self,$c) = @_;

	my $device_id = $c->stash->{device_id};

	my %fields = (
		'DB::device' => [
			'clientid',
			'mac_addr',
			'ip_addr',
			'device_id',
			{ name => 'device_class_id',
			  cb => sub {
					my $o = shift;
					my @classes = ();
					foreach my $cl ( $o->classes ) {
						push @classes, $cl->device_class_id;
					}
					return \@classes;
			  },
			},
			{
				name => 'regulatory_compliance',
				cb	=> sub {
					my $o = shift;

					my $regs = $o->compliant_regulations();
					my %regs = ();	
					if( defined $regs && $regs->count() ) {
						while( my $rc = $regs->next ) {
							$regs{$rc->regulation_id} = 1;
						}
					}
					return \%regs;

				},
			},
		],
		'DB::device::details'	=> [
			'property_tag',
			'notes',
			'serial_no',
			'make_model',
			'node_type_id',
			{
				name	=> 'primary_user',
				cb	=> sub {
					my $o = shift;
					my $username = undef;
					try { $username = $o->primary_user->username; };
					return $username;
				},
			},
		],
		'DB::device::vlan::assigned' => [
			'vlan_id'	
		],
	);

	my %node = ();
	foreach my $table (keys %fields) {
		my $obj = $c->model($table)->find( { device_id => $device_id } );
		foreach my $decoder (@{ $fields{$table} }) {
			if( ref $decoder eq 'HASH' ) {
				my $val;
				eval {
					$val = $decoder->{cb}->($obj);
				} if defined $obj;
				if(my $error = $@) {
					warn "Object Decoder Error: $error\n";
				} else {
					$node{$decoder->{name}} = $val;
				}
			}
			else {
				my $val;
				eval {
					no strict;
					$val = $obj->$decoder();
				} if defined $obj;
				$node{$decoder} = $val;
			}
		}
	}

	$node{device_class_id} ||= [];
	$c->stash->{node} = \%node;
	$c->stash->{template} = '/node/edit.mas';
}

=head2 add

=cut

sub node_add :Path('add') :Args(0) {
	my ($self,$c) = @_;
	$c->stash->{node} = {};
	$c->stash->{template} = '/node/edit.mas';
}

=head2 save

Save the form details

=cut

sub node_save :Chained('base_node') :PathPart('save') :Args(0) {
	my ($self,$c) = @_;

	my $device_id = $c->stash->{device_id};

	if( $c->req->method ne 'POST' ) {
		$c->res->redirect( $c->uri_for( '/node/' . $device_id . '/view' ) );
		$c->detach;
	}

	my %sanitize = (
		property_tag	=> sub { local $_ = shift; s/[^0-9]//g; $_ },
		make_model		=> sub { local $_ = shift; s/[^a-z0-9\- ]+//gi; $_ },
		serial_no		=> sub { local $_ = shift; s/[^a-z0-9\- ]+//gi; $_ },
		primary_user	=> sub { local $_ = shift; s/[^a-z0-9]+//gi; $_ },
		clientid		=> sub { local $_ = shift; s/[^a-z0-9\-_]+//gi; $_ },
	);

	my $params = $c->req->params;
	foreach my $k ( keys %{ $params } ) {
		if( exists $sanitize{$k} && ref $sanitize{$k} eq 'CODE') {
			$params->{$k} = $sanitize{$k}->( $params->{$k} );
		}
	}
	my $dev = $c->stash->{device};

	if( defined $device_id && $device_id > 0 ) {
		#
		# Details Update
		my $details = $c->model('DB::device::details')->find_or_create( { device_id => $device_id } );	

		$details->property_tag( $params->{property_tag} );
		$details->serial_no( $params->{serial_no} );
		$details->mod_user_id( $c->user->user_id );

		my ($pri_user) = $c->model('DB::user')->search(
			{
				username	=> lc $params->{primary_user},
				is_active	=> 't',
			},
			{
				rows		=> 1,
			},
		);
		if( defined $pri_user ) {
			$details->primary_user_id( $pri_user->user_id );
		}
		$details->node_type_id( $params->{node_type_id} ) if $params->{node_type_id};
		$details->make_model( $params->{make_model} ) if $params->{make_model};

		$dev->is_verified(1);
		$details->update();

		# Device Classes
		if( defined $params->{device_class_id} ) {
			my @classes = ();
			if( ref $params->{device_class_id} eq 'ARRAY' ) {
				foreach my $clid ( @{ $params->{device_class_id} } ) {
					push @classes, $c->model('DB::device::class')->find( $clid );
				}
			}
			else {
				push @classes, $c->model('DB::device::class')->find( $params->{device_class_id} );
			}
			$dev->set_classes( \@classes  );
		}
		$dev->update;

		#
		# Assign VLAN
		if( $params->{vlan_id} > 0 ) {
			warn "Setting VLAN to $params->{vlan_id}}";
			my $vlan = $c->model('DB::device::vlan::assigned')->find_or_create(
			{
				device_id	=> $device_id,
				vlan_id		=> $params->{vlan_id}
			});
			$vlan->assign_user_id ( $c->user->user_id );
			$vlan->assign_type( 'manual' );

			$vlan->update();
		}

		#
		# Regulations
		if( defined $params->{regulations} ) {
			my @regs = ref $params->{regulations} eq 'ARRAY' ? @{ $params->{regulations} } : $params->{regulations};
			my @regSet = ();
			foreach my $reg_id ( @regs ) {
				if( $params->{"reg_compliance_$reg_id"} == 1 ) {
					push @regSet, $c->model('DB::regulatory::meta')->find( $reg_id );
				}
				if( length $params->{"reg_dev_log_status_$reg_id"} ) {
					my $rdl = $c->model('DB::regulatory::device::log')->create({
						device_id	=> $device_id,
						regulation_id => $reg_id,
						user_id		=> $c->user->user_id,
						status		=> $params->{"reg_dev_log_status_$reg_id"},
						comments	=> $params->{"reg_dev_log_comments_$reg_id"},
					});
					$rdl->update;
				}
			}
			$dev->set_compliant_regulations( \@regSet );
			$dev->update;
		}
		
		#
		# Over Rides
		if( $params->{overwrite_clientid} ) {
			$dev->discovery_method( 'manual' );
			$dev->clientid( $params->{clientid} );
			$dev->update;
		}
	}

	# Return the User back to the edit page.
	$c->res->redirect( $c->uri_for( '/node/' . $device_id .'/view' ) );
	$c->detach;
}

=head2 node_makemodel

=cut

sub node_makemodel :Chained('/') :PathPart('node/makemodel') :CaptureArgs(0) {
	my ($self,$c) = @_;

	my $str = $c->req->param('q');
	$str =~ s/[^\w\d ]+//g;
	$c->stash->{query_str} = $str;

	if( defined $str && length $str ) {
		# Cache Key
		my $key = join(',', 'node::makemodel', $str);
		my $cached = $c->cached->get( $key );
		if( ref $cached eq 'ARRAY' ) {
			$c->stash->{list} = $cached;
		}
		else {
			my %list = ();
			my $rs = $c->model('DB::device::details')->search(
				{
					'lower(make_model)' => { 'LIKE' =>  lc $str . '%' },
				},
			);
			while( my $rec = $rs->next ) {
				my $mm = $rec->make_model;	
				next unless defined $mm;
				$list{$mm} ||= 0;
				$list{$mm}++;
			}
			my @list = sort { $list{$b} <=> $list{$a} } keys %list;
			my $end = $#list > 24 ? 24 : $#list;
			$c->stash->{list} = [ @list[0..$end] ];
			$c->cached->set( $key, $c->stash->{list} );
		}
	}
}

sub node_makemodel_json :Chained('node_makemodel') :PathPart('json') :Args(0) {
	my ($self,$c) = @_;
	# Send the list through the JSON View
	$c->stash->{json_data} = $c->stash->{list};
	$c->forward('View::JSON');
}

=head2 _get_fake_mac 

Generate a BOGUS unique mac address for a device

=cut

sub _get_fake_mac : Private {
	my ($self,$c) = @_;

	my $prefix = '99:99:99:';

	my $obj = $c->model('DB::ext::fake_mac_addr')->create({ user_id => $c->user->user_id });
	my $raw = sprintf("%06x", $obj->suffix);

	my $suffix = join(':', $raw =~ /(\w{2})/g);

	return $prefix . $suffix;
	
}

=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

