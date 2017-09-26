package Curtobacterium::Services::Controller::Blast;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

services::Controller::Blast - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

use base 'Catalyst::Controller::REST';
BEGIN { extends 'Catalyst::Controller::REST'; }

=head2

Method used to realize search blast

=cut

sub search : Path("/Blast/search") : CaptureArgs(18) : ActionClass('REST') { }

sub search_POST {
	my ( $self, $c ) = @_;

	open( my $FILEHANDLER, "<", $c->req->body );
	my $formData = do { local $/; <$FILEHANDLER> };
	close($FILEHANDLER);
	use JSON;
	my %hash = %{ decode_json($formData) };

	foreach my $key ( keys %hash ) {
		if ($key) {
			$hash{$key} =~ s/['"&.|]//g;
			chomp( $hash{$key} ) if $key ne "SEQUENCE";
		}
	}

	use File::Temp ();
	my $fh    = File::Temp->new();
	my $fname = $fh->filename;
	open( $FILEHANDLER, ">", $fname );
	my @fuckingSequence = split( /\\n/, $hash{SEQUENCE} );
	$hash{SEQUENCE} = join( "\n", @fuckingSequence );
	print $FILEHANDLER $hash{SEQUENCE};
	close($FILEHANDLER);

	$hash{DATALIB} = $c->path_to("root") . "/seq/Sequences"
	  if ( $hash{DATALIB} eq "PMN_genome_1" );
	$hash{DATALIB} = $c->path_to("root"). "/orfs_nt/Sequences_NT"
	  if ( $hash{DATALIB} eq "PMN_genes_1" );
	$hash{DATALIB} = $c->path_to("root") . "/orfs_aa/Sequences_AA"
	  if ( $hash{DATALIB} eq "PMN_prot_1" );
	my $content = "";
	if ( exists $hash{PROGRAM} ) {
		if (   $hash{PROGRAM} eq "blastn"
			|| $hash{PROGRAM} eq "blastp"
			|| $hash{PROGRAM} eq "blastx"
			|| $hash{PROGRAM} eq "tblastn"
			|| $hash{PROGRAM} eq "tblastx" )
		{
			my @response = @{
				$c->model('BlastRepository')->executeBlastSearch(
					$hash{PROGRAM},            $hash{DATALIB},
					$fname,                    $hash{QUERY_FROM},
					$hash{QUERY_TO},           $hash{FILTER},
					$hash{EXPECT},             $hash{MAT_PARAM},
					$hash{UNGAPPED_ALIGNMENT}, $hash{GENETIC_CODE},
					$hash{DB_GENETIC_CODE},    
					$hash{OTHER_ADVANCED},     $hash{OVERVIEW},
					$hash{ALIGNMENT_VIEW},     $hash{DESCRIPTIONS},
					$hash{ALIGNMENTS},         $hash{COST_OPEN_GAP},
                    $hash{COST_EXTEND_GAP},    $hash{WORD_SIZE}
				)
			};
			$content = join( "", @response );
		}
		else {
			$content = "PROGRAM NOT IN THE LIST";
		}
	}
	else {
		$content = "NO PROGRAM DEFINED";
	}

	return standardStatusOk( $self, $c, $content );
}

sub fancy : Path("/Blast/fancy") : CaptureArgs(3) : ActionClass('REST') { }

sub fancy_POST {
	my ( $self, $c ) = @_;
	open( my $FILEHANDLER, "<", $c->req->body );
	my $formData = do { local $/; <$FILEHANDLER> };
	close($FILEHANDLER);
	use JSON;
	my %hash = %{ decode_json($formData) };

	use File::Temp ();
	my $fh    = File::Temp->new();
	my $fname = $fh->filename;
	open( $FILEHANDLER, ">", $fname );
	print $FILEHANDLER $hash{blast};
	close($FILEHANDLER);
	use File::Temp qw/ :mktemp  /;
	my $tmpdir_name = mkdtemp("/tmp/XXXXXX");
	%hash = ();
	if ($c->model('BlastRepository')->fancyBlast($fname, $tmpdir_name)) {
		my @files = ();
		opendir(my $DIR, $tmpdir_name);
		@files = grep(!/^\./, readdir($DIR));
		closedir($DIR);
		use MIME::Base64;
		for(my $i = 0; $i < scalar @files; $i++) 
		{
			open($FILEHANDLER, "<", $tmpdir_name . "/" . $files[$i]);
			my $content = do { local $/; <$FILEHANDLER> };
			if($files[$i] =~ /\.html/g) {
				$hash{html} = $content;
			}
			elsif($files[$i] =~ /\.png/g) {
				$hash{image} = MIME::Base64::encode_base64($content);
			}
			close($FILEHANDLER);
		}
	}
	use File::Path;
	rmtree($tmpdir_name);
	return standardStatusOk($self, $c, \%hash);
}

=head2

Method used to make a default return of every ok request using BaseResponse model

=cut

sub standardStatusOk {
	my ( $self, $c, $response, $total, $pageSize, $offset ) = @_;
	if (   ( defined $total || $total )
		&& ( defined $pageSize || $pageSize )
		&& ( defined $offset   || $offset ) )
	{
		my $pagedResponse = $c->model('PagedResponse')->new(
			status_code => 200,
			message     => "Ok",
			elapsed_ms  => $c->stats->elapsed,
			response    => $response,
			total       => $total,
			pageSize    => $pageSize,
			offset      => $offset,
		);
		$self->status_ok( $c, entity => $pagedResponse->pack(), );
	}
	else {
		my $baseResponse = $c->model('BaseResponse')->new(
			status_code => 200,
			message     => "Ok",
			elapsed_ms  => $c->stats->elapsed,
			response    => $response
		);
		$self->status_ok( $c, entity => $baseResponse->pack(), );
	}
}

=encoding utf8

=head1 AUTHOR

Wendel Hime L. Castro,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;

