package eris::schema::ext::lab_pco;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::ext::lab_pco

=cut

__PACKAGE__->table("ext_lab_pco");

=head1 ACCESSORS

=head2 unique_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'ext_lab_pco_unique_id_seq'

=head2 lab

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "unique_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "ext_lab_pco_unique_id_seq",
  },
  "lab",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("unique_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AK00xGqTwiEXrTYFAPw1mQ


__PACKAGE__->belongs_to('user', 'eris::schema::user', 'user_id');

1;
