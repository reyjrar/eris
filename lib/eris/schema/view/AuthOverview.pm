package eris::schema::view::AuthOverview;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::view::AuthOverview

=cut

__PACKAGE__->table("v_daily_authentication");

=head1 ACCESSORS

=head2 device_id

  data_type: 'bigint'
  is_nullable: 1

=head2 username

  data_type: 'varchar'
  is_nullable: 1
  size: 80

=head2 display_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 auth_method

  data_type: 'varchar'
  is_nullable: 1
  size: 25

=head2 auth_ts

  data_type: 'timestamp'
  is_nullable: 1

=head2 ip

  data_type: 'inet'
  is_nullable: 1

=head2 mac

  data_type: 'macaddr'
  is_nullable: 1

=head2 clientid

  data_type: 'varchar'
  is_nullable: 1
  size: 150

=head2 device_ts

  data_type: 'timestamp'
  is_nullable: 1

=head2 device_method

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 switch_ip

  data_type: 'inet'
  is_nullable: 1

=head2 switch_port

  data_type: 'varchar'
  is_nullable: 1
  size: 30

=cut

__PACKAGE__->add_columns(
  "device_id",
  { data_type => "bigint", is_nullable => 1 },
  "username",
  { data_type => "varchar", is_nullable => 1, size => 80 },
  "display_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "auth_method",
  { data_type => "varchar", is_nullable => 1, size => 25 },
  "auth_ts",
  { data_type => "timestamp", is_nullable => 1 },
  "ip",
  { data_type => "inet", is_nullable => 1 },
  "mac",
  { data_type => "macaddr", is_nullable => 1 },
  "clientid",
  { data_type => "varchar", is_nullable => 1, size => 150 },
  "device_ts",
  { data_type => "timestamp", is_nullable => 1 },
  "device_method",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "switch_ip",
  { data_type => "inet", is_nullable => 1 },
  "switch_port",
  { data_type => "varchar", is_nullable => 1, size => 30 },
);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EhS3XtudR44+klKbq1TLwA


#------------------------------------------------------------------------#
# More Meta
__PACKAGE__->set_primary_key(qw(device_id));
#------------------------------------------------------------------------#
# Relationships
__PACKAGE__->belongs_to('device', 'eris::schema::device', 'device_id');
#------------------------------------------------------------------------#
1;
