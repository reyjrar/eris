#!/usr/bin/env perl
#
# This script optimizes the pgsql DB
#
use strict;
use Getopt::Std;
use DBI;
use YAML;
use FindBin;

# Load Config
my $ETC = "$FindBin::Bin/../etc";
my $CFG = YAML::LoadFile( qq{$ETC/eris.cfg} );

my %OPT = ();
getopts('d', \%OPT);


my %SQL = (
	inventory_archive => q{delete from inventory_archive where event_ts < NOW() - interval '18 months'},
	security_events => q{delete from security_events where event_ts < NOW() - interval '18 months'},
);

my $dbh = DBI->connect($CFG->{db_dsn}, $CFG->{db_user}, $CFG->{db_pass}, { PrintError => 1 });

foreach my $t (keys %SQL) {
	local $|=1;
	print "pruning $t .. " if $OPT{d};
	$dbh->do($SQL{$t});
	print "done.\n" if $OPT{d};
}
