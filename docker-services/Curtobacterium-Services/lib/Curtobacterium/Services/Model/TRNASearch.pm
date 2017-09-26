package Curtobacterium::Services::Model::TRNASearch;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Report_HTML_DB::Models::Application::TRNASearch',
    constructor => 'new',
);

1;

