package eris::schema::regulatory::meta;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::regulatory::meta

=cut

__PACKAGE__->table("regulatory_meta");

=head1 ACCESSORS

=head2 regulation_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'regulatory_meta_regulation_id_seq'

=head2 create_ts

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 initial_deadline

  data_type: 'date'
  is_nullable: 0

=head2 waiver_correction_interval

  data_type: 'interval'
  default_value: '30 days'
  is_nullable: 1

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 80

=head2 description

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "regulation_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "regulatory_meta_regulation_id_seq",
  },
  "create_ts",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "initial_deadline",
  { data_type => "date", is_nullable => 0 },
  "waiver_correction_interval",
  { data_type => "interval", default_value => "30 days", is_nullable => 1 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 80 },
  "description",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("regulation_id");
__PACKAGE__->add_unique_constraint("regulatory_meta_name_key", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lrGQQj+g/O0hfWd/Ih4D8Q

#------------------------------------------------------------------------#
# MANY-TO-MANY
__PACKAGE__->has_many('exception_classes', 'eris::schema::regulatory::exception', 'regulation_id' );
__PACKAGE__->many_to_many('exceptions', 'exception_classes', 'class');
#------------------------------------------------------------------------#
1;
