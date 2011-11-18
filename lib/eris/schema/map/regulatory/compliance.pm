package eris::schema::map::regulatory::compliance;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::map::regulatory::compliance

=cut

__PACKAGE__->table("regulatory_compliance");

=head1 ACCESSORS

=head2 reg_map_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'regulatory_compliance_reg_map_id_seq'

=head2 regulation_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 device_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 mod_user_id

  data_type: 'integer'
  is_nullable: 1

=head2 mod_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "reg_map_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "regulatory_compliance_reg_map_id_seq",
  },
  "regulation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "device_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "mod_user_id",
  { data_type => "integer", is_nullable => 1 },
  "mod_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("reg_map_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EwquFzoWlNx7WkeWSoHIgg


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id');
__PACKAGE__->belongs_to('regulation', 'eris::schema::regulatory::meta', 'regulation_id');
#------------------------------------------------------------------------#
1;
