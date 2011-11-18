package eris::schema::event::type;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::event::type

=cut

__PACKAGE__->table("security_event_types");

=head1 ACCESSORS

=head2 evt_type_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'security_event_types_evt_type_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 40

=head2 base_level

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 short

  data_type: 'char'
  is_nullable: 1
  size: 20

=cut

__PACKAGE__->add_columns(
  "evt_type_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "security_event_types_evt_type_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 40 },
  "base_level",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "short",
  { data_type => "char", is_nullable => 1, size => 20 },
);
__PACKAGE__->set_primary_key("evt_type_id");
__PACKAGE__->add_unique_constraint("uniq_sec_evt_name", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Bs4AWbSwm0VrEMM18RVaiw

#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->has_many('signatures', 'eris::schema::event::signature', 'evt_type_id');
#------------------------------------------------------------------------#
1;
