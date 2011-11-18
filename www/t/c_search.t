use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'eris' }
BEGIN { use_ok 'eris::C::search' }

ok( request('/search')->is_success, 'Request should succeed' );


