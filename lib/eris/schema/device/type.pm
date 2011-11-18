package eris::schema::device::type;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::device::type

=cut

__PACKAGE__->table("eris_node_types");

=head1 ACCESSORS

=head2 node_type_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'eris_node_types_node_type_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 short

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 is_mobile

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 is_hub

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 has_parent

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "node_type_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "eris_node_types_node_type_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "short",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "is_mobile",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "is_hub",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "has_parent",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("node_type_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ri2QopRqBFUFSwMSViC/1A


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->has_many('devices', 'eris::schema::device::details', 'node_type_id' );
#------------------------------------------------------------------------#
1;
