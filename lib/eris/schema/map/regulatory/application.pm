package eris::schema::map::regulatory::application;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::map::regulatory::application

=cut

__PACKAGE__->table("regulatory_application");

=head1 ACCESSORS

=head2 reg_app_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'regulatory_application_reg_app_id_seq'

=head2 regulation_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 node_type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "reg_app_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "regulatory_application_reg_app_id_seq",
  },
  "regulation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "node_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("reg_app_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ypAQiHoud7bEf8IeJ/Q4Qg


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('regulation', 'eris::schema::regulatory::meta', 'regulation_id');
__PACKAGE__->belongs_to('node_type', 'eris::schema::device::type', 'node_type_id');
#------------------------------------------------------------------------#

1;
