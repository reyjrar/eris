package eris::schema::regulatory::waiver::log;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::regulatory::waiver::log

=cut

__PACKAGE__->table("regulatory_waiver_log");

=head1 ACCESSORS

=head2 waiver_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=head2 entry_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 status

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 comments

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "waiver_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "entry_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "comments",
  { data_type => "text", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:guDjxtlW4zbe5euCs1ev/A


# You can replace this text with custom content, and it will be preserved on regeneration
1;
