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
use Net::IP::Resolver;
use Regexp::Common qw(net);

use lib "$FindBin::Bin/../lib";
use eris::schema;

my $CONFIG_FILE = "$FindBin::Bin/../etc/eris.cfg";
my $CFG = YAML::LoadFile( $CONFIG_FILE ) or die "unable to parse $FindBin::Bin/../etc/eris.cfg\n";

my $schema = eris::schema->connect( $CFG->{db_dsn}, $CFG->{db_user}, $CFG->{db_pass} );

if( @ARGV != 4 ) {
	die "usage: $0 hostfile network reverse forward";
}
my ($FILE,$NET,$REVERSE,$FORWARD) = @ARGV;

my $reverse = $schema->resultset('dnsmgr::zones')->find( { name => $REVERSE } );
die "Invalid reverse zone: $REVERSE" unless defined $reverse;

my $forward = $schema->resultset('dnsmgr::zones')->find( { name => $FORWARD } );
die "Invalid forward zone: $FORWARD" unless defined $forward;



my $res = Net::IP::Resolver->new( );
$res->add( 'thiszone' => $NET ) or die "can't make sense of $NET";

open( my $FH, '<', $FILE ) or die "unable to open $FILE: $!";

while( my $line = <$FH> ) {
	chomp ($line);
	$line =~ s/\#.*//; # Strip comments
	next unless length $line;

	my ( $ip, @hosts ) = split /\s+/, $line;
	my $hostname;
	foreach my $ent (@hosts) {
		if( $ent !~ /\./ ) {
			$hostname = $ent;
		}
	}
	my $digit = (split /\./, $ip)[3];

	next unless $ip =~ /$RE{net}{IPv4}/;
	next unless $res->find_first( $ip );

	say "$ip is $hostname.$FORWARD";

	next unless defined $digit and defined $ip and defined $hostname;
	next if $OPT{d};

	my $rev_obj = $schema->resultset('dnsmgr::records')->find_or_create(
		zone_id => $reverse->zone_id,
		name	=>  $digit,
		class	=> 'IN',
		type	=> 'PTR',
		value 	=> "$hostname.$FORWARD.",
		mod_user_id => 1426,
		source => 'hosts',
	);
	$rev_obj->update;

	my $fwd_obj = $schema->resultset('dnsmgr::records')->find_or_create(
		zone_id => $forward->zone_id,
		name	=>  $hostname,
		class	=> 'IN',
		type	=> 'A',
		value 	=> $ip,
		mod_user_id => 1426,
		source => 'hosts',
	);
	$fwd_obj->update;
}
