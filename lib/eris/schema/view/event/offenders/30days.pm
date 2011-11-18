package eris::schema::view::event::offenders::30days;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::view::event::offenders::30days

=cut

__PACKAGE__->table("mv_security_offenders_sig_30days");

=head1 ACCESSORS

=head2 offender_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 sig_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 first_ts

  data_type: 'timestamp'
  is_nullable: 1

=head2 last_ts

  data_type: 'timestamp'
  is_nullable: 1

=head2 violations

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "offender_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "sig_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "first_ts",
  { data_type => "timestamp", is_nullable => 1 },
  "last_ts",
  { data_type => "timestamp", is_nullable => 1 },
  "violations",
  { data_type => "bigint", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:X5vgDdKNfWfeohUQ9upT3w


# You can replace this text with custom content, and it will be preserved on regeneration
1;
