#!/usr/bin/env perl
$|++;
use strict;
use warnings;

use DBI;
use Getopt::Std;
use FindBin;
use YAML;

my $ETC = "$FindBin::Bin/../etc";
my $CFG = YAML::LoadFile( qq{$ETC/eris.cfg} );

my %OPT=();
getopts('q',\%OPT);

#------------------------------------------------------------------------#
# Options
my %CFG = (
    db_dsn  => $CFG->{db_dsn},
    db_user => $CFG->{db_user},
    db_pass => $CFG->{db_pass},
    db_opts => { RaiseError => 1, PrintError => 1 },
);



#------------------------------------------------------------------------#
# Main
my $dbh = DBI->connect( @CFG{qw(db_dsn db_user db_pass db_opts)} )
    or die "db connect as $CFG{db_user}: $DBI::errstr\n";

# Set Search Path
$dbh->do('set search_path to matviews, public');

# Statements:
my %SQL = (
    'lock' => 'update matviews set is_locked = true where mv_name = ?',
    unlock => 'update matviews set is_locked = false where mv_name = ?',
    do_refresh => 'select refresh_matview(?)',
    get_list => q{select mv_name from matviews where last_refresh < NOW() - refresh_interval and is_locked is false}
);

# Prepare the Statements
my %STH =();
foreach my $st (keys %SQL) {
    $STH{$st} = $dbh->prepare($SQL{$st});
}

# Find refreshable views:
$STH{get_list}->execute();

while( my ($mv) = $STH{get_list}->fetchrow_array ) {
    print "locking .. " unless $OPT{q};
    $STH{lock}->execute( $mv );

    print "refreshing $mv .." unless $OPT{q};
    $STH{do_refresh}->execute( $mv );

    print "unlocking .. " unless $OPT{q};
    $STH{unlock}->execute( $mv );

    print " done.\n" unless $OPT{q};
}

