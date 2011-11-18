package eris::schema::user;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::user

=cut

__PACKAGE__->table("eris_users");

=head1 ACCESSORS

=head2 user_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'eris_users_user_id_seq'

=head2 username

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 external_id

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 display_name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 first_name

  data_type: 'varchar'
  is_nullable: 0
  size: 120

=head2 last_name

  data_type: 'varchar'
  is_nullable: 0
  size: 134

=head2 can_login

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 is_admin

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 is_active

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 orgid

  data_type: 'varchar'
  is_nullable: 1
  size: 15

=head2 lab

  data_type: 'varchar'
  is_nullable: 1
  size: 15

=head2 ext_last_logon_ts

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "user_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "eris_users_user_id_seq",
  },
  "username",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "external_id",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "display_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "first_name",
  { data_type => "varchar", is_nullable => 0, size => 120 },
  "last_name",
  { data_type => "varchar", is_nullable => 0, size => 134 },
  "can_login",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "is_admin",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "is_active",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "orgid",
  { data_type => "varchar", is_nullable => 1, size => 15 },
  "lab",
  { data_type => "varchar", is_nullable => 1, size => 15 },
  "ext_last_logon_ts",
  { data_type => "timestamp", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("user_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pMUAQxGQsuyBb0/LQbsHew

#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->has_many('owned_devices','eris::schema::device::details', 
	{ 'foreign.primary_user_id' => 'self.user_id'} );
__PACKAGE__->has_many('authentications','eris::schema::authen', 'user_id');
#------------------------------------------------------------------------#

#------------------------------------------------------------------------#
# Many-to-many
__PACKAGE__->has_many('map_user_role', 'eris::schema::map::roles', 'user_id');
__PACKAGE__->many_to_many('roles','map_user_role','role');
#------------------------------------------------------------------------#

# You can replace this text with custom content, and it will be preserved on regeneration
1;
