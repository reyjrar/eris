package eris::schema::dnsmgr::updates;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::dnsmgr::updates

=cut

__PACKAGE__->table("dnsmgr_updates");

=head1 ACCESSORS

=head2 zone_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 record_id

  data_type: 'bigint'
  is_nullable: 0

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
  is_nullable: 0
  size: 10

=head2 opt

  data_type: 'varchar'
  is_nullable: 1
  size: 35

=head2 value

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 request_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 status_ts

  data_type: 'timestamp'
  is_nullable: 1

=head2 status

  data_type: 'char'
  is_nullable: 1
  size: 10

=head2 is_complete

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 req_user_id

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 update_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dnsmgr_updates_update_id_seq'

=head2 action

  data_type: 'char'
  default_value: 'add'
  is_nullable: 0
  size: 3

=head2 source

  data_type: 'char'
  default_value: 'user'
  is_nullable: 1
  size: 5

=cut

__PACKAGE__->add_columns(
  "zone_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "record_id",
  { data_type => "bigint", is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "class",
  { data_type => "char", default_value => "IN", is_nullable => 0, size => 10 },
  "type",
  { data_type => "char", is_nullable => 0, size => 10 },
  "opt",
  { data_type => "varchar", is_nullable => 1, size => 35 },
  "value",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "request_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "status_ts",
  { data_type => "timestamp", is_nullable => 1 },
  "status",
  { data_type => "char", is_nullable => 1, size => 10 },
  "is_complete",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "req_user_id",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "update_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dnsmgr_updates_update_id_seq",
  },
  "action",
  { data_type => "char", default_value => "add", is_nullable => 0, size => 3 },
  "source",
  { data_type => "char", default_value => "user", is_nullable => 1, size => 5 },
);
__PACKAGE__->set_primary_key("update_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KhybEhwEF6o9nedicLHoRQ

__PACKAGE__->belongs_to( 'zone' => 'eris::schema::dnsmgr::zones' => 'zone_id' );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
