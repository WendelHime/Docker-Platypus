package Curtobacterium::Services::Model::TRFSearch;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Report_HTML_DB::Models::Application::TRFSearch',
    constructor => 'new',
);

1;
