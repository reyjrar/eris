package eris::schema::notification::queue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::notification::queue

=cut

__PACKAGE__->table("notification_queue");

=head1 ACCESSORS

=head2 queue_no

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'notification_queue_queue_no_seq'

=head2 notification_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 to_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 first_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 last_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 events

  data_type: 'integer'
  is_nullable: 1

=head2 expire_ts

  data_type: 'timestamp'
  is_nullable: 0

=head2 orig_email_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 summary_email_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "queue_no",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "notification_queue_queue_no_seq",
  },
  "notification_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "to_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "first_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "last_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "events",
  { data_type => "integer", is_nullable => 1 },
  "expire_ts",
  { data_type => "timestamp", is_nullable => 0 },
  "orig_email_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "summary_email_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("queue_no");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:d20kNNzA6bx2ck9fan+1Og


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('to_user', 'eris::schema::user', { 'foreign.user_id' => 'self.to_user_id' } );
__PACKAGE__->has_one('orig_email', 'eris::schema::notification::email', { 'foreign.email_id' => 'self.orig_email_id' } );
__PACKAGE__->has_one('summary_email', 'eris::schema::notification::email', { 'foreign.email_id' => 'self.summary_email_id' } );
1;
