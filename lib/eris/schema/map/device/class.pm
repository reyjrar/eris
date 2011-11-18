package eris::schema::map::device::class;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::map::device::class

=cut

__PACKAGE__->table("device_class_mapping");

=head1 ACCESSORS

=head2 device_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=head2 device_class_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 entry_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "device_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "device_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "entry_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zX84iy24P7r4bVgmBdOxVg


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('class', 'eris::schema::device::class', 'device_class_id');
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id');
#------------------------------------------------------------------------#
1;
