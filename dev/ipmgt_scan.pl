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
use Net::Ping;
use Net::DNS;
use Net::IP;
use Data::Dumper;

use lib "$FindBin::Bin/../lib";
use eris::schema;

# Find and Connect the Database
my $CONFIG_FILE = "$FindBin::Bin/../etc/eris.cfg";
my $CFG = YAML::LoadFile( $CONFIG_FILE ) or die "unable to parse $FindBin::Bin/../etc/eris.cfg\n";

my $schema = eris::schema->connect( $CFG->{db_dsn}, $CFG->{db_user}, $CFG->{db_pass} );

# Argument Handling
if( @ARGV < 2 ) {
    die "usage: $0 mgt_id <list of DNS Servers to check>";
}
my ($MGTID,@nameservers) = @ARGV;

# Setup the Resolver
my $resolver = Net::DNS::Resolver->new();

# Setup the Pinger
my $pinger = Net::Ping->new();

#
# Prepare the SQL
my %SQL = (
    range_sel => q{select * from dnsmgr_ip_mgt_range where mgt_id = ? and range_used < range_total},
    ip_sel => q{SELECT count(1) from dnsmgr_ip_mgt_records where range_id = ? and ip = ?},
);
my %STH = ();
foreach my $s (keys %SQL) {
    $STH{$s} = $schema->storage->dbh->prepare( $SQL{$s} );
}

$STH{range_sel}->execute( $MGTID );

while( my $rec = $STH{range_sel}->fetchrow_hashref ) {

    my $range = Net::IP->new( "$rec->{range_start} - $rec->{range_stop}" );
    my $size = $range->size;

    do {
        my $ip = $range->ip;

        $STH{ip_sel}->execute( $rec->{range_id}, $ip );
        my ($isTaken) = $STH{ip_sel}->fetchrow_array;

        if( !$isTaken ) {
            # DNS Check
            my @dns_entries = ();
            foreach my $ns ( @nameservers ) {
                $resolver->nameserver( $ns );
                my $query = $resolver->query( $ip );
                if( defined $query ) {
                    foreach my $rr ( $query->answer ) {
                        if( $rr->type eq 'PTR' ) { push @dns_entries, "\t $ns has $ip = PTR " . $rr->ptrdname . "\n"; }
                    }
                }
            }
            # Ping Check
            my $status = $pinger->ping($ip) ? 'up' : 'down';
            say "$ip is $status";
            print @dns_entries if @dns_entries;
        }
    } while( ++$range );

}
