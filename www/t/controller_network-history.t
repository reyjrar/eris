use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'eris' }
BEGIN { use_ok 'eris::Controller::network::history' }

ok( request('/network/history')->is_success, 'Request should succeed' );
done_testing();
