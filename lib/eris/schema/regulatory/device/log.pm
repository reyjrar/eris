package eris::schema::regulatory::device::log;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::regulatory::device::log

=cut

__PACKAGE__->table("regulatory_device_log");

=head1 ACCESSORS

=head2 reg_log_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'regulatory_device_log_reg_log_id_seq'

=head2 regulation_id

  data_type: 'integer'
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

=head2 device_id

  data_type: 'bigint'
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
  "reg_log_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "regulatory_device_log_reg_log_id_seq",
  },
  "regulation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "entry_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "device_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "comments",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("reg_log_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DQPgWUqEUoMQ3Zd4ydBTIA


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('user', 'eris::schema::user', 'user_id');
#------------------------------------------------------------------------#
1;
