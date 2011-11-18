package eris::schema::user::roles;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::user::roles

=cut

__PACKAGE__->table("eris_roles");

=head1 ACCESSORS

=head2 role_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'eris_roles_role_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 25

=cut

__PACKAGE__->add_columns(
  "role_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "eris_roles_role_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 25 },
);
__PACKAGE__->set_primary_key("role_id");
__PACKAGE__->add_unique_constraint("uniq_eris_role_name", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7aUdGY2yjn8cSEcxYmrkcA

#------------------------------------------------------------------------#
# Many-to-Many
__PACKAGE__->has_many(map_user_role => 'eris::schema::map::roles', 'role_id');
#------------------------------------------------------------------------#

# You can replace this text with custom content, and it will be preserved on regeneration
1;
