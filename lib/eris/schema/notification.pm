package eris::schema::notification;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::notification

=cut

__PACKAGE__->table("notification_meta");

=head1 ACCESSORS

=head2 notification_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'notification_meta_notification_id_seq'

=head2 evt_type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 orig_admin_alert

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 orig_admin_message

  data_type: 'text'
  is_nullable: 1

=head2 orig_user_alert

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 orig_user_message

  data_type: 'text'
  is_nullable: 1

=head2 summary_admin_alert

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 summary_admin_message

  data_type: 'text'
  is_nullable: 1

=head2 summary_user_alert

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 summary_user_message

  data_type: 'text'
  is_nullable: 1

=head2 create_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 mod_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 mod_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 orig_admin_subject

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 orig_user_subject

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 summary_admin_subject

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 summary_user_subject

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 alert_from_address

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 summary_last_ts

  data_type: 'timestamp'
  is_nullable: 1

=head2 notification_interval

  data_type: 'interval'
  default_value: '30 days'
  is_nullable: 1

=head2 orig_user_file_id

  data_type: 'integer'
  is_nullable: 1

=head2 is_enabled

  data_type: 'boolean'
  default_value: true
  is_nullable: 1

=head2 min_events_trigger

  data_type: 'integer'
  default_value: 1
  is_nullable: 1

=head2 last_interval_ts

  data_type: 'timestamp'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "notification_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "notification_meta_notification_id_seq",
  },
  "evt_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "orig_admin_alert",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "orig_admin_message",
  { data_type => "text", is_nullable => 1 },
  "orig_user_alert",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "orig_user_message",
  { data_type => "text", is_nullable => 1 },
  "summary_admin_alert",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "summary_admin_message",
  { data_type => "text", is_nullable => 1 },
  "summary_user_alert",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "summary_user_message",
  { data_type => "text", is_nullable => 1 },
  "create_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "mod_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "mod_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "orig_admin_subject",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "orig_user_subject",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "summary_admin_subject",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "summary_user_subject",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "alert_from_address",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "summary_last_ts",
  { data_type => "timestamp", is_nullable => 1 },
  "notification_interval",
  { data_type => "interval", default_value => "30 days", is_nullable => 1 },
  "orig_user_file_id",
  { data_type => "integer", is_nullable => 1 },
  "is_enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
  "min_events_trigger",
  { data_type => "integer", default_value => 1, is_nullable => 1 },
  "last_interval_ts",
  { data_type => "timestamp", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("notification_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:kryesAR4+f5QKXO8WlnlFQ

#------------------------------------------------------------------------#
# Relationships

__PACKAGE__->has_one('event_type', 'eris::schema::event::type', { 'foreign.evt_type_id' => 'self.evt_type_id' } );
__PACKAGE__->has_one('attachment', 'eris::schema::notification::files',
	{ 'foreign.file_id' => 'self.orig_user_file_id' } );

# MANY-TO-MANY: Admins
__PACKAGE__->has_many('notify_admins', 'eris::schema::map::notification::admins',
		 { 'foreign.notification_id' => 'self.notification_id' });
__PACKAGE__->many_to_many('admins', 'notify_admins', 'admin' );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
