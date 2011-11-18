package eris::schema::map::notification::admins;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::map::notification::admins

=cut

__PACKAGE__->table("notification_admins");

=head1 ACCESSORS

=head2 notification_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 notify_admin_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'notification_admins_notify_admin_id_seq'

=cut

__PACKAGE__->add_columns(
  "notification_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "notify_admin_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "notification_admins_notify_admin_id_seq",
  },
);
__PACKAGE__->set_primary_key("notify_admin_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:t+BWMwSCG4sZ5N94cw0ypw

#------------------------------------------------------------------------#
# Relationships

__PACKAGE__->belongs_to( 'admin', 'eris::schema::user', { 'foreign.user_id' => 'self.user_id' } );
__PACKAGE__->belongs_to( 'notification', 'eris::schema::notification', { 'foreign.notification_id' => 'self.notification' } );

1;
