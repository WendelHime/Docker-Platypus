package Curtobacterium::Services::Model::SearchDBClient;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config(
	class		=> 'Report_HTML_DB::Clients::SearchDBClient',
	constructor	=> 'new',
);

1;

