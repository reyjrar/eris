package eris::schema::map::device::parents;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::map::device::parents

=cut

__PACKAGE__->table("device_parents");

=head1 ACCESSORS

=head2 parent_id

  data_type: 'bigint'
  is_nullable: 0

=head2 child_id

  data_type: 'bigint'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "parent_id",
  { data_type => "bigint", is_nullable => 0 },
  "child_id",
  { data_type => "bigint", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("parent_id", "child_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9Wn97Q5LJWgGBjq3nTXMPQ

# You can replace this text with custom content, and it will be preserved on regeneration
1;
