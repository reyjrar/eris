package eris::schema::view::history;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::view::history

=cut

__PACKAGE__->table("inventory_archive");

=head1 ACCESSORS

=head2 inv_archive_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'inventory_archive_inv_archive_id_seq'

=head2 device_id

  data_type: 'bigint'
  is_nullable: 1

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 mac

  data_type: 'macaddr'
  is_nullable: 1

=head2 ip

  data_type: 'inet'
  is_nullable: 1

=head2 clientid

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 username

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 event_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 discovery_method

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=cut

__PACKAGE__->add_columns(
  "inv_archive_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "inventory_archive_inv_archive_id_seq",
  },
  "device_id",
  { data_type => "bigint", is_nullable => 1 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "mac",
  { data_type => "macaddr", is_nullable => 1 },
  "ip",
  { data_type => "inet", is_nullable => 1 },
  "clientid",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "username",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "event_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "discovery_method",
  { data_type => "varchar", is_nullable => 1, size => 80 },
);
__PACKAGE__->set_primary_key("inv_archive_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:nAdCShgt8QEtVYujeFslbg


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id');
__PACKAGE__->belongs_to('user', 'eris::schema::user', 'user_id');
#------------------------------------------------------------------------#
1;
