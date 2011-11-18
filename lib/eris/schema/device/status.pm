package eris::schema::device::status;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::device::status

=cut

__PACKAGE__->table("device_status");

=head1 ACCESSORS

=head2 status_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'device_status_status_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 25

=head2 description

  data_type: 'text'
  is_nullable: 0

=head2 is_operational

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

=head2 alarm_if_seen

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "status_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "device_status_status_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 25 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "is_operational",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "alarm_if_seen",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("status_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0EOIad8P3nMIg3f80Ykdfw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
