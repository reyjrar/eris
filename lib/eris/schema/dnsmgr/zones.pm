package eris::schema::dnsmgr::zones;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::dnsmgr::zones

=cut

__PACKAGE__->table("dnsmgr_zones");

=head1 ACCESSORS

=head2 zone_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dnsmgr_zones_zone_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 type

  data_type: 'char'
  default_value: 'forward'
  is_nullable: 0
  size: 7

=head2 accept

  data_type: 'varchar'
  default_value: 'any'
  is_nullable: 0
  size: 20

=head2 zone_priority

  data_type: 'integer'
  default_value: 10
  is_nullable: 0

=head2 accept_inet

  data_type: 'inet'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "zone_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dnsmgr_zones_zone_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "type",
  {
    data_type => "char",
    default_value => "forward",
    is_nullable => 0,
    size => 7,
  },
  "accept",
  {
    data_type => "varchar",
    default_value => "any",
    is_nullable => 0,
    size => 20,
  },
  "zone_priority",
  { data_type => "integer", default_value => 10, is_nullable => 0 },
  "accept_inet",
  { data_type => "inet", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("zone_id");
__PACKAGE__->add_unique_constraint("uniq_dnsmgr_zone", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FqUgZoR125hCoKjh/8tR1Q


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->has_many('records', 'eris::schema::dnsmgr::records', 'zone_id');
1;
