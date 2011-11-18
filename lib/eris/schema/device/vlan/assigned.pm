package eris::schema::device::vlan::assigned;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::device::vlan::assigned

=cut

__PACKAGE__->table("vlan_assignment");

=head1 ACCESSORS

=head2 assign_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'vlan_assignment_assign_id_seq'

=head2 device_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 vlan_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 is_active

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

=head2 assign_ts

  data_type: 'time'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 assign_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 assign_notes

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 assign_type

  data_type: 'varchar'
  default_value: 'automatic'
  is_nullable: 0
  size: 25

=head2 immutable

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

Disallows Changing of VLANs by automated processes

=cut

__PACKAGE__->add_columns(
  "assign_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "vlan_assignment_assign_id_seq",
  },
  "device_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "vlan_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_active",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "assign_ts",
  {
    data_type     => "time",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "assign_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "assign_notes",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "assign_type",
  {
    data_type => "varchar",
    default_value => "automatic",
    is_nullable => 0,
    size => 25,
  },
  "immutable",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("assign_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4hDUwVpqPuFM2bHdi1hHUQ

#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id');
__PACKAGE__->belongs_to('vlan', 'eris::schema::switch::vlans', 'vlan_id');
#------------------------------------------------------------------------#


1;
