package eris::Controller::dnsmgr;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Net::DNS;
use Net::IP::Resolver;
use Regexp::Common qw(net);

=head1 NAME

eris::Controller::dnsmgr - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
	$c->stash->{template} = '/dnsmgr/index.mas';
}

=head2 default

=cut

sub default :Path :Args(0) {
	my ($self,$c) = @_;
	$c->stash->{template} = '/dnsmgr/index.mas';
}

=head2 zone

=cut

sub zone :Chained('/') :PathPart('dnsmgr/zone') :CaptureArgs(1) {
	my ($self,$c,$zone_id) = @_;

	if( $zone_id !~ /^\d+$/ ) {
		$zone_id =~ s/[^\w\d]//g;
		$c->flash->{error} = [ "Invalid zone_id::'$zone_id'" ];
		$c->res->redirect( $c->uri_for( '/dnsmgr' ) );
		$c->detach;
	}

	my $zone = $c->model('DB::dnsmgr::zones')->find( $zone_id );

	if( defined $zone && ref $zone ) {
		$c->stash->{zone} = $zone;
		$c->stash->{cfg} = $c->config->{dnsmgr} || {};
	}
	else {
		$c->flash->{error} = [ "Unknown Zone with zone_id::'$zone_id'" ];
		$c->res->redirect( $c->uri_for( '/dnsmgr' ) );
		$c->detach;
	}
	1;
}

=head2 zone_list

=cut

sub zone_list :Path('zone/list') {
    my ( $self, $c ) = @_;


	my $rs = $c->model('DB::dnsmgr::zones')->search(
		undef,
		{ order_by => [ 'type', 'accept', 'zone_id' ] }
	);
	$c->stash->{template} = '/dnsmgr/zone/index.mas';
	$c->stash->{zone_rs} = $rs;
	
}

=head2 zone_create

=cut

sub zone_create :Path('zone/create') {
	my ( $self, $c ) = @_;

	my $rs = $c->model('DB::dnsmgr::zones')->search(
		undef,
		{ order_by => [ 'accept', 'name' ] }
	);

	$c->stash->{template} = '/dnsmgr/zone/create.mas';
	$c->stash->{zone_rs} = $rs;
}

sub zone_create_save :Path('zone/create_save') {
	my ( $self, $c ) = @_;

	my %params = %{ $c->req->params };
	
	$c->stash->{template} = '/dnsmgr/zone/list.mas';
}


=head2 zone_view

=cut

sub zone_view :Chained('zone') :PathPart('') :Args(0) {
	my ( $self, $c ) = @_;
	$c->stash->{template} = '/dnsmgr/zone/view.mas';
}

sub zone_add_record :Chained('zone') :PathPart('add') :Args(0) {
	my ($self,$c) = @_;

	my $zone = $c->stash->{zone};
	my %params = %{ $c->req->params };

	my %warnings = ();
	my @errors = ();
	my %vals = _validate_record( $c, \%params, $c->stash->{cfg},\@errors, \%warnings );

	if( @errors ) {
		$c->flash->{errors} = \@errors;
		$c->res->redirect( $c->uri_for( '/dnsmgr/zone/' . $zone->zone_id ) );
		$c->detach;	
	}

	$c->stash->{values} = \%vals;
	$c->stash->{warnings} = \%warnings;
	$c->stash->{template} = '/dnsmgr/zone/record/verify.mas';
}

sub zone_create_record :Chained('zone') :PathPart('create') :Args(0) {
	my ($self,$c) = @_;

	my $zone = $c->stash->{zone};
	my $action = $c->req->param('action') || 'cancel';

	if( $action eq 'save' ) {
		my (%warnings,@errors);
		my %vals = _validate_record( $c, \%{ $c->req->params }, $c->stash->{cfg}, \@errors, \%warnings );
	
		if( @errors ) {
			push @{ $c->flash->{errors} }, @errors;
		}
		else {
			my $record = $c->model('DB::dnsmgr::records')->find( {
				zone_id => $zone->zone_id,
				name 	=> lc $vals{rec_name},
				class	=> 'IN',
				type	=> uc $vals{rec_type},
			});

			if( !defined $record ) {
				$record = $c->model('DB::dnsmgr::records')->create({
						zone_id => $zone->zone_id,
						name 	=> lc $vals{rec_name},
						class	=> 'IN',
						type	=> uc $vals{rec_type},
						value	=> $vals{rec_value},
				});
			}
			$record->mod_user_id( $c->user->user_id );
			$record->value( $vals{rec_value} );
			$record->priority( 1 );
	
			$record->update;
			$c->flash->{notice} = "Successfully added $vals{rec_name} IN $vals{rec_type} $vals{rec_value}";

			# Check to see if we can reverse
			if( $record->class eq 'IN' and $record->type eq 'A' ) {
				my ($revzone) = $c->model('DB::dnsmgr::zones')->find({
					type => 'reverse',
					accept_inet => { '>>', $vals{rec_value} },
				});	
				my ($octet) = (split /\./,$vals{rec_value})[3];
				my $forward_name = $vals{rec_name} . '.' . $zone->name . '.';
				my $revrec = $c->model('DB::dnsmgr::records')->find( {
					zone_id => $revzone->zone_id,
					name => $octet,
					class => 'IN',
					type => 'PTR'
				});
				if( !defined $revrec ) {
					$revrec = $c->model('DB::dnsmgr::records')->create({
							zone_id => $revzone->zone_id,
							name 	=> $octet,
							class	=> 'IN',
							type	=> 'PTR',
							value	=> $forward_name,
					});
				}
				$revrec->mod_user_id( $c->user->user_id );
				$revrec->value( $forward_name );
				$revrec->priority( 1 );
				$revrec->update;
				$c->flash->{notice} .= " and reverse added!";
			}
		}
	}

	# Redirect back to the zone
	$c->res->redirect( $c->uri_for( '/dnsmgr/zone/' . $zone->zone_id ) );
	$c->detach;
}

=head2 zone_delete_record

=cut

sub zone_delete_record :Path('zone/delete_record') :Args(1) {
    my ( $self, $c, $rec_id ) = @_;

	my $rec = $c->model('DB::dnsmgr::records')->find( $rec_id );
	my $zone_id = 'list';

	if( !defined $rec ) {
		push @{ $c->flash->{error} }, "Attempt to delete invalid record_id:$rec_id";
	}
	else {
		$zone_id = $rec->zone_id;
		$rec->delete;
	}

	$c->res->redirect( $c->uri_for( '/dnsmgr/zone/' . $zone_id ) );
	$c->detach;
}


sub _validate_record {
	my ($c,$params,$cfg,$errors,$warnings) = @_;

	my %return = ();
	# Validation Schema
	my %typeValid = (
		A		=> {
			rec_name => sub {
				my ($val) = @_;
				return undef unless defined $val;
				$val =~ s/[^0-9a-zA-Z\-\_]//g;
				if ( $val ne $_[0] ) {
					push @{ $warnings->{rec_name} }, "Name modified due to illegal characters";
				}
				return $val;
			},
			rec_value => sub {
				my ($val) = @_;
				return undef unless defined $val;
				my ($ip) = ($val =~ /$RE{net}{IPv4}{-keep}/);	
				if ( $ip ne $_[0] ) {
					push @{ $warnings->{rec_value} }, "IP modified due to illegal characters";
				}
				return $ip;
			},
		},
		CNAME 	=> {
			rec_name => sub {
				my ($val) = @_;
				return undef unless defined $val;
				$val =~ s/[^0-9a-zA-Z\-\_]//g;
				if ( $val ne $_[0] ) {
					push @{ $warnings->{rec_name} },"Name modified due to illegal characters";
				}
				return $val;
			},
			rec_value => sub {
				my ($val) = @_;
				return undef unless defined $val;
				$val =~ s/[^0-9a-zA-Z\-\_\.]//g;
				return $val;
			},
		},
		PTR	=> {
			rec_name => sub {
				my ($val) = @_;
				return undef unless defined $val;
				$val =~ s/[^0-9]//g;
				if ( $val ne $_[0] ) {
					push @{ $warnings->{rec_name} },"Name modified due to illegal characters";
				}
				if( $val < 0 || $val > 256 ) {
					push @$errors, "Invalid IP Octect";
					return undef;
				}
				return $val;
			},
			rec_value => sub {
				my ($val) = @_;
				return undef unless defined $val;
				$val =~ s/[^0-9a-zA-Z\-\_\.]//g;
				if ( $val ne $_[0] ) {
					push @{ $warnings->{rec_value} },"Name modified due to illegal characters";
				}
				if( $val !~ /\.$/ ) {
					$val .= '.';
				}
				return $val;
			},
		},
	);

	# Do Validation of Input
	if( !exists $typeValid{$params->{rec_type}} ) {
		push @$errors, "Invalid Record Type";
	}
	else {
		my $checks = $typeValid{$params->{rec_type}};
		$return{rec_type} = $params->{rec_type};
		foreach my $p (keys %{ $checks }) {
			my $val = $checks->{$p}->( $params->{$p} );
			if( defined $val ) {
				$return{$p} = $val;
			}
			else {
				push @$errors, "Bad Value for $p";
			}
		}	
	}
	# Check the values for existing records
	if( !@$errors && exists $cfg->{areas} && ref $cfg->{areas} eq 'HASH' ) {
		if( grep { $_ eq $params->{rec_type} } qw(A CNAME) ) {
			foreach my $area (sort keys %{ $cfg->{areas} } ) {
				my @names = ();
				my @values = ();
				# Permutate $rec_name
				if( $return{rec_name} =~ /[a-z0-9\-\_]/ ) {
					my $suffix = $cfg->{areas}{$area}{suffix};
					my @suffix = ref $suffix eq 'ARRAY' ? @{$suffix} : ($suffix);
					foreach my $suff ( @suffix ) {
						my $fqdn = join('.', $return{rec_name}, $suff);
						if( my $ref = $c->dns_resolve( $fqdn, $cfg->{areas}{$area}{nameserver} ) ) {
							push @names, @$ref;
						}
					}
					push @{ $warnings->{rec_name} }, "=ICON= NS($area) has $return{rec_name}", @names if @names;
				}
				if( $return{rec_value} =~ /$RE{net}{IPv4}/ ) {
					if( my $ref = $c->dns_resolve( $return{rec_value}, $cfg->{areas}{$area}{nameserver} ) ) {
						push @values, @$ref;
					}
					push @{ $warnings->{rec_value} }, "=ICON= NS($area) has $return{rec_value}", @values if @values;
				}
			}
		}
	}

	return %return;
}

=head2 ipmgt

IP Management Code

=cut

sub ipmgt_base :Chained('/') :PathPart("dnsmgr/ipmgt") :CaptureArgs(0) {
	my ( $self, $c ) = @_;
}

sub ipmgt_main :Chained('ipmgt_base') :PathPart('main') :Args(0) {
	my ( $self, $c ) = @_;

	my $ipmgt_rs = $c->model('DB::dnsmgr::meta')->search(
		{ allow_edit => 'true' },
		{ order_by => 'name' }
	);

	$c->stash->{template} = '/dnsmgr/ipmgt/main.mas';
	$c->stash->{ipmgt_rs} = $ipmgt_rs;
}

sub ipmgt_request :Chained('ipmgt_base') :PathPart('request') :Args(0) {
	my ($self, $c) = @_;

	my %args = %{ $c->req->params() };


	# Assemble args to the DB friendly status
	my $zone = $c->model('DB::dnsmgr::zones')->find( $args{zone_id} );
	my $short = lc $args{clientid};
	$short =~ s/[^a-z0-9\-]//g;
	my $fqdn = join('.', $short, $zone->name );

	my $request = $c->model('DB::dnsmgr::meta::record')->find(
		{ fqdn => $fqdn, source => 'request' }
	);
	my $ip = undef;

	if( $request ) {
		$ip = $request->ip;
	}
	else {
		# Find the Next IP Address
		my $sth = $c->dbconn->run( fixup => sub {
				$_->prepare( q{select sp_dnsmgr_next_free_ip( ?, ? )} );
			}
		);

		# Grab the next IP
		$sth->execute( $args{range}, $fqdn );
		($ip) = $sth->fetchrow_array;
	}

	# Check for existing entry
	my $dnsrec = $c->model('DB::dnsmgr::records')->find(
		{ zone_id => $zone->zone_id, name => $short, 
			class => 'IN', type => 'A' }
	);
	if( $dnsrec ) {
		$c->flash->{notice} = "$fqdn has address " . $dnsrec->value;
	}

	my (%warnings,@errors);
	my %tests = ( rec_name => $short, rec_value => $ip, rec_type => 'A' );
	my %vals = _validate_record( $c, \%tests, $c->config->{dnsmgr}, \@errors, \%warnings );

	$c->stash->{template} = '/dnsmgr/ipmgt/request.mas';
	$c->stash->{zone} = $zone;
	$c->stash->{clientid} = $short;
	$c->stash->{fqdn} = $fqdn;
	$c->stash->{ip} = $ip;
	$c->stash->{warnings} = \%warnings;
}

sub ipmgt_confirm :Chained('ipmgt_base') :PathPart('confirm') :Args(0) {
	my ($self, $c) = @_;

	# Get the Parameters;
	my %args = map { lc } %{ $c->req->params() };

	# Request Ticket in the Records DB
	my $request = $c->model('DB::dnsmgr::meta::record')->find(
		{ fqdn => $args{fqdn}, ip => $args{ip}, source => 'request' }
	);

	
	if( $args{response} eq "confirm" ) {
		if( $args{do_zone_update} == 1 ) {
			# Do the Foward Update
			my $rec = $c->model('DB::dnsmgr::records')->find_or_create(
				{ zone_id => $args{zone_id}, name => $args{clientid}, class => 'IN',
					type => 'A', value => $request->ip, mod_user_id => $c->user->user_id
				}
			); 
			$rec->priority(1);
			$rec->update;
			$request->forward_rec_id( $rec->record_id );	
		}
		# Always record the reverse
		my $ContainsIP = q{ >> '} . $request->ip . q{'::inet};
		my $rev_zone = $c->model('DB::dnsmgr::zones')->find(
			 { type => 'reverse', 
				accept_inet => \$ContainsIP
			}
		);
		if( $rev_zone ) {
			my ($last_octet) = ($request->ip =~ /(?:\d{1,3}\.){3}(\d{1,3})/);
			my $rec = $c->model('DB::dnsmgr::records')->find_or_create(
				{ zone_id => $rev_zone->zone_id, name => $last_octet, class => 'PTR',
					type => '', value => $args{fqdn} . '.',, mod_user_id => $c->user->user_id
				}
			); 
			$rec->priority(1);
			$rec->update;
			$request->reverse_rec_id( $rec->record_id );	
		}
		$request->source('accepted');
		$request->update;
	}
	else {
		$request->delete();
	}

	$c->res->redirect( $c->uri_for('/dnsmgr/ipmgt/main') );
	$c->detach;
}

=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
