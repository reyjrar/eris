package eris::schema::event;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::event

=cut

__PACKAGE__->table("security_events");

=head1 ACCESSORS

=head2 evt_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'security_events_evt_id_seq'

=head2 sensor

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 sensor_id

  data_type: 'integer'
  is_nullable: 1

=head2 event_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 src_ip

  data_type: 'inet'
  is_nullable: 1

=head2 src_port

  data_type: 'integer'
  is_nullable: 1

=head2 src_username

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 src_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 src_id

  data_type: 'integer'
  is_nullable: 1

=head2 dst_ip

  data_type: 'inet'
  is_nullable: 1

=head2 dst_port

  data_type: 'integer'
  is_nullable: 1

=head2 dst_username

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=head2 dst_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 dst_id

  data_type: 'integer'
  is_nullable: 1

=head2 message

  data_type: 'text'
  is_nullable: 1

=head2 sig_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 week_id

  data_type: 'char'
  default_value: 0
  is_nullable: 0
  size: 6

=cut

__PACKAGE__->add_columns(
  "evt_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "security_events_evt_id_seq",
  },
  "sensor",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "sensor_id",
  { data_type => "integer", is_nullable => 1 },
  "event_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "src_ip",
  { data_type => "inet", is_nullable => 1 },
  "src_port",
  { data_type => "integer", is_nullable => 1 },
  "src_username",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "src_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "src_id",
  { data_type => "integer", is_nullable => 1 },
  "dst_ip",
  { data_type => "inet", is_nullable => 1 },
  "dst_port",
  { data_type => "integer", is_nullable => 1 },
  "dst_username",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "dst_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "dst_id",
  { data_type => "integer", is_nullable => 1 },
  "message",
  { data_type => "text", is_nullable => 1 },
  "sig_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "week_id",
  { data_type => "char", default_value => 0, is_nullable => 0, size => 6 },
);
__PACKAGE__->set_primary_key("evt_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:E6/1xmoGggo3R5SIW/EzCw

#------------------------------------------------------------------------#
__PACKAGE__->belongs_to('signature', 'eris::schema::event::signature', 'sig_id');

#------------------------------------------------------------------------#
# Users linked
__PACKAGE__->might_have('src_user', 'eris::schema::user',
	{ 'foreign.user_id' => 'self.src_user_id' } );
__PACKAGE__->might_have('dst_user', 'eris::schema::user',
	{ 'foreign.user_id' => 'self.dst_user_id' } );

#------------------------------------------------------------------------#
# Devices linked
__PACKAGE__->might_have('src_dev', 'eris::schema::device',
	{ 'foreign.device_id' => 'self.src_id' } );
__PACKAGE__->might_have('dst_dev', 'eris::schema::device',
	{ 'foreign.device_id' => 'self.dst_id' } );
__PACKAGE__->might_have('sensor_dev', 'eris::schema::device',
	{ 'foreign.device_id' => 'self.sensor_id' } );

# You can replace this text with custom content, and it will be preserved on regeneration
1;
