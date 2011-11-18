package eris::schema::authen;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::authen

=cut

__PACKAGE__->table("authen_current");

=head1 ACCESSORS

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 device_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 discovery_method

  data_type: 'varchar'
  is_nullable: 0
  size: 25

=head2 first_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 last_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 authen_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'authen_current_authen_id_seq'

=cut

__PACKAGE__->add_columns(
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "device_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "discovery_method",
  { data_type => "varchar", is_nullable => 0, size => 25 },
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
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "authen_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "authen_current_authen_id_seq",
  },
);
__PACKAGE__->set_primary_key("authen_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:is/+tQcEJB9OeeKnrEp9+g

#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id' );
__PACKAGE__->belongs_to('user', 'eris::schema::user', 'user_id' );
#------------------------------------------------------------------------#

# You can replace this text with custom content, and it will be preserved on regeneration
1;
