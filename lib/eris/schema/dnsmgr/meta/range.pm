package eris::schema::dnsmgr::meta::range;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::dnsmgr::meta::range

=cut

__PACKAGE__->table("dnsmgr_ip_mgt_range");

=head1 ACCESSORS

=head2 range_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dnsmgr_ip_mgt_range_range_id_seq'

=head2 range_start

  data_type: 'inet'
  is_nullable: 0

=head2 range_stop

  data_type: 'inet'
  is_nullable: 0

=head2 mgt_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 range_total

  data_type: 'integer'
  is_nullable: 1

=head2 range_used

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "range_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dnsmgr_ip_mgt_range_range_id_seq",
  },
  "range_start",
  { data_type => "inet", is_nullable => 0 },
  "range_stop",
  { data_type => "inet", is_nullable => 0 },
  "mgt_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "range_total",
  { data_type => "integer", is_nullable => 1 },
  "range_used",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("range_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BxMe/IBwcZ36cjFQu7mF0g

__PACKAGE__->belongs_to('area', 'eris::schema::dnsmgr::meta', 'mgt_id' );
__PACKAGE__->has_many('records', 'eris::schema::dnsmgr::meta::record', 'range_id');
# You can replace this text with custom content, and it will be preserved on regeneration
1;
