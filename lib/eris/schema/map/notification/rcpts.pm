package eris::schema::map::notification::rcpts;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::map::notification::rcpts

=cut

__PACKAGE__->table("map_notification_email_rcpts");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 email_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 rcpt_type

  data_type: 'char'
  default_value: 'to'
  is_nullable: 0
  size: 5

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "email_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "rcpt_type",
  { data_type => "char", default_value => "to", is_nullable => 0, size => 5 },
);
__PACKAGE__->set_primary_key("email_id", "user_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CoYd7LtLLZNmeWVXbsow+w

#------------------------------------------------------------------------#
# Relationships

__PACKAGE__->belongs_to('email_user', 'eris::schema::user', { 'foreign.user_id' => 'self.user_id' } );
__PACKAGE__->belongs_to('user_email', 'eris::schema::notification::email', { 'foreign.email_id' => 'self.email_id' } );
1;
