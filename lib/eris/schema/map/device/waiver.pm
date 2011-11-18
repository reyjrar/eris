package eris::schema::map::device::waiver;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::map::device::waiver

=cut

__PACKAGE__->table("device_waivers");

=head1 ACCESSORS

=head2 device_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=head2 waiver_id

  data_type: 'bigint'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "device_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
  "waiver_id",
  { data_type => "bigint", is_foreign_key => 1, is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jpkULA0TMSL1p+HjJWF2Sw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
