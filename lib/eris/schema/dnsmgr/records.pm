package eris::schema::dnsmgr::records;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::dnsmgr::records

=cut

__PACKAGE__->table("dnsmgr_records");

=head1 ACCESSORS

=head2 zone_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 record_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dnsmgr_records_record_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 class

  data_type: 'char'
  default_value: 'IN'
  is_nullable: 0
  size: 10

=head2 type

  data_type: 'char'
  is_nullable: 1
  size: 10

=head2 opt

  data_type: 'varchar'
  is_nullable: 1
  size: 35

=head2 value

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 priority

  data_type: 'smallint'
  default_value: 5
  is_nullable: 0

=head2 parent_id

  data_type: 'bigint'
  default_value: 0
  is_nullable: 1

=head2 mod_user_id

  data_type: 'integer'
  is_nullable: 1

=head2 mod_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 source

  data_type: 'char'
  default_value: 'user'
  is_nullable: 0
  size: 5

=cut

__PACKAGE__->add_columns(
  "zone_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "record_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dnsmgr_records_record_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "class",
  { data_type => "char", default_value => "IN", is_nullable => 0, size => 10 },
  "type",
  { data_type => "char", is_nullable => 1, size => 10 },
  "opt",
  { data_type => "varchar", is_nullable => 1, size => 35 },
  "value",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "priority",
  { data_type => "smallint", default_value => 5, is_nullable => 0 },
  "parent_id",
  { data_type => "bigint", default_value => 0, is_nullable => 1 },
  "mod_user_id",
  { data_type => "integer", is_nullable => 1 },
  "mod_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "source",
  { data_type => "char", default_value => "user", is_nullable => 0, size => 5 },
);
__PACKAGE__->set_primary_key("record_id");
__PACKAGE__->add_unique_constraint(
  "uniq_dnsmgr_record",
  ["zone_id", "name", "class", "type", "opt", "value"],
);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vx+a606GnF4v/Rrb9Z4RuQ


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('zone', 'eris::schema::dnsmgr::zones', 'zone_id');

1;
