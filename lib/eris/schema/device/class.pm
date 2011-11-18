package eris::schema::device::class;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::device::class

=cut

__PACKAGE__->table("device_classes");

=head1 ACCESSORS

=head2 device_class_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'device_classes_device_class_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 80

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 type

  data_type: 'varchar'
  default_value: 'unknown'
  is_nullable: 1
  size: 20

=cut

__PACKAGE__->add_columns(
  "device_class_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "device_classes_device_class_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "type",
  {
    data_type => "varchar",
    default_value => "unknown",
    is_nullable => 1,
    size => 20,
  },
);
__PACKAGE__->set_primary_key("device_class_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gFAMEiwl07e1kMkD/bfPUg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
