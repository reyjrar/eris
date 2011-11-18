package eris::schema::user::groups;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::user::groups

=cut

__PACKAGE__->table("eris_ous");

=head1 ACCESSORS

=head2 ou_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'eris_ous_ou_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 short

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 external_code

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=cut

__PACKAGE__->add_columns(
  "ou_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "eris_ous_ou_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "short",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "external_code",
  { data_type => "varchar", is_nullable => 1, size => 64 },
);
__PACKAGE__->set_primary_key("ou_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IbmQcj/RPYZVbtHG8zm2dQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
