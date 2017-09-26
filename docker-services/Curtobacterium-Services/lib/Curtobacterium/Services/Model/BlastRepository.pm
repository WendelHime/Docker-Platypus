package Curtobacterium::Services::Model::BlastRepository;
use strict;
use warnings;
use base 'Catalyst::Model::Adaptor';

__PACKAGE__->config(
	class		=> 'Report_HTML_DB::Repositories::BlastRepository',
	constructor	=> 'new',
);

1;

