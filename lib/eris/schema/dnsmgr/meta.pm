package eris::schema::dnsmgr::meta;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::dnsmgr::meta

=cut

__PACKAGE__->table("dnsmgr_ip_mgt");

=head1 ACCESSORS

=head2 mgt_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dnsmgr_ip_mgt_mgt_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 25

=head2 allow_edit

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 default_zone_id

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "mgt_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dnsmgr_ip_mgt_mgt_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 25 },
  "allow_edit",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "default_zone_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("mgt_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mttBmOWKvqqqp46tCs5WlQ

__PACKAGE__->has_many('ranges' => 'eris::schema::dnsmgr::meta::range', 'mgt_id' );
__PACKAGE__->has_one('default_zone' => 'eris::schema::dnsmgr::zones',
	{ "foreign.zone_id" => "self.default_zone_id" } );
# You can replace this text with custom content, and it will be preserved on regeneration

sub total_ips {
	my ($self) = @_;
	return $self->ranges->get_column('range_total')->sum();
}

sub used_ips {
	my ($self) = @_;
	return $self->ranges->get_column('range_used')->sum();
}
1;
