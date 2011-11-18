#!/usr/bin/env perl

use feature ':5.10';
use strict;
use warnings;
no utf8;
use Getopt::Std;

my %OPT;
getopts('d',\%OPT);

use FindBin;
use YAML;
use Net::DNS;
use Data::Dumper;
use Regexp::Common qw(net);

use lib "$FindBin::Bin/../lib";
use eris::schema;

my $CONFIG_FILE = "$FindBin::Bin/../etc/eris.cfg";
my $CFG = YAML::LoadFile( $CONFIG_FILE ) or die "unable to parse $FindBin::Bin/../etc/eris.cfg\n";

my $schema = eris::schema->connect( $CFG->{db_dsn}, $CFG->{db_user}, $CFG->{db_pass} );

if( @ARGV != 3 ) {
	die "usage: $0 zone.on.ns nameserver new_forward";
}
my ($ZONE,$NS,$FORWARD) = @ARGV;

my $reverse = $schema->resultset('dnsmgr::zones')->find( { name => $ZONE } );
die "Invalid reverse zone: $ZONE" unless defined $reverse;

my $forward = $schema->resultset('dnsmgr::zones')->find( { name => $FORWARD } );
die "Invalid forward zone: $FORWARD" unless defined $forward;



my $res = Net::DNS::Resolver->new( nameservers => [$NS] );

my @zone = $res->axfr( $ZONE );

foreach my $rr (@zone) {
	my ($digit,$ip,$hostname);
	if( $rr->type eq 'PTR' ) {
		my @parts = split /\./, $rr->name;
		$digit = $parts[0];
		$ip = join('.', reverse( @parts[0..3] ));
		$hostname = (split /\./, $rr->ptrdname)[0];
		say "$ip is $hostname.$FORWARD";
	}

	next if $OPT{d};

	next unless defined $digit and defined $ip and defined $hostname;

	next unless $ip =~ /$RE{net}{IPv4}/;

	my $rev_obj = $schema->resultset('dnsmgr::records')->find_or_create(
		zone_id => $reverse->zone_id,
		name	=>  $digit,
		class	=> 'IN',
		type	=> 'PTR',
		value	=> "$hostname.$FORWARD.",
		mod_user_id => 1426,
	);
	$rev_obj->source( 'axfr' );
	$rev_obj->update;

	my $fwd_obj = $schema->resultset('dnsmgr::records')->find_or_create(
		zone_id => $forward->zone_id,
		name	=>  $hostname,
		class	=> 'IN',
		type	=> 'A',
		value	=> $ip,
		mod_user_id => 1426,
	);
	$fwd_obj->source( 'axfr' );
	$fwd_obj->update;

}
