package Curtobacterium::Services::Model::BlastClient;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config(
	class		=> 'Report_HTML_DB::Clients::BlastClient',
	constructor	=> 'new',
);

1;

