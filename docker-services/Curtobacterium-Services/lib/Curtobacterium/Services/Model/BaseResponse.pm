package Curtobacterium::Services::Model::BaseResponse;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config( 
    class       => 'Report_HTML_DB::Models::Services::BaseResponse',
    constructor => 'new',
);

1;
