package eris::schema::switch::vlans;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::switch::vlans

=cut

__PACKAGE__->table("switch_vlans");

=head1 ACCESSORS

=head2 vlan_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'switch_vlans_vlan_id_seq'

=head2 vlan_specifier

  data_type: 'varchar'
  is_nullable: 0
  size: 25

=head2 vlan_name

  data_type: 'varchar'
  is_nullable: 0
  size: 80

=head2 vlan_type

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 nac_managed

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 nac_specifier

  data_type: 'varchar'
  is_nullable: 1
  size: 40

=head2 description

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "vlan_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "switch_vlans_vlan_id_seq",
  },
  "vlan_specifier",
  { data_type => "varchar", is_nullable => 0, size => 25 },
  "vlan_name",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "vlan_type",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "nac_managed",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "nac_specifier",
  { data_type => "varchar", is_nullable => 1, size => 40 },
  "description",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("vlan_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GbPpov9b1YysMEp+QkbWYg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
