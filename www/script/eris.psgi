#!/usr/bin/env perl
use strict;
use warnings;
use eris;

eris->setup_engine('PSGI');
my $app = sub { eris->run(@_) };

