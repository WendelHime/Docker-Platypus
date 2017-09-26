package Curtobacterium::Services::Model::Feature;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Report_HTML_DB::Models::Application::Feature',
    constructor => 'new',
);

1;
