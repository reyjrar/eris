use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'eris' }
BEGIN { use_ok 'eris::Controller::node::surplus' }

ok( request('/node/surplus')->is_success, 'Request should succeed' );
done_testing();
