package eris::schema::regulatory::waiver::meta;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::regulatory::waiver::meta

=cut

__PACKAGE__->table("regulatory_waivers_meta");

=head1 ACCESSORS

=head2 meta_waiver_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'regulatory_waivers_meta_meta_waiver_id_seq'

=head2 regulation_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 exception_class_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 compensating_controls

  data_type: 'text'
  is_nullable: 1

=head2 authoritative_user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 destination_fax

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 destination_email

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 is_active

  data_type: 'boolean'
  default_value: true
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "meta_waiver_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "regulatory_waivers_meta_meta_waiver_id_seq",
  },
  "regulation_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "exception_class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "compensating_controls",
  { data_type => "text", is_nullable => 1 },
  "authoritative_user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "destination_fax",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "destination_email",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "is_active",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("meta_waiver_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:miWSWTjjHPx96Ur0NTOVLg


# You can replace this text with custom content, and it will be preserved on regeneration
1;
