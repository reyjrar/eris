package eris::schema::notification::files;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime", "PK::Auto");

=head1 NAME

eris::schema::notification::files

=cut

__PACKAGE__->table("notification_files");

=head1 ACCESSORS

=head2 file_id

  data_type: 'bigint'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'notification_files_file_id_seq'

=head2 filename

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'text'
  is_nullable: 0

=head2 filecontent

  data_type: 'bytea'
  is_nullable: 0

=head2 filesize

  data_type: 'integer'
  is_nullable: 0

=head2 filetype

  data_type: 'varchar'
  default_value: 'application/octet-stream'
  is_nullable: 0
  size: 150

=head2 notification_id

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "file_id",
  {
    data_type         => "bigint",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "notification_files_file_id_seq",
  },
  "filename",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "filecontent",
  { data_type => "bytea", is_nullable => 0 },
  "filesize",
  { data_type => "integer", is_nullable => 0 },
  "filetype",
  {
    data_type => "varchar",
    default_value => "application/octet-stream",
    is_nullable => 0,
    size => 150,
  },
  "notification_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("file_id");


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2011-07-28 12:28:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QcKOfOcURpCZXbpn2xhKkw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
