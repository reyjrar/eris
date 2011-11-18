package eris::schema::regulatory::waiver;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::regulatory::waiver

=cut

__PACKAGE__->table("regulatory_waivers");

=head1 ACCESSORS

=head2 meta_waiver_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 waiver_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'regulatory_waivers_waiver_id_seq'

=head2 create_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 close_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 status

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=cut

__PACKAGE__->add_columns(
  "meta_waiver_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "waiver_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "regulatory_waivers_waiver_id_seq",
  },
  "create_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "close_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 15 },
);
__PACKAGE__->set_primary_key("waiver_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mEl91DZjRYjc8dOnhlcUsQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
