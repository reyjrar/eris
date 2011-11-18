package eris::schema::device::switchport;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::device::switchport - This table stores Switch and Port relations.

=cut

__PACKAGE__->table("switch_ports");

=head1 ACCESSORS

=head2 switch_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 port_num

  data_type: 'varchar'
  is_nullable: 0
  size: 30

=head2 device_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 first_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 last_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 sp_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'switch_ports_sp_id_seq'

=head2 vlan_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "switch_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "port_num",
  { data_type => "varchar", is_nullable => 0, size => 30 },
  "device_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "first_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "last_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "sp_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "switch_ports_sp_id_seq",
  },
  "vlan_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("sp_id");
__PACKAGE__->add_unique_constraint("idx_switch_ports_devices", ["device_id"]);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uu72c9TKZFwnVbsqQpXC3g


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id');
__PACKAGE__->belongs_to('switch', 'eris::schema::device',
	{ 'foreign.device_id' => 'self.switch_id' });
#------------------------------------------------------------------------#
1;
