package eris::schema::device::services;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::device::services

=cut

__PACKAGE__->table("services");

=head1 ACCESSORS

=head2 svc_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'services_svc_id_seq'

=head2 device_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 ip

  data_type: 'inet'
  is_nullable: 1

=head2 proto

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 port

  data_type: 'integer'
  is_nullable: 1

=head2 connections

  data_type: 'bigint'
  is_nullable: 1

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

=head2 network_name

  data_type: 'varchar'
  default_value: 'niairp'
  is_nullable: 0
  size: 20

=head2 vicinity

  data_type: 'varchar'
  default_value: 'internal'
  is_nullable: 0
  size: 10

=cut

__PACKAGE__->add_columns(
  "svc_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "services_svc_id_seq",
  },
  "device_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "ip",
  { data_type => "inet", is_nullable => 1 },
  "proto",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "port",
  { data_type => "integer", is_nullable => 1 },
  "connections",
  { data_type => "bigint", is_nullable => 1 },
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
  "network_name",
  {
    data_type => "varchar",
    default_value => "niairp",
    is_nullable => 0,
    size => 20,
  },
  "vicinity",
  {
    data_type => "varchar",
    default_value => "internal",
    is_nullable => 0,
    size => 10,
  },
);
__PACKAGE__->set_primary_key("svc_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3Bk4EdFXBncjYTa0yaUm4w


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id' );
#------------------------------------------------------------------------#
1;
