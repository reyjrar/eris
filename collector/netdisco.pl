#!/usr/bin/env perl
#
# This grabs switch & port information from netdisco

use strict;
use warnings;

use Carp;
use YAML;
use File::Spec;
use File::Basename;
use DBI;

# Grab the Configuration
my @path = File::Spec->splitdir( File::Spec->rel2abs( dirname $0 ) );
# pop the collector directory
pop @path;
my $CFGFILE = File::Spec->catfile( @path, 'etc', 'eris.cfg' );
croak "config file missing ($CFGFILE)\n" unless -f $CFGFILE;

my $CONF = YAML::LoadFile( $CFGFILE );

my %DBH = ();
$DBH{eris} = DBI->connect( $CONF->{db_dsn}, $CONF->{db_user}, $CONF->{db_pass} )
	or croak "Unable to connect to DB( $CONF->{db_dsn} ): $DBI::errstr\n";
$DBH{netdisco} = DBI->connect( $CONF->{netdisco}{db_dsn}, $CONF->{netdisco}{db_user}, $CONF->{netdisco}{db_pass} )
	or croak "Unable to connect to DB( $CONF->{netdisco}{db_dsn} ): $DBI::errstr\n";

my @dbFields = qw(switch port mac time_first time_last vlan);

my %SQL = (
	eris => {
		reg_device	=> q{select sp_reg_device( 'netdisco', ?, ?, NULL, ? )},
		sp_exec => q{select sp_handle_netdisco( ?, ?, ?, ?, ?, ? )},
	},
	netdisco => {
		sel => q|
				select n.*,
					i.ip
				from node n
					left join node_ip i on n.mac = i.mac and i.active is true
						and i.time_last > now() - interval '3 days'
				where n.active is true
				and n.time_last > NOW() - interval '3 days'
		|,
		vlan => q{
			select vlan from device_port where ip = ? and port = ?
		},
	}
);

my %STH = ();

foreach my $db (keys %DBH) {
	foreach my $s (keys %{ $SQL{$db} } ){
		$STH{$db}{$s} = $DBH{$db}->prepare($SQL{$db}{$s});
	}
}

#
# Select the stuff from netdisco
$STH{netdisco}{sel}->execute;

#
# Insert the stuff into our local table
while( my $r = $STH{netdisco}{sel}->fetchrow_hashref ) {
	my %i = %$r;


	$STH{netdisco}{vlan}->execute( @i{qw(switch port)} );
	if( $STH{netdisco}{vlan}->rows > 0) {
		($i{vlan}) = $STH{netdisco}{vlan}->fetchrow_array;
	}

	if( $i{ip} ) {
		$STH{eris}{reg_device}->execute( @i{qw(mac ip time_last)} );
	}

	my $rc = $STH{eris}{sp_exec}->execute(@i{@dbFields});
}
