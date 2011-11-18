package eris::schema::ext::fake_mac_addr;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::ext::fake_mac_addr

=cut

__PACKAGE__->table("fake_mac_addr");

=head1 ACCESSORS

=head2 suffix

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'fake_mac_addr_suffix_seq'

=head2 create_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 user_id

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "suffix",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "fake_mac_addr_suffix_seq",
  },
  "create_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "user_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("suffix");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gMLdwHNiQwu3RcwCH4CyeQ


# You can replace this text with custom content, and it will be preserved on regeneration
1;
