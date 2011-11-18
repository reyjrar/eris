package eris::View::Mason;

use strict;
use warnings;
use base 'Catalyst::View::Mason';
use eris;

__PACKAGE__->config(use_match => 0);
__PACKAGE__->config(comp_root => eris->path_to(qw(root))->absolute->stringify );
__PACKAGE__->config(data_dir => eris->path_to(qw(mason))->absolute->stringify );

=head1 NAME

eris::View::Mason - Mason View Component

=head1 SYNOPSIS

    Very simple to use

=head1 DESCRIPTION

Very nice component.

=head1 AUTHOR

Clever guy

=head1 LICENSE

This library is free software . You can redistribute it and/or modify it under
the same terms as perl itself.

=cut

1;
