#!/usr/bin/env perl
#
# This script optimizes the pgsql DB
#
use strict;
use DBI;
use YAML;
use FindBin;
use Getopt::Long;

my %OPT = ();
GetOptions(\%OPT, 'mode=s');

my $ETC = "$FindBin::Bin/../etc";
my $CFG = YAML::LoadFile( qq{$ETC/eris.cfg} );

my @tables = qw(
	authen_current
	device_class_mapping device_classes device_details
	device_discovery device_waivers
	eris_node_types eris_ous eris_role_map eris_roles
	eris_users ext_custodians ext_lab_pco ext_property_book
	ext_surplus_sheets fake_mac_addr inventory_archive	
	notification_admins notification_meta notification_queue
	regulatory_application regulatory_compliance regulatory_device_log
	regulatory_exception_classes regulatory_meta regulatory_waiver_log
	regulatory_waivers regulatory_waivers_meta
	security_event_types security_events security_signatures
	services sessions switch_ports switch_vlans syslog_archive
	vlan_assignment vlan_discovered
);

my %sql = (
	full => 'vacuum full analyze',
	reindex	=> 'reindex table',
	cluster => 'cluster'
);

my $dbh = DBI->connect($CFG->{db_dsn}, $CFG->{db_user}, $CFG->{db_pass}, { PrintError => 1 });

foreach my $t (@tables) {
	my $sql = join(' ', $sql{$OPT{mode}}, $t);
	$dbh->do($sql);
}
