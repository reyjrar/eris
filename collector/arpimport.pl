#!/usr/bin/env perl
#
# get information from an arp.dat file,
# insert it into the netdisco node_ip table.
#

use strict;
use Carp;
use YAML;
use DateTime;
use File::Spec;
use File::Basename;
use DBI;

my $FILE = shift @ARGV;

die "usage: $0 /path/to/arpwatch.dat\n" unless length $FILE;

# Grab the Configuration
my @path = File::Spec->splitdir( File::Spec->rel2abs( dirname $0 ) );
# pop the collector directory
pop @path;
my $CFGFILE = File::Spec->catfile( @path, 'etc', 'eris.cfg' );
croak "config file missing ($CFGFILE)\n" unless -f $CFGFILE;

my $CONF = YAML::LoadFile( $CFGFILE );

my $dbh = DBI->connect( $CONF->{db_dsn}, $CONF->{db_user}, $CONF->{db_pass} )
	or croak "Unable to connect to DB( $CONF->{db_dsn} ) : $DBI::errstr\n";


open(my $arp_fh, '<', $FILE)
	or croak "cannot read $FILE: $!\n";

my %SQL = (
	'sp_exec' => 'select sp_handle_arpwatch( ?, ?, ?, ? )',
);

my %STH = ();
foreach my $sql ( keys %SQL ) {
	$STH{$sql} = $dbh->prepare($SQL{$sql});
}
my $TOTAL = 0;

my $GRAB = time - (60*60*24);
while(local $_ = <$arp_fh>) {
	my($macOrig,$ip,$time,$host) = split /\s+/;

	#
	# Check if time is in the last 24 hours
	next unless $time > $GRAB;

	my @macArray = ();
	foreach my $d ( split ':', $macOrig ) {
		$d = '0' . $d if length $d == 1;
		push @macArray, $d;
	}
	my $mac = join(':',@macArray);

	my $dt = DateTime->from_epoch( epoch => $time, time_zone => 'America/New_York' );

	my @args = map { length $_ ? $_ : undef; } ($ip, $mac, $dt->datetime, $host);

	$STH{sp_exec}->execute( @args );

	if( $STH{sp_exec}->errstr ) {
		print STDERR "Error inserting $mac = $ip: ", $STH{sp_exec}->errstr, "\n";
	}
	else {
		$TOTAL++;
	}
}
close $arp_fh;

print "Imported $TOTAL devices from $FILE\n";

foreach my $sth (values %STH) {
	$sth->finish;
}

$dbh->disconnect;
exit 0;
