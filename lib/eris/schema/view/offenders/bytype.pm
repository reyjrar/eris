package eris::schema::view::offenders::bytype;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::view::offenders::bytype

=cut

__PACKAGE__->table("v_security_offenders_bytype");

=head1 ACCESSORS

=head2 evt_type_id

  data_type: 'integer'
  is_nullable: 1

=head2 offending_ip

  data_type: 'inet'
  is_nullable: 1

=head2 offending_id

  data_type: 'integer'
  is_nullable: 1

=head2 violations

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "evt_type_id",
  { data_type => "integer", is_nullable => 1 },
  "offending_ip",
  { data_type => "inet", is_nullable => 1 },
  "offending_id",
  { data_type => "integer", is_nullable => 1 },
  "violations",
  { data_type => "bigint", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K5Tka+LT9H6CMQhFWdJU4Q


# You can replace this text with custom content, and it will be preserved on regeneration
1;
