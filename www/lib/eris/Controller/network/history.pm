package eris::Controller::network::history;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

eris::Controller::network::history - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{template} = '/network/history.mas';
}

sub base_records :Chained('/') :PathPart('network/history/records') :CaptureArgs(0) {
	my ($self, $c) = @_;
	use Data::Dumper;

	$c->log->debug( Dumper $c->req->params );

	# Build Filters
	my %filters = $self->_build_filters( $c->req->params );

	my $sth = $c->dbconn->run( fixup => sub {
		my $lsh = $_->prepare(qq{
			select
				to_char( inv.event_ts, 'Mon DD HH24:MI') as date,
				inv.device_id as id,
				inv.ip,
				case
					when inv.mac is not null then inv.mac
					when dev.mac_addr is not null then dev.mac_addr
					else '00:00:00:00:00:00'
				end as mac,
				case
					when inv.clientid is not null then inv.clientid
					when dev.clientid is not null then dev.clientid
					else 'n/a'
				end as clientid,
				inv.discovery_method as method
			from inventory_archive inv
				inner join device_discovery dev on inv.device_id = dev.device_id
			where
				inv.ip is not null
				$filters{where}
			order by inv.event_ts desc
				limit $filters{limit}
		});
	});	
	$sth->execute(@{ $filters{args} });
	$c->stash->{res_sth} = $sth;
}

sub json_records :Chained('base_records') :PathPart('json') :Args(0) {
	my ($self, $c) = @_;
	
	my @records = ();
	while( my $record = $c->stash->{res_sth}->fetchrow_hashref ) {
		push @records, $record;
	}
	$c->stash->{json_data} = \@records;
	$c->forward('View::JSON');
}


#------------------------------------------------------------------------#
# Internal Methods
sub _build_filters {
	my ($self,$args) = @_;
	my $Today = DateTime->now();
	my %filter_build = (
		ip		=> {
			where		=> 'AND inv.ip = ?',
			args		=> sub {
				my $ip = shift;
				$ip =~ s/[^0-9\.]//g;
				return $ip;
			},
		},
		start_date => {
			where		=> q{AND event_ts >= ?},
			args		=> sub {
				my $str = shift;
				if( my($date) = ($str =~ /([0-9]{4}-[0-9]{2}-[0-9]{2})/) ) {
					return "$date 00:00:00";
				}
				return undef;
			},
			defaults => {
				where => q{AND event_ts >= '} . $Today->ymd('-') . q{ 00:00:00'},
			},
		},
		end_date => {
			where		=> q{AND event_ts <= ?},
			args		=> sub {
				my $str = shift;
				if( my($date) = ($str =~ /([0-9]{4}-[0-9]{2}-[0-9]{2})/) ) {
					return "$date 23:59:59";
				}
				return undef;
			},
			defaults => {
				where => q{AND event_ts <= '} . $Today->ymd('-') . q{ 23:59:59'},
			},
		},
		limit	=> {
			fixup => sub {
				my $str = shift;
				$str =~ s/[^0-9]//g;
				my $rows = int( $str );
				# Range checking
				if( $rows < 1 || $rows > 10_000 ) {
					$rows = 200;
				}
				return $rows;
			},
		},
	);
	my @where=();
	my @args=();
	my %copy_to_filter = ( limit => 200 );

	# Build the Filters
	foreach my $filter (keys %filter_build) {
		if( exists $args->{$filter} && defined $args->{$filter} ) {
			if( exists $filter_build{$filter}->{where} ) {
				push @where, $filter_build{$filter}->{where};
				push @args, $filter_build{$filter}->{args}->( $args->{$filter} );
			}
			elsif( exists $filter_build{$filter}->{fixup} ) {
				$copy_to_filter{$filter} = $filter_build{$filter}->{fixup}->( $args->{$filter} );	
			}
		}
		elsif( exists $filter_build{$filter}->{defaults} ) {
			if( exists $filter_build{$filter}->{defaults}{where} ) {
				push @where, $filter_build{$filter}->{defaults}{where};
			}
		}
	}

	my %filter_hash = (
		where	=> join(' ', @where),
		args	=> \@args,
		%copy_to_filter,
	);

	return %filter_hash;
}




=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
