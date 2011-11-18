package eris::dnsmgr::read::dbic;

use strict;
use warnings;
use Try::Tiny;
use eris::schema;
use POE;

=head1 NAME

eris::dnsmgr::read::dbic

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

POE Session for retrieving updates from a database via a DBIx::Class Model

	use eris::dnsmgr::read::dbic;

	my $reader_sessid = eris::dnsmgr::read::dbic->spawn(
			cb_sesssion => 'processor',
			cb_prefix	=> 'dnswrite',
			db_dsn		=> 'dbi:...',			# required
			db_user		=> 'user',				# required
			db_pass		=> 'pass',				# required
			interval	=> 90, # seconds		
			log_sid 	=> 'log', # default
	);

cb_session must be able to dispatch the following events:

	$cb_prefix . '_add'		=> Arguments( Zone, Record, Update_Object ),
	$cb_prefix . '_del'		=> Arguments( Zone, Record, Update_Object ),
	$cb_prefix . '_upd'		=> Arguments( Zone, Record, Update_Object ),

=head1 EXPORT

eris::dnsmgr::read::dbic does not export any symbols.

=head1 FUNCTIONS

=head2 spawn

Creates the POE::Session for the DB Reader

Parameters:
	cb_sesssion => 'processor',
	cb_prefix	=> 'dnswrite',
	db_dsn		=> 'dbi:...',			# required
	db_user		=> 'user',				# required
	db_pass		=> 'pass',				# required
	interval	=> 90, # seconds		
	log_sid 	=> 'log', # default

=cut


sub spawn {
	my $type = shift;

	#
	# Param Setup
	my %args = (
		cb_session		=> 'processor',
		cb_prefix		=> 'dnswrite',  #default
		interval		=> 90, 			#default
		log_sid			=> 'log',		#default
		@_
	);

	# Validation
	my @required = qw( db_dsn db_user db_pass );
	foreach my $p (@required) {
		die "__PACAKGE__ requires parameter $p to be set!\n" unless defined $args{$p};
	}

	return POE::Session->create( inline_states => {
			_start		=> sub { my ($k,$h) = @_[KERNEL,HEAP]; _build( $k, $h, %args ) },
			_stop		=> sub { },
			check_db	=> \&check_db,
			get_meta	=> \&get_meta,
			get_updates	=> \&get_updates,
	});

}


=head2 _build

Sets up the retrieval process

=cut 

sub _build {
	my ($kernel,$heap,%args) = @_;

	# Store our Arguments
	$heap->{args} = \%args;

	# Connect to the Database
	$kernel->yield( 'check_db' );

	# Do the first refresh
	$kernel->delay_add( 'get_updates', 5 );
}

sub check_db {
	my ($kernel,$heap) = @_[KERNEL,HEAP];

	if( !exists $heap->{model} || !defined $heap->{model} ) {
		my %args = %{ $heap->{args} };
		# Connect to the database
		$heap->{model} = eris::schema->connect(@args{qw(db_dsn db_user db_pass)});
		$kernel->post( $args{log_sid} => notice => "connecting to $args{db_dsn}" );

		# Retrieve Meta Data	
		$kernel->yield( 'get_meta' );
	}
	$kernel->delay_add('check_db', 3600);
}

sub get_meta { 
	my ($kernel,$heap) = @_[KERNEL,HEAP];
	my %args = %{ $heap->{args} };

	my $zone_rs = $heap->{model}->resultset('dnsmgr::zones')->search( { name => $args{zones} } );
	my @zone_ids = ();
	while( my $zone = $zone_rs->next ) {
		push @zone_ids, $zone->zone_id;
	}
	$heap->{meta}{zone_ids} = \@zone_ids;
	$kernel->post( $args{log_sid} => 'info' => 'loaded the following zone ids: ' . join( ', ', @zone_ids ) );
}

sub get_updates {
	my ($kernel, $heap) = @_[KERNEL,HEAP];
	my %args = %{ $heap->{args} };

	$kernel->post( $args{log_sid} => debug => 'checking for updates' );

	my $update_rs = $heap->{model}->resultset('dnsmgr::updates')->search(
		{		is_complete => 0,
				zone_id => $heap->{meta}{zone_ids}
		},
		{
			order_by => 'request_ts asc'
		}
	);

	while( my $upd = $update_rs->next ) {
		my @record = (join('.', $upd->name, $upd->zone->name), $upd->class, $upd->type);
		if( defined $upd->opt ) { push @record, $upd->opt; };
		push @record, $upd->value;
		my $record = join(' ', @record );
		$record =~ s/\s+/ /g;
		$kernel->call( $args{cb_session} => join('_', $args{cb_prefix}, $upd->action), $upd->zone->name, $record, $upd );

		$upd->is_complete(1);
		$upd->update;
	}

	$kernel->delay_add( 'get_updates', $args{interval} );
}

# Return True
1;
