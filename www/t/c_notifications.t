use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'eris' }
BEGIN { use_ok 'eris::C::notifications' }

ok( request('/notifications')->is_success, 'Request should succeed' );
done_testing();
