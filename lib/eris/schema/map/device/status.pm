package eris::schema::map::device::status;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::map::device::status

=cut

__PACKAGE__->table("map_device_status");

=head1 ACCESSORS

=head2 device_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 0

=head2 status_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 mod_user_id

  data_type: 'integer'
  is_nullable: 0

=head2 mod_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 is_archived

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 map_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'map_device_status_map_id_seq'

=cut

__PACKAGE__->add_columns(
  "device_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "mod_user_id",
  { data_type => "integer", is_nullable => 0 },
  "mod_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "is_archived",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "map_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "map_device_status_map_id_seq",
  },
);
__PACKAGE__->set_primary_key("map_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hBumx73tyLeAv0TJzOcVzA

#------------------------------------------------------------------------#
# Relationship
__PACKAGE__->belongs_to('status', 'eris::schema::device::status', 'status_id');
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id');
__PACKAGE__->belongs_to('mod_user', 'eris::schema::user', { 'foreign.user_id' => 'self.mod_user_id' });
#------------------------------------------------------------------------#

# You can replace this text with custom content, and it will be preserved on regeneration
1;
