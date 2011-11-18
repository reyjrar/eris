package eris::Model::DB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';
use eris;

use lib '../lib';

__PACKAGE__->config(
    schema_class => 'eris::schema',
    connect_info => [
		eris->config->{db}{dsn},
		eris->config->{db}{user},
		eris->config->{db}{pass},
    ],
);

=head1 NAME

eris::Model::DB - Catalyst DBIC Schema Model
=head1 SYNOPSIS

See L<eris>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<eris::Schema>

=head1 AUTHOR

Brad Lhotsky

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
