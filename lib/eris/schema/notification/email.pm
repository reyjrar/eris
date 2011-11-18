package eris::schema::notification::email;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::notification::email

=cut

__PACKAGE__->table("notification_email");

=head1 ACCESSORS

=head2 email_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'notification_email_email_id_seq'

=head2 notification_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 sent_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 email_type

  data_type: 'char'
  default_value: 'origination'
  is_nullable: 0
  size: 12

=head2 email_subject

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 email_message

  data_type: 'text'
  is_nullable: 0

=head2 ack_ts

  data_type: 'timestamp'
  is_nullable: 1

=head2 ack_code

  data_type: 'char'
  is_nullable: 1
  size: 40

=head2 file_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "email_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "notification_email_email_id_seq",
  },
  "notification_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "sent_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "email_type",
  {
    data_type => "char",
    default_value => "origination",
    is_nullable => 0,
    size => 12,
  },
  "email_subject",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "email_message",
  { data_type => "text", is_nullable => 0 },
  "ack_ts",
  { data_type => "timestamp", is_nullable => 1 },
  "ack_code",
  { data_type => "char", is_nullable => 1, size => 40 },
  "file_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("email_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DRoaOds+hJQVbet4uyLjlQ


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->has_one( 'rcpt', 'eris::schema::user', { 'foreign.user_id' => 'self.user_id' } );

# Many-to-Many: RCPTS
__PACKAGE__->has_many('map_rcpts', 'eris::schema::map::notification::rcpts', { 'foreign.email_id' => 'self.email_id' } );
__PACKAGE__->many_to_many( 'rcpts', 'map_rcpts', 'email_user' );
1;
