#!/usr/bin/env perl

use strict;
use warnings;
use YAML;
use FindBin;

use DBIx::Class::Schema::Loader qw/ make_schema_at /;

if( !-d './lib') {
    die "must be run in the root dir of eris!\n";
}

my $CONFIG_FILE = "$FindBin::Bin/../etc/eris.cfg";
my $CFG = YAML::LoadFile( $CONFIG_FILE ) or die "unable to parse $FindBin::Bin/../etc/eris.cfg\n";

make_schema_at(
    'eris::schema',
    {
        dump_directory=> './lib',
        exclude     => qr/(^pg_)|(^v_admin)|(^v_history)/,
        moniker_map => sub {
            my $table = shift;

            my %map = (
                authen_current                   => 'authen',
                device_classes                   => 'device::class',
                device_class_mapping             => 'map::device::class',
                device_details                   => 'device::details',
                device_discovery                 => 'device',
                device_parents                   => 'map::device::parents',
                device_waivers                   => 'map::device::waiver',
                eris_node_types                  => 'device::type',
                eris_ous                         => 'user::groups',
                eris_users                       => 'user',
                eris_role_map                    => 'map::roles',
                eris_roles                       => 'user::roles',
                ext_lab_pco                      => 'ext::lab_pco',
                ext_property_book                => 'ext::property_book',
                ext_surplus_sheets               => 'ext::surplus_sheets',
                ext_custodians                   => 'ext::custodians',
                fake_mac_addr                    => 'ext::fake_mac_addr',
                inventory_archive                => 'view::history',
                # Device Status
                device_status                    => 'device::status',
                map_device_status                => 'map::device::status',
                # Notification Tables
                notification_admins              => 'map::notification::admins',
                notification_meta                => 'notification',
                notification_queue               => 'notification::queue',
                notification_files               => 'notification::files',
                notification_email               => 'notification::email',
                map_notification_email_rcpts     => 'map::notification::rcpts',
                regulatory_application           => 'map::regulatory::application',
                regulatory_compliance            => 'map::regulatory::compliance',
                regulatory_device_log            => 'regulatory::device::log',
                regulatory_exception_classes     => 'regulatory::exception',
                regulatory_meta                  => 'regulatory::meta',
                regulatory_waivers_meta          => 'regulatory::waiver::meta',
                regulatory_waiver_log            => 'regulatory::waiver::log',
                regulatory_waivers               => 'regulatory::waiver',
                services                         => 'device::services',
                security_event_types             => 'event::type',
                security_events                  => 'event',
                security_signatures              => 'event::signature',
                sessions                         => 'sessions',
                switch_ports                     => 'device::switchport',
                switch_vlans                     => 'switch::vlans',
                syslog_archive                   => 'log::syslog',
                vlan_assignment                  => 'device::vlan::assigned',
                vlan_discovered                  => 'device::vlan::discovered',
                v_daily_authentication           => 'view::AuthOverview',
                v_device_overview                => 'device::overview',
                v_security_offenders_bytype      => 'view::offenders::bytype',
                # DNS MGR
                dnsmgr_zones                     => 'dnsmgr::zones',
                dnsmgr_records                   => 'dnsmgr::records',
                dnsmgr_updates                   => 'dnsmgr::updates',
                dnsmgr_ip_mgt                    => 'dnsmgr::meta',
                dnsmgr_ip_mgt_range              => 'dnsmgr::meta::range',
                dnsmgr_ip_mgt_records            => 'dnsmgr::meta::record',
                # Materialized Views
                mv_security_offenders_sig_30days => 'view::event::offenders::30days',
            );

            return $map{$table} if exists $map{$table};

            my $pre = '';
            if( $table =~ /^v_/ ) {
                $pre = 'view::';
                $table =~ s/^v_//;
            }

            return $pre . join('', map ucfirst, split /[\W_]+/, lc $table);
        },
        skip_relationships => 1,
        components => [qw(InflateColumn::DateTime PK::Auto)],
    },
    [ $CFG->{db_dsn}, $CFG->{db_user}, $CFG->{db_pass} ]

);
