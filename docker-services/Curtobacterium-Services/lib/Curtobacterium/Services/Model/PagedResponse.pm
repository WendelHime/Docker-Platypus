package Curtobacterium::Services::Model::PagedResponse;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Report_HTML_DB::Models::Services::PagedResponse',
    constructor => 'new',
);

1;	
