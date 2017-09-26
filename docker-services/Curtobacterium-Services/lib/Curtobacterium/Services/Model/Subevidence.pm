package Curtobacterium::Services::Model::Subevidence;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Report_HTML_DB::Models::Application::Subevidence',
    constructor => 'new',
);

1;
