package eris::schema::log::syslog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::log::syslog

=cut

__PACKAGE__->table("syslog_archive");

=head1 ACCESSORS

=head2 priority

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 priority_int

  data_type: 'integer'
  is_nullable: 0

=head2 facility

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 facility_int

  data_type: 'integer'
  is_nullable: 0

=head2 event_ts

  data_type: 'timestamp'
  is_nullable: 0

=head2 hostname

  data_type: 'varchar'
  is_nullable: 0
  size: 80

=head2 domain

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 program_name

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 program_pid

  data_type: 'integer'
  is_nullable: 1

=head2 program_sub

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 content

  data_type: 'text'
  is_nullable: 0

=head2 entry_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 message_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'syslog_archive_message_id_seq'

=cut

__PACKAGE__->add_columns(
  "priority",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "priority_int",
  { data_type => "integer", is_nullable => 0 },
  "facility",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "facility_int",
  { data_type => "integer", is_nullable => 0 },
  "event_ts",
  { data_type => "timestamp", is_nullable => 0 },
  "hostname",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "domain",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "program_name",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "program_pid",
  { data_type => "integer", is_nullable => 1 },
  "program_sub",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "content",
  { data_type => "text", is_nullable => 0 },
  "entry_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "message_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "syslog_archive_message_id_seq",
  },
);
__PACKAGE__->set_primary_key("message_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:2G/X3J3omls28SBPQ0LkmA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
