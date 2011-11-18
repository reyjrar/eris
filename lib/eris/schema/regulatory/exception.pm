package eris::schema::regulatory::exception;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::regulatory::exception

=cut

__PACKAGE__->table("regulatory_exception_classes");

=head1 ACCESSORS

=head2 reg_exp_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'regulatory_exception_classes_reg_exp_id_seq'

=head2 regulation_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 device_class_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 waiver_required

  data_type: 'boolean'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "reg_exp_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "regulatory_exception_classes_reg_exp_id_seq",
  },
  "regulation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "device_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "waiver_required",
  { data_type => "boolean", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("reg_exp_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:fApQAgOrIlmYXkdo1P7Amg


#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('class', 'eris::schema::device::class', 'device_class_id');
__PACKAGE__->belongs_to('regulation', 'eris::schema::regulatory::meta', 'regulation_id');
#------------------------------------------------------------------------#
1;
