package eris::Controller::events;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use DateTime;

=head1 NAME

eris::Controller::events - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

	my $sth = $c->dbconn->run( fixup => sub { 
			my $sth = $_->prepare(q{
				select
					offender_id,
					dev.clientid,
					min(mvs.first_ts) as first_ts,
					max(mvs.last_ts) as last_ts,
					SUM(violations) as violations
				from mv_security_offenders_sig_30days mvs
					left join device_discovery dev on mvs.offender_id = dev.device_id
					where violations > 100
				group by offender_id, dev.clientid
				order by violations desc
			});
			$sth->execute();
			$sth;
	});

	$c->stash->{res_sth} = $sth;
	$c->stash->{template} = '/events/top.mas';
}

sub console :Path('console') :Args(0) {
	my ($self,$c) = @_;

	$c->stash->{template} = '/events/console.mas';
}

sub console_messages :Chained('/') :PathPart('events/messages') :CaptureArgs(0) {
	my ($self, $c) = @_;
	use Data::Dumper;

	$c->log->debug( Dumper $c->req->params );

	# Build Filters
	my %filters = $self->_build_filters( $c->req->params );

	my $sth = $c->dbconn->run( fixup => sub {
		my $lsh = $_->prepare(qq{
			select
				to_char( event_ts, 'Mon DD HH24:MI') as date,
				evt.src_ip, evt.src_port, evt.src_id,
				evt.dst_ip, evt.dst_port, evt.dst_id,
				sig.description,
				etype.short as type_short, etype.name as type_name
			from security_events evt
				inner join security_signatures sig on evt.sig_id = sig.sig_id
				inner join security_event_types etype on sig.evt_type_id = etype.evt_type_id
			where
				etype.base_level > 1
				$filters{where}
			order by evt.event_ts desc
				limit $filters{limit}
		});
	});	
	$sth->execute(@{ $filters{args} });
	$c->stash->{res_sth} = $sth;
}

sub json_console_messages :Chained('console_messages') :PathPart('json') :Args(0) {
	my ($self, $c) = @_;
	
	my @records = ();
	while( my $record = $c->stash->{res_sth}->fetchrow_hashref ) {
		push @records, $record;
	}
	$c->stash->{json_data} = \@records;
	$c->forward('View::JSON');
}

sub node_details :Chained('/') :PathPart('events/node') :CaptureArgs(1) {
	my ($self, $c, $id) = @_;

	my $sth = $c->dbconn->run( fixup => sub {
		my $lsh = $_->prepare(q{
			select
				sig.description as signature,
				mv.violations
			from mv_security_offenders_sig_30days mv
				left join security_signatures sig on mv.sig_id = sig.sig_id
			where
				mv.offender_id = ?
			order by violations desc
		});
		$lsh->execute($id);
		$lsh;
	});
	$c->stash->{res_sth} = $sth;
}

sub ajax_node_details :Chained('node_details') :PathPart('ajax') :Args(0) {
	my ($self, $c) = @_;

	$c->stash->{template} = '/ajax/table.mas';
	my @rows = ();
	while( my $row = $c->stash->{res_sth}->fetchrow_hashref ) {
		push @rows, [ $row->{signature}, $row->{violations} ];
	}
	$c->stash->{entries} = \@rows;
	$c->stash->{header} = [ 'Signature Description', 'Violations' ];
}

#------------------------------------------------------------------------#
# Internal Methods
sub _build_filters {
	my ($self,$args) = @_;
	my $Today = DateTime->now();
	my %filter_build = (
		ip		=> {
			where		=> 'AND (evt.src_ip = ? or evt.dst_ip = ?)',
			args		=> sub {
				my $ip = shift;
				$ip =~ s/[^0-9\.]//g;
				return $ip, $ip;
			},
		},
		type => {
			where		=> q{AND etype.short = ?},
			args		=> sub {
				my $str = shift;
				return $str;
			},
		},
		signature => {
			where		=> q{AND to_tsvector('english', description) @@ to_tsquery( ? )},
			args		=> sub {
				my $str = lc shift;
				$str =~ s/\s+/_/g;
				return $str;
			}
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

1;
