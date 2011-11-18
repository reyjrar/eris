package eris::schema::dnsmgr::meta::record;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::dnsmgr::meta::record

=cut

__PACKAGE__->table("dnsmgr_ip_mgt_records");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dnsmgr_ip_mgt_records_id_seq'

=head2 ip

  data_type: 'inet'
  is_nullable: 0

=head2 fqdn

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 device_id

  data_type: 'integer'
  is_nullable: 1

=head2 range_id

  data_type: 'integer'
  is_nullable: 0

=head2 forward_rec_id

  data_type: 'integer'
  is_nullable: 1

=head2 reverse_rec_id

  data_type: 'integer'
  is_nullable: 1

=head2 source

  data_type: 'varchar'
  default_value: 'automatic'
  is_nullable: 0
  size: 25

=head2 first_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dnsmgr_ip_mgt_records_id_seq",
  },
  "ip",
  { data_type => "inet", is_nullable => 0 },
  "fqdn",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "device_id",
  { data_type => "integer", is_nullable => 1 },
  "range_id",
  { data_type => "integer", is_nullable => 0 },
  "forward_rec_id",
  { data_type => "integer", is_nullable => 1 },
  "reverse_rec_id",
  { data_type => "integer", is_nullable => 1 },
  "source",
  {
    data_type => "varchar",
    default_value => "automatic",
    is_nullable => 0,
    size => 25,
  },
  "first_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QoDwuO8xd1+E+w76MTYVuQ

__PACKAGE__->belongs_to('range', 'eris::schema::dnsmgr::meta::range', 'range_id');
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id');
# You can replace this text with custom content, and it will be preserved on regeneration
1;
