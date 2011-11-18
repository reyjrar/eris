use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'eris' }
BEGIN { use_ok 'eris::C::dnsmgr' }

ok( request('/dnsmgr')->is_success, 'Request should succeed' );


