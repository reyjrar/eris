package eris::schema::map::roles;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::map::roles

=cut

__PACKAGE__->table("eris_role_map");

=head1 ACCESSORS

=head2 role_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "role_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("role_id", "user_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dmKmvQBBHuraamMWE31sgQ
__PACKAGE__->belongs_to('user', 'eris::schema::user', 'user_id' );
__PACKAGE__->belongs_to('role', 'eris::schema::user::roles', 'role_id' );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
