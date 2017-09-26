use strict;
use warnings;

use Curtobacterium::Services;

my $app = Curtobacterium::Services->apply_default_middlewares(Curtobacterium::Services->psgi_app);
$app;

