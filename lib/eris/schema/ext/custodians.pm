package eris::schema::ext::custodians;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::ext::custodians

=cut

__PACKAGE__->table("ext_custodians");

=head1 ACCESSORS

=head2 uniq_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'ext_custodians_uniq_id_seq'

=head2 custodial_code

  data_type: 'integer'
  is_nullable: 1

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 custodian_name

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=cut

__PACKAGE__->add_columns(
  "uniq_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "ext_custodians_uniq_id_seq",
  },
  "custodial_code",
  { data_type => "integer", is_nullable => 1 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "custodian_name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
);
__PACKAGE__->set_primary_key("uniq_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:j3kt4Vse7zydx+YoZzll9A


__PACKAGE__->belongs_to('user', 'eris::schema::user', 'user_id');

1;
