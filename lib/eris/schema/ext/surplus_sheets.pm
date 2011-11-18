package eris::schema::ext::surplus_sheets;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::ext::surplus_sheets

=cut

__PACKAGE__->table("ext_surplus_sheets");

=head1 ACCESSORS

=head2 property_tag

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=cut

__PACKAGE__->add_columns(
  "property_tag",
  { data_type => "varchar", is_nullable => 0, size => 10 },
);
__PACKAGE__->set_primary_key("property_tag");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4CGBJr/jRDG7kZdx3aLuIw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
