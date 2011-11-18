package eris::schema::device::vlan::discovered;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::device::vlan::discovered

=cut

__PACKAGE__->table("vlan_discovered");

=head1 ACCESSORS

=head2 vlan_discovery_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'vlans_discovered_vlan_discovery_id_seq'

=head2 device_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 vlan_id

  data_type: 'integer'
  is_foreign_key: 1
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

=head2 is_active

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

=head2 discovery_method

  data_type: 'varchar'
  default_value: 'unknown'
  is_nullable: 0
  size: 25

=cut

__PACKAGE__->add_columns(
  "vlan_discovery_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "vlans_discovered_vlan_discovery_id_seq",
  },
  "device_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "vlan_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
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
  "is_active",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "discovery_method",
  {
    data_type => "varchar",
    default_value => "unknown",
    is_nullable => 0,
    size => 25,
  },
);
__PACKAGE__->set_primary_key("vlan_discovery_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:30oZJKzMBov5ETPvUs9Anw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
