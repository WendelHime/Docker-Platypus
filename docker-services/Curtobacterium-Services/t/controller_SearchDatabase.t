use strict;
use warnings;
use Test::More;


use Catalyst::Test 'Curtobacterium::Services';
use Curtobacterium::Services::Controller::SearchDatabase;

ok( request('/searchdatabase')->is_success, 'Request should succeed' );
done_testing();
