package eris::schema::ext::property_book;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::ext::property_book

=cut

__PACKAGE__->table("ext_property_book");

=head1 ACCESSORS

=head2 property_tag

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 manufacturer

  data_type: 'varchar'
  is_nullable: 1
  size: 35

=head2 model

  data_type: 'varchar'
  is_nullable: 1
  size: 35

=head2 class_code

  data_type: 'varchar'
  is_nullable: 1
  size: 15

=head2 class_name

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 acquisition_date

  data_type: 'date'
  is_nullable: 1

=head2 acquisition_cost

  data_type: 'numeric'
  is_nullable: 1
  size: [8,2]

=head2 last_inventory_date

  data_type: 'date'
  is_nullable: 1

=head2 has_property_pass

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 responsible_user

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 device_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 serial_number

  data_type: 'varchar'
  is_nullable: 1
  size: 35

=head2 custodial_code

  data_type: 'integer'
  is_nullable: 1

=head2 location

  data_type: 'varchar'
  is_nullable: 1
  size: 35

=cut

__PACKAGE__->add_columns(
  "property_tag",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "manufacturer",
  { data_type => "varchar", is_nullable => 1, size => 35 },
  "model",
  { data_type => "varchar", is_nullable => 1, size => 35 },
  "class_code",
  { data_type => "varchar", is_nullable => 1, size => 15 },
  "class_name",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "acquisition_date",
  { data_type => "date", is_nullable => 1 },
  "acquisition_cost",
  { data_type => "numeric", is_nullable => 1, size => [8, 2] },
  "last_inventory_date",
  { data_type => "date", is_nullable => 1 },
  "has_property_pass",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "responsible_user",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "device_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "serial_number",
  { data_type => "varchar", is_nullable => 1, size => 35 },
  "custodial_code",
  { data_type => "integer", is_nullable => 1 },
  "location",
  { data_type => "varchar", is_nullable => 1, size => 35 },
);
__PACKAGE__->set_primary_key("property_tag");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9u6+0CWPJH+yu5vSf0siRg


__PACKAGE__->belongs_to('custodian', 'eris::schema::ext::custodians', 'custodial_code');
__PACKAGE__->belongs_to('user', 'eris::schema::user', 'user_id');
1;
