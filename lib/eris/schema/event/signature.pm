package eris::schema::event::signature;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::event::signature

=cut

__PACKAGE__->table("security_signatures");

=head1 ACCESSORS

=head2 sig_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'security_signatures_sig_id_seq'

=head2 evt_type_id

  data_type: 'integer'
  default_value: 1
  is_foreign_key: 1
  is_nullable: 0

=head2 native_sig_id

  data_type: 'varchar'
  is_nullable: 0
  size: 80

=head2 facility

  data_type: 'varchar'
  is_nullable: 0
  size: 40

=head2 create_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 description

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "sig_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "security_signatures_sig_id_seq",
  },
  "evt_type_id",
  {
    data_type      => "integer",
    default_value  => 1,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "native_sig_id",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "facility",
  { data_type => "varchar", is_nullable => 0, size => 40 },
  "create_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("sig_id");
__PACKAGE__->add_unique_constraint(
  "uniq_security_sigs_by_facility",
  ["facility", "native_sig_id"],
);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gC9L+WdQxbY5pU6crv15Wg

#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('type', 'eris::schema::event::type', 'evt_type_id');
__PACKAGE__->has_many('events', 'eris::schema::event', 'sig_id');

#------------------------------------------------------------------------#
1;
