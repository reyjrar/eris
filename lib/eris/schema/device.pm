package eris::schema::device;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::device

=cut

__PACKAGE__->table("device_discovery");

=head1 ACCESSORS

=head2 device_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'device_discovery_device_id_seq'

=head2 ip_addr

  data_type: 'inet'
  is_nullable: 1

=head2 mac_addr

  data_type: 'macaddr'
  is_nullable: 0

=head2 first_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 last_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 clientid

  data_type: 'varchar'
  default_value: 'unknown'
  is_nullable: 1
  size: 150

=head2 discovery_method

  data_type: 'varchar'
  default_value: 'unknown'
  is_nullable: 1
  size: 20

=head2 is_verified

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "device_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "device_discovery_device_id_seq",
  },
  "ip_addr",
  { data_type => "inet", is_nullable => 1 },
  "mac_addr",
  { data_type => "macaddr", is_nullable => 0 },
  "first_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "last_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "clientid",
  {
    data_type => "varchar",
    default_value => "unknown",
    is_nullable => 1,
    size => 150,
  },
  "discovery_method",
  {
    data_type => "varchar",
    default_value => "unknown",
    is_nullable => 1,
    size => 20,
  },
  "is_verified",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("device_id");
__PACKAGE__->add_unique_constraint("idx_devices_macs", ["mac_addr"]);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KOzciorfmYkxpVBMOZ3wrA

#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->might_have('details', 'eris::schema::device::details', 'device_id' );
__PACKAGE__->might_have('overview', 'eris::schema::device::overview', 'device_id' );
__PACKAGE__->might_have('assigned_vlan', 'eris::schema::device::vlan::assigned', 'device_id');
__PACKAGE__->might_have('authentication', 'eris::schema::authen', 'device_id');
__PACKAGE__->has_many('services', 'eris::schema::device::services', 'device_id');

# MANY-TO-MANY: DEVICE CLASSES
__PACKAGE__->has_many('device_class', 'eris::schema::map::device::class', 'device_id');
__PACKAGE__->many_to_many('classes', 'device_class', 'class');

# MANY-TO-MANY: REGULATION COMPLIANCE
__PACKAGE__->has_many('map_regulatory_compliance', 'eris::schema::map::regulatory::compliance', 'device_id');
__PACKAGE__->many_to_many('compliant_regulations', 'map_regulatory_compliance', 'regulation');

# MANY-TO-MANY: DEVICE STATUS
__PACKAGE__->has_many('device_status', 'eris::schema::map::device::status', 'device_id');
__PACKAGE__->many_to_many('status', 'device_status', 'status');

#------------------------------------------------------------------------#
# You can replace this text with custom content, and it will be preserved on regeneration
1;
