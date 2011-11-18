package eris::schema::device::details;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::device::details

=head1 DESCRIPTION

This holds all the user editable fields for the device discovery table.

=cut

__PACKAGE__->table("device_details");

=head1 ACCESSORS

=head2 device_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 property_tag

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 node_type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 mod_ts

  data_type: 'timestamp'
  is_nullable: 1

=head2 mod_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 primary_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 make_model

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 notes

  data_type: 'text'
  is_nullable: 1

=head2 serial_no

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "device_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "property_tag",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "node_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "mod_ts",
  { data_type => "timestamp", is_nullable => 1 },
  "mod_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "primary_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "make_model",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "notes",
  { data_type => "text", is_nullable => 1 },
  "serial_no",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("device_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-08-01 13:30:06
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0yjyib3+K2E5V4fZMDdXFg


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('node_type', 'eris::schema::device::type', 'node_type_id');
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id' );
__PACKAGE__->might_have('primary_user', 'eris::schema::user',
		{ 'foreign.user_id' => 'self.primary_user_id' } );
#------------------------------------------------------------------------#
1;
