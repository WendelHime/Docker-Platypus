package Curtobacterium::Services::Model::SearchDatabaseRepository;

use strict;
use warnings;
use parent 'Catalyst::Model::DBI';

__PACKAGE__->config(
	dsn      => "dbi:Pg:dbname=curto_db;host=localhost",
	user     => "chadouser",
	password => "",
	options  => {},
);

=head2

Method used to get pipeline from database

=cut

sub getPipeline {
	my ( $self ) = @_;
	my $dbh = $self->dbh;
	my $query = "select distinct p.value as value
        	from feature_relationship r
        	join featureloc l on (r.subject_id = l.feature_id)
        	join featureprop p on (p.feature_id = l.srcfeature_id)
        	join cvterm cp on (p.type_id = cp.cvterm_id)
        	WHERE cp.name='pipeline_id';";
	my $sth = $dbh->prepare($query);
        print STDERR $query;
        $sth->execute();
        my @rows = @{ $sth->fetchall_arrayref() };
        my %returnedHash = ();

        for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
                $returnedHash{pipeline_id} = $rows[$i][0];
        }

        return \%returnedHash;
}

=head2

Method used to get rRNAs availables in the sequence

=cut

sub getRibosomalRNAs {
	my ( $self, $hash ) = @_;
	my $dbh = $self->dbh;
	my @args = ();
	my $query = "select distinct pd.value AS name 
from feature f 
join feature_relationship r on (f.feature_id = r.object_id) 
join cvterm cr on (r.type_id = cr.cvterm_id) 
join featureprop ps on (r.subject_id = ps.feature_id) 
join cvterm cs on (ps.type_id = cs.cvterm_id) 
join featureprop pf on (f.feature_id = pf.feature_id) 
join cvterm cf on (pf.type_id = cf.cvterm_id) 
join featureloc l on (l.feature_id = f.feature_id) 
join featureprop pl on (l.srcfeature_id = pl.feature_id) 
join cvterm cp on (pl.type_id = cp.cvterm_id) 
join featureprop pd on (r.subject_id = pd.feature_id) 
join cvterm cd on (pd.type_id = cd.cvterm_id) 
where cr.name = 'based_on' and cf.name = 'tag' and pf.value='rRNA_prediction' and cs.name = 'locus_tag' and cd.name = 'description' and cp.name = 'pipeline_id' and pl.value=? ORDER BY pd.value ASC ;";
	push @args, $hash->{pipeline};
	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my @list = ();
    for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
    	push @list, $rows[$i][0];
	}
	return \@list;
}

=head2

Method used to realize search based on parameters received by form of analyses of protein-coding genes

=cut

sub analyses_CDS {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query = "SELECT motherfuckerquery.feature_id, COUNT(*) OVER() FROM "
	  . "((select distinct f.feature_id "
	  . "from feature f "
	  . "join feature_relationship r on (f.feature_id = r.object_id) "
	  . "join cvterm cr on (r.type_id = cr.cvterm_id) "
	  . "join featureprop ps on (r.subject_id = ps.feature_id) "
	  . "join cvterm cs on (ps.type_id = cs.cvterm_id) "
	  . "join featureprop pf on (f.feature_id = pf.feature_id) "
	  . "join cvterm cf on (pf.type_id = cf.cvterm_id) "
	  . "join featureloc l on (l.feature_id = f.feature_id) "
	  . "join featureprop pl on (l.srcfeature_id = pl.feature_id) "
	  . "join cvterm cp on (pl.type_id = cp.cvterm_id) "
	  . "join featureprop pd on (r.subject_id = pd.feature_id) "
	  . "join cvterm cd on (pd.type_id = cd.cvterm_id) "
	  . "where cr.name = 'based_on' and cf.name = 'tag' and pf.value='CDS' and cs.name = 'locus_tag' and cd.name = 'description' and cp.name = 'pipeline_id' and pl.value=? ";
	push @args, $hash->{pipeline};
	
	if(exists $hash->{contig} && $hash->{contig}) {
		$query .= " and l.srcfeature_id = ? ) ";
		push @args, $hash->{contig};
	} else {
		$query .= " ) ";
	}
	
	my $connector = "1";

	my $query_gene     = "";
	my $query_GO       = "";
	my $query_TCDB     = "";
	my $query_Phobius  = "";
	my $query_sigP     = "";
	my $query_blast    = "";
	my $query_RPS      = "";
	my $query_KEGG     = "";
	my $query_ORTH     = "";
	my $query_interpro = "";
	my $query_tmhmm    = "";
	my $query_dgpi	   = "";
	my $query_predgpi  = "";
	my $query_bigpi	   = "";

	if (   ( exists $hash->{geneDesc} && $hash->{geneDesc} )
		|| ( exists $hash->{noDesc} && $hash->{noDesc} ) )
	{
		my $and = "";
		$query_gene =
		    "(SELECT DISTINCT f.feature_id "
		  . "FROM feature f JOIN feature_relationship r ON (f.feature_id = r.object_id) "
		  . "JOIN cvterm cr ON (r.type_id = cr.cvterm_id) "
		  . "JOIN featureloc l ON (l.feature_id = f.feature_id) "
		  . "JOIN featureprop pl ON (l.srcfeature_id = pl.feature_id) "
		  . "JOIN cvterm cp ON (pl.type_id = cp.cvterm_id) "
		  . "JOIN featureprop pd ON (r.subject_id = pd.feature_id) "
		  . "JOIN cvterm cd ON (pd.type_id = cd.cvterm_id) "
		  . "WHERE cr.name = 'based_on' AND cd.name = 'description' AND cp.name = 'pipeline_id' AND pl.value=? AND ";
		push @args, $hash->{pipeline};
		$connector = " INTERSECT " if $connector;

		if ( exists $hash->{geneDesc} && $hash->{geneDesc} ) {
			$query_gene .= generate_clause( "?", "", "", "lower(pd.value)" );
			push @args, lc("%".$hash->{geneDesc} . "%");
			$and = " AND ";
		}
		if ( exists $hash->{noDesc} && $hash->{noDesc} ) {
			$query_gene .=
			  generate_clause( "?", "NOT", $and, "lower(pd.value)" );
			push @args, "%" . lc( $hash->{noDesc} ) . "%";
		}
		
		if (   ( exists $hash->{geneDescription} && $hash->{geneDescription} )
		|| ( exists $hash->{noDescription} && $hash->{noDescription} ) )
		{
			my @likesDescription   = ();
			my @likesNoDescription = ();
			if ( $hash->{geneDescription} ) {
				while ( $hash->{geneDescription} =~ /(\S+)/g ) {
					push @likesDescription,
					  generate_clause( "?", "", "",
						"lower(pd.value)"
					  );
					push @args, lc( "%" . $1 . "%" );
				}
			}
			if ( $hash->{noDescription} ) {
				while ( $hash->{noDescription} =~ /(\S+)/g ) {
					push @likesNoDescription,
					  generate_clause( "?", "NOT", "",
						"lower(pd.value)"
					  );
					push @args, lc( "%" . $1 . "%" );
				}
			}
	
			if (    exists $hash->{individually}
				and $hash->{individually}
				and scalar(@likesDescription) > 0 )
			{
				if ( scalar(@likesNoDescription) > 0 ) {
					foreach my $like (@likesDescription) {
						$query_gene .= " AND " . $like;
					}
					foreach my $notLike (@likesNoDescription) {
						$query_gene .= " AND " . $notLike;
					}
				}
				else {
					foreach my $like (@likesDescription) {
						$query_gene .= " AND " . $like;
					}
				}
			}
			elsif ( scalar(@likesDescription) > 0 ) {
				my $and = "";
				if ( scalar(@likesNoDescription) > 0 ) {
					foreach my $notLike (@likesNoDescription) {
						$query_gene .= " AND " . $notLike;
					}
					$and = "1";
				}
				if ($and) {
					$and = " AND ";
				}
				else {
					$and = " OR ";
				}
				$query_gene .= " AND (";
				my $counter = 0;
				foreach my $like (@likesDescription) {
					if ( $counter == 0 ) {
						$query_gene .= $like;
						$counter++;
					}
					else {
						$query_gene .= $and . $like;
					}
				}
				$query_gene .= " ) ";
			}
			elsif ( scalar(@likesDescription) <= 0
				and scalar(@likesNoDescription) > 0 )
			{
				foreach my $like (@likesNoDescription) {
					$query_gene .= " AND " . $like;
				}
			}
		}
		
		$query_gene .= ")";
		$query_gene = $connector . $query_gene;
		$connector  = "1";
	}
	if (   ( exists $hash->{noGO} && $hash->{noGO} )
		|| ( exists $hash->{goID}   && $hash->{noGO} )
		|| ( exists $hash->{goDesc} && $hash->{noGO} ) )
	{
		$query_GO =
		    "(SELECT DISTINCT r.object_id "
		  . "FROM feature_relationship r "
		  . "JOIN featureloc l ON (r.object_id = l.feature_id) "
		  . "JOIN featureprop p ON (p.feature_id = l.srcfeature_id) "
		  . "JOIN cvterm c ON (p.type_id = c.cvterm_id) "
		  . "JOIN feature_relationship pr ON (r.subject_id = pr.object_id) "
		  . "JOIN featureprop pd ON (pr.subject_id = pd.feature_id) "
		  . "JOIN cvterm cpd ON (pd.type_id = cpd.cvterm_id) "
		  . "WHERE c.name ='pipeline_id' AND p.value = ? ";

		push @args, $hash->{pipeline};

		$connector = " INTERSECT " if $connector;

		if ( exists $hash->{noGO} && $hash->{noGO} ) {
			$connector = " EXCEPT " if $connector;
			$query_GO .= "AND cpd.name LIKE 'evidence_%' ";
		}
		elsif ( exists $hash->{goID} && $hash->{goID} ) {
			$query_GO .=
			  "AND cpd.name LIKE 'evidence_%' AND lower(pd.value) LIKE ?)";
			push @args, "%" . lc( $hash->{'goID'} ) . "%";
		}
		elsif ( exists $hash->{goDesc} && $hash->{goDesc} ) {
			$query_GO .=
			  "and cpd.name like 'evidence_%' and "
			  . generate_clause( "?", "", "", "lower(pd.value)" ) . " )";
			push @args, "%" . lc( $hash->{'goDesc'} ) . "%";
		}
		$query_GO  = $connector . $query_GO . ")";
		$connector = "1";
	}
	if (   ( exists $hash->{'noTC'} && $hash->{'noTC'} )
		|| ( exists $hash->{'tcdbID'}       && $hash->{'tcdbID'} )
		|| ( exists $hash->{'tcdbFam'}      && $hash->{'tcdbFam'} )
		|| ( exists $hash->{'tcdbSubclass'} && $hash->{'tcdbSubclass'} )
		|| ( exists $hash->{'tcdbClass'}    && $hash->{'tcdbClass'} )
		|| ( exists $hash->{'tcdbDesc'}     && $hash->{'tcdbDesc'} ) )
	{
		$query_TCDB =
		    "(SELECT DISTINCT r.object_id "
		  . "FROM feature_relationship r "
		  . "JOIN featureloc l ON (r.object_id = l.feature_id) "
		  . "JOIN featureprop p ON (p.feature_id = l.srcfeature_id) "
		  . "JOIN cvterm c ON (p.type_id = c.cvterm_id) "
		  . "JOIN feature_relationship pr ON (r.subject_id = pr.object_id) "
		  . "JOIN featureprop ppr ON (pr.subject_id = ppr.feature_id) "
		  . "JOIN featureprop pd ON (pr.subject_id = pd.feature_id) "
		  . "JOIN cvterm cpd ON (pd.type_id = cpd.cvterm_id) "
		  . "WHERE c.name ='pipeline_id' AND p.value = ? ";
		push @args, $hash->{pipeline};

		$connector = " INTERSECT " if $connector;

		if ( $hash->{'noTC'} ) {
			$connector = " EXCEPT " if $connector;
			$query_TCDB .= " AND cpd.name = 'TCDB_ID'";
		}
		elsif ( $hash->{'tcdbID'} ) {
			$query_TCDB .= "AND cpd.name = 'TCDB_ID' AND pd.value = ?";
			push @args, $hash->{'tcdbID'};
		}
		elsif ( $hash->{'tcdbFam'} ) {
			$query_TCDB .=
			  "AND cpd.name = 'TCDB_family' AND lower(pd.value) LIKE ?";
			push @args, "%" . lc( $hash->{'tcdbFam'} ) . "%";
		}
		elsif ( $hash->{'tcdbSubclass'} ) {
			$query_TCDB .=
			  "AND cpd.name = 'TCDB_subclass' AND lower(pd.value) LIKE ?";
			push @args, "%" . lc( $hash->{'tcdbSubclass'} ) . "%";
		}
		elsif ( $hash->{'tcdbClass'} ) {
			$query_TCDB .=
			  "AND cpd.name = 'TCDB_class' AND lower(pd.value) LIKE ?";
			push @args, "%" . lc( $hash->{'tcdbClass'} ) . "%";
		}
		elsif ( $hash->{'tcdbDesc'} ) {
			$query_TCDB .=
			  "and cpd.name = 'hit_description' and "
			  . generate_clause( "?", "", "", "lower(pd.value)" );
			push @args, lc( $hash->{'tcdbDesc'} );
		}
		$query_TCDB = $connector . $query_TCDB . ")";
		$connector  = "1";
	}
	if (   ( exists $hash->{'noBlast'} && $hash->{'noBlast'} )
		|| ( exists $hash->{'blastID'}   && $hash->{'blastID'} )
		|| ( exists $hash->{'blastDesc'} && $hash->{'blastDesc'} ) )
	{
		$query_blast = "(SELECT DISTINCT r.object_id " . " FROM feature f
                JOIN feature_relationship r ON (r.subject_id = f.feature_id)
                JOIN feature fo ON (r.object_id = fo.feature_id)
                JOIN analysisfeature af ON (f.feature_id = af.feature_id)
                JOIN analysis a ON (a.analysis_id = af.analysis_id)
                JOIN featureloc l ON (r.object_id = l.feature_id)
                JOIN featureprop p ON (p.feature_id = srcfeature_id)
                JOIN cvterm c ON (p.type_id = c.cvterm_id)
                JOIN feature_relationship ra ON (ra.object_id = f.feature_id)
                JOIN cvterm cra ON (ra.type_id = cra.cvterm_id)
                JOIN featureprop pfo ON (ra.subject_id = pfo.feature_id)
                JOIN cvterm cpfo ON (cpfo.cvterm_id = pfo.type_id)
                JOIN featureprop pr ON (r.object_id = pr.feature_id)
                JOIN cvterm cpr ON (pr.type_id = cpr.cvterm_id) ";
		my $conditional =
"WHERE a.program = 'annotation_blast.pl' AND c.name ='pipeline_id' AND p.value = ? AND cra.name = 'alignment' AND cpfo.name = 'subject_id'";
		push @args, $hash->{pipeline};
		$connector = " INTERSECT " if $connector;
		if ( $hash->{'noBlast'} ) {
			$connector = " EXCEPT " if $connector;
		}
		elsif ( $hash->{'blastID'} ) {
			$conditional .= " AND lower(pfo.value) LIKE ?";
			push @args, "%" . lc( $hash->{'blastID'} ) . "%";
		}
		elsif ( $hash->{'blastDesc'} ) {
			$conditional .=
			  " AND " . generate_clause( "?", "", "", "lower(pfo.value)" );
			push @args, $hash->{'blastDesc'};
		}
		$query_blast = $connector . $query_blast . $conditional . ")";
		$connector   = "1";
	}
	if (   ( exists $hash->{'noRps'} && $hash->{'noRps'} )
		|| ( exists $hash->{'rpsID'}   && $hash->{'rpsID'} )
		|| ( exists $hash->{'rpsDesc'} && $hash->{'rpsDesc'} ) )
	{
		$query_RPS =
		    "(select distinct r.object_id "
		  . " from feature f "
		  . "join feature_relationship r on (r.subject_id = f.feature_id) "
		  . "join feature fo on (r.object_id = fo.feature_id) "
		  . "join analysisfeature af on (f.feature_id = af.feature_id) "
		  . "join analysis a on (a.analysis_id = af.analysis_id) "
		  . "join featureloc l on (r.object_id = l.feature_id) "
		  . "join featureprop p on (p.feature_id = srcfeature_id) "
		  . "join cvterm c on (p.type_id = c.cvterm_id) "
		  . "join feature_relationship ra on (ra.object_id = f.feature_id) "
		  . "join cvterm cra on (ra.type_id = cra.cvterm_id) "
		  . "join featureprop pfo on (ra.subject_id = pfo.feature_id) "
		  . "join cvterm cpfo on (cpfo.cvterm_id = pfo.type_id) "
		  . "join featureprop pr on (r.object_id = pr.feature_id) "
		  . "join cvterm cpr on (pr.type_id = cpr.cvterm_id) ";
		my $conditional =
"where a.program = 'annotation_rpsblast.pl' and c.name ='pipeline_id' and p.value = ? and cra.name = 'alignment' and cpfo.name = 'subject_id' ";
		push @args, $hash->{pipeline};
		$connector = " INTERSECT " if $connector;

		if ( $hash->{'noRps'} ) {
			$connector = " EXCEPT " if $connector;
		}
		elsif ( $hash->{'rpsID'} ) {
			$conditional .= " and lower(pfo.value) like ? ";
			push @args, "%" . lc( $hash->{'rpsID'} ) . "%";
		}
		elsif ( $hash->{'rpsDesc'} ) {
			$conditional .=
			  " and " . generate_clause( "?", "", "", "lower(pfo.value)" );
			push @args, "%" . lc( $hash->{'rpsDesc'} ) . "%";
		}
		$query_RPS = $connector . $query_RPS . $conditional . ")";
		$connector = 1;
	}
	if (   $hash->{'noKEGG'}
		|| $hash->{'koID'}
		|| $hash->{'keggPath'}
		|| $hash->{'keggDesc'} )
	{
		$query_KEGG =
		    "(select distinct r.object_id "
		  . "from feature_relationship r "
		  . "join featureloc l on (r.object_id = l.feature_id)"
		  . "join featureprop p on (p.feature_id = l.srcfeature_id)"
		  . "join cvterm c on (p.type_id = c.cvterm_id)"
		  . "join feature_relationship pr on (r.subject_id = pr.object_id)"
		  . "join featureprop ppr on (pr.subject_id = ppr.feature_id)"
		  . "join featureprop pd on (pr.subject_id = pd.feature_id)"
		  . "join cvterm cpd on (pd.type_id = cpd.cvterm_id) ";
		my $conditional = " where c.name ='pipeline_id' and p.value = ? ";
		push @args, $hash->{pipeline};
		$connector = " intersect " if $connector;
		if ( $hash->{'noKEGG'} ) {
			$connector = " except " if $connector;
			$conditional .= " and cpd.name = 'orthologous_group_id'";
		}
		elsif ( $hash->{'koID'} ) {
			$conditional .=
" and cpd.name = 'orthologous_group_id' and lower(pd.value) LIKE ? ";
			push @args, "%" . lc( $hash->{'koID'} ) . "%";
		}
		elsif ( $hash->{'keggPath'} ) {
			$conditional .=
" and cpd.name = 'metabolic_pathway_id' and lower(pd.value) like ? ";
			push @args, "%" . lc( $hash->{'keggPath'} ) . "%";
		}
		elsif ( $hash->{'keggDesc'} ) {
			$query_KEGG .=
			    " join analysisfeature af on (r.subject_id = af.feature_id)"
			  . "join analysis a on (a.analysis_id = af.analysis_id) ";
			$conditional .=
" and a.program = 'annotation_pathways.pl' and cpd.name = 'orthologous_group_description' and "
			  . generate_clause( "?", "", "", "pd.value" );
			push @args, "%" . lc( $hash->{'keggDesc'} ) . "%";
		}
		$query_KEGG = $connector . $query_KEGG . $conditional . ")";
		$connector  = "1";
	}
	if (   ( exists $hash->{'noOrth'} && $hash->{'noOrth'} )
		|| ( exists $hash->{'orthID'}   && $hash->{'orthID'} )
		|| ( exists $hash->{'orthDesc'} && $hash->{'orthDesc'} ) )
	{
		$query_ORTH =
		    "(select distinct r.object_id"
		  . " from feature_relationship r "
		  . "join featureloc l on (r.object_id = l.feature_id) "
		  . "join featureprop p on (p.feature_id = l.srcfeature_id) "
		  . "join cvterm c on (p.type_id = c.cvterm_id) "
		  . "join feature_relationship pr on (r.subject_id = pr.object_id) "
		  . "join featureprop ppr on (pr.subject_id = ppr.feature_id) "
		  . "join featureprop pd on (pr.subject_id = pd.feature_id) "
		  . "join cvterm cpd on (pd.type_id = cpd.cvterm_id) ";
		my $conditional = "where c.name ='pipeline_id' and p.value = ? ";
		push @args, $hash->{pipeline};
		$connector = " intersect " if $connector;
		if ( $hash->{'noOrth'} ) {
			$connector = " except " if $connector;
			$conditional .= " and cpd.name = 'orthologous_group' ";
		}
		elsif ( $hash->{'orthID'} ) {
			$conditional =
			  "and cpd.name = 'orthologous_group' and lower(pd.value) like ? ";
			push @args, "%" . lc( $hash->{'orthID'} ) . "%";
		}
		elsif ( $hash->{'orthDesc'} ) {
			$query_ORTH .=
			    " join analysisfeature af on (r.subject_id = af.feature_id) "
			  . " join analysis a on (a.analysis_id = af.analysis_id) ";
			$conditional .=
" and a.program = 'annotation_orthology.pl' and cpd.name = 'orthologous_group_description' and "
			  . generate_clause( "?", "", "", "lower(pd.value)" );
			push @args, "%" . $hash->{'orthDesc'} . "%";
		}
		$query_ORTH = $connector . $query_ORTH . $conditional . ")";
		$connector  = "1";
	}
	if (   ( exists $hash->{'noIP'} && $hash->{'noIP'} )
		|| ( exists $hash->{'interproID'}   && $hash->{'interproID'} )
		|| ( exists $hash->{'interproDesc'} && $hash->{'interproDesc'} ) )
	{
		$query_interpro =
		    "(select distinct r.object_id "
		  . " from feature f "
		  . "join feature_relationship r on (r.subject_id = f.feature_id) "
		  . "join featureloc l on (r.object_id = l.feature_id) "
		  . "join featureprop p on (p.feature_id = l.srcfeature_id) "
		  . "join cvterm c on (p.type_id = c.cvterm_id) "
		  . "join feature_relationship pr on (r.subject_id = pr.object_id) "
		  . "join featureprop ppr on (pr.subject_id = ppr.feature_id) "
		  . "join cvterm cpr on (ppr.type_id = cpr.cvterm_id) ";
		my $conditional = "where c.name ='pipeline_id' and p.value = ? ";
		push @args, $hash->{pipeline};
		$connector = " intersect " if $connector;
		if ( $hash->{'noIP'} ) {
			$connector = " except " if $connector;
			$conditional .= "and cpr.name like 'interpro_id'";
		}
		elsif ( $hash->{'interproID'} ) {
			$conditional .=
			  "and cpr.name like 'interpro_id' and ppr.value LIKE ? ";
			push @args, "%" . $hash->{'interproID'} . "%";
		}
		elsif ( $hash->{'interproDesc'} ) {
			$conditional .=
			  "and cpr.name like 'description%' and ppr.value like ? ";
			push @args, "%" . $hash->{'interproDesc'} . "%";
		}
		$query_interpro = $connector . $query_interpro . $conditional . ")";
		$connector      = 1;
	}
	if (   ( exists $hash->{'noTMHMM'} && $hash->{'noTMHMM'} )
		|| ( exists $hash->{'TMHMMdom'}   && $hash->{'TMHMMdom'}   ) )
	{
		my $select = "(SELECT DISTINCT r.object_id       
FROM feature f 
JOIN feature_relationship r ON (r.subject_id = f.feature_id) 
JOIN feature fo ON (r.object_id = fo.feature_id) 
JOIN featureloc l ON (r.object_id = l.feature_id) 
JOIN featureprop p ON (p.feature_id = l.srcfeature_id) 
JOIN analysisfeature af ON (f.feature_id = af.feature_id) 
JOIN analysis a ON (a.analysis_id = af.analysis_id) 
JOIN cvterm c ON (p.type_id = c.cvterm_id)  
JOIN feature_relationship pr ON (r.subject_id = pr.object_id) 
JOIN featureprop ppr ON (pr.subject_id = ppr.feature_id) 
JOIN cvterm cpr ON (ppr.type_id = cpr.cvterm_id)  
JOIN featureprop pp ON (pr.subject_id = pp.feature_id) 
JOIN cvterm cpp ON (pp.type_id = cpp.cvterm_id) 
JOIN featureprop ppp ON (pr.subject_id = ppp.feature_id)       
JOIN cvterm cppp ON (ppp.type_id = cppp.cvterm_id)
WHERE a.program = 'annotation_tmhmm.pl' AND c.name ='pipeline_id' AND p.value=? AND cpr.name ='version' AND cpp.name='direction' AND cppp.name='predicted_TMHs' ";
		push @args, $hash->{pipeline};
		$connector = " INTERSECT " if $connector;
		if($hash->{'noTMHMM'}) {
			$connector = " EXCEPT " if $connector;
			$query_tmhmm = $connector . $select . ")";
		} elsif($hash->{'TMHMMdom'}) {
			$select .= " AND my_to_decimal(ppp.value) ";
			if ( $hash->{'tmhmmQuant'} eq "exact" ) {
				$select .= "= ? ";
			}
			elsif ( $hash->{'tmhmmQuant'} eq "orLess" ) {
				$select .= "<= ? ";
			}
			elsif ( $hash->{'tmhmmQuant'} eq "orMore" ) {
				$select .= ">= ? ";
			}
			push @args, $hash->{'TMHMMdom'} if $hash->{'tmhmmQuant'};
			$query_Phobius = $connector . $select . ")";
			$connector     = "1";
		} else {
			$query_tmhmm = "";
		}
		
	}
	if (    ( exists $hash->{'noDGPI'} && $hash->{'noDGPI'} )
		||  ( exists $hash->{'cleavageSiteDGPI'}   && $hash->{'cleavageSiteDGPI'}   ) 
		||  ( exists $hash->{'scoreDGPI'}   && $hash->{'scoreDGPI'}   )  )
	{
		my $select = "(SELECT DISTINCT r.object_id       
FROM feature f 
JOIN feature_relationship r ON (r.subject_id = f.feature_id) 
JOIN feature fo ON (r.object_id = fo.feature_id) 
JOIN featureloc l ON (r.object_id = l.feature_id) 
JOIN featureprop p ON (p.feature_id = l.srcfeature_id) 
JOIN analysisfeature af ON (f.feature_id = af.feature_id) 
JOIN analysis a ON (a.analysis_id = af.analysis_id) 
JOIN cvterm c ON (p.type_id = c.cvterm_id)  
JOIN feature_relationship pr ON (r.subject_id = pr.object_id) 
JOIN featureprop ppr ON (pr.subject_id = ppr.feature_id) 
JOIN cvterm cpr ON (ppr.type_id = cpr.cvterm_id)
JOIN featureprop pp ON (pr.subject_id = pp.feature_id) 
JOIN cvterm cpp ON (pp.type_id = cpp.cvterm_id)  
WHERE a.program = 'annotation_dgpi.pl' AND c.name='pipeline_id' AND p.value=? AND cpr.name='cleavage_site' AND cpp.name='score' ";
		push @args, $hash->{pipeline};
		$connector = " INTERSECT " if $connector;
		if($hash->{'noDGPI'}) {
			$connector = " EXCEPT " if $connector;
			$query_dgpi = $connector . $select . ")";
		} elsif($hash->{'cleavageSiteDGPI'}) {
			$select .= " AND my_to_decimal(ppr.value) ";
			
			if ( $hash->{'cleavageQuant'} eq "exact" ) {
				$select .= "= ? ";
			}
			elsif ( $hash->{'cleavageQuant'} eq "orLess" ) {
				$select .= "<= ? ";
			}
			elsif ( $hash->{'cleavageQuant'} eq "orMore" ) {
				$select .= ">= ? ";
			}
			push @args, $hash->{'cleavageSiteDGPI'} if $hash->{'cleavageQuant'};
			$query_Phobius = $connector . $select . ")";
			$connector     = "1";
		} elsif($hash->{'scoreDGPI'}) {
			$select .= " AND my_to_decimal(pp.value) ";
			
			if ( $hash->{'scoreQuant'} eq "exact" ) {
				$select .= "= ? ";
			}
			elsif ( $hash->{'scoreQuant'} eq "orLess" ) {
				$select .= "<= ? ";
			}
			elsif ( $hash->{'scoreQuant'} eq "orMore" ) {
				$select .= ">= ? ";
			}
			push @args, $hash->{'scoreDGPI'} if $hash->{'scoreQuant'};
			$query_Phobius = $connector . $select . ")";
			$connector     = "1";
		}
		$connector      = 1;
	}
	if (    ( exists $hash->{'noPreDGPI'} && $hash->{'noPreDGPI'} )
		||  ( exists $hash->{'namePreDGPI'} && $hash->{'namePreDGPI'} ) 
		||  ( exists $hash->{'positionPreDGPI'} && $hash->{'positionPreDGPI'} ) 
		||  ( exists $hash->{'specificityPreDGPI'} && $hash->{'specificityPreDGPI'} ) 
		||  ( exists $hash->{'sequencePreDGPI'} && $hash->{'sequencePreDGPI'} )  ) {
		my $select = "(SELECT DISTINCT r.object_id       
FROM feature f 
JOIN feature_relationship r ON (r.subject_id = f.feature_id) 
JOIN feature fo ON (r.object_id = fo.feature_id) 
JOIN featureloc l ON (r.object_id = l.feature_id) 
JOIN featureprop p ON (p.feature_id = l.srcfeature_id) 
JOIN analysisfeature af ON (f.feature_id = af.feature_id) 
JOIN analysis a ON (a.analysis_id = af.analysis_id) 
JOIN cvterm c ON (p.type_id = c.cvterm_id)  
JOIN feature_relationship pr ON (r.subject_id = pr.object_id) 
JOIN featureprop ppr ON (pr.subject_id = ppr.feature_id) 
JOIN cvterm cpr ON (ppr.type_id = cpr.cvterm_id)  
JOIN featureprop pp ON (pr.subject_id = pp.feature_id) 
JOIN cvterm cpp ON (pp.type_id = cpp.cvterm_id)
JOIN featureprop ppp ON (pr.subject_id = ppp.feature_id) 
JOIN cvterm cppp ON (ppp.type_id = cppp.cvterm_id) 
JOIN featureprop pppp ON (pr.subject_id = pppp.feature_id) 
JOIN cvterm cpppp ON (pppp.type_id = cpppp.cvterm_id)      
WHERE a.program = 'annotation_predgpi.pl' AND c.name='pipeline_id' AND p.value=? AND cpr.name='name' AND cpp.name='position' AND cppp.name='specificity' AND cpppp.name='sequence' ";
		push @args, $hash->{pipeline};
		$connector = " INTERSECT " if $connector;
		if($hash->{'noPreDGPI'}) {
			$connector = " EXCEPT " if $connector;
			$query_predgpi = $connector . $select . ")";
		}
		elsif($hash->{'namePreDGPI'}) {
			$select .= " AND lower(ppr.value ) LIKE ? ";
			push @args, "%" . lc( $hash->{'namePreDGPI'} ) . "%";
			$query_predgpi .= $connector . $select . " ) ";
			$connector     = "1";
		}
		elsif($hash->{'positionPreDGPI'}) {
			$select .= " AND my_to_decimal(pp.value) ";
			if ( $hash->{'positionQuantPreDGPI'} eq "exact" ) {
				$select .= "= ? ";
			}
			elsif ( $hash->{'positionQuantPreDGPI'} eq "orLess" ) {
				$select .= "<= ? ";
			}
			elsif ( $hash->{'positionQuantPreDGPI'} eq "orMore" ) {
				$select .= ">= ? ";
			}
			push @args, $hash->{'positionPreDGPI'} if $hash->{positionQuantPreDGPI};
			$query_predgpi .= $connector . $select . " ) ";
			$connector     = "1";
		}
		elsif($hash->{'specificityPreDGPI'}) {
			$select .= " AND my_to_decimal(ppp.value) ";
			if ( $hash->{'specificityQuantPreDGPI'} eq "exact" ) {
				$select .= "= ? ";
			}
			elsif ( $hash->{'specificityQuantPreDGPI'} eq "orLess" ) {
				$select .= "<= ? ";
			}
			elsif ( $hash->{'specificityQuantPreDGPI'} eq "orMore" ) {
				$select .= ">= ? ";
			}
			push @args, $hash->{'specificityPreDGPI'} if $hash->{specificityQuantPreDGPI};
			$query_predgpi .= $connector . $select . " ) ";
			$connector     = "1";
		}
		elsif($hash->{'sequencePreDGPI'}) {
			$select .= " AND lower(pppp.value ) LIKE ? ";
			push @args, "%" . lc( $hash->{'sequencePreDGPI'} ) . "%";
			$query_predgpi .= $connector . $select . " ) ";
			$connector     = "1";
		}
		
	}
	if (    ( exists $hash->{'noBigGPI'} && $hash->{'noBigGPI'} )
		||  ( exists $hash->{'pvalueBigpi'}   && $hash->{'pvalueBigpi'}   ) 
		||  ( exists $hash->{'positionBigpi'}   && $hash->{'positionBigpi'}   )  )
	{
		my $select = "(SELECT DISTINCT r.object_id       
FROM feature f 
JOIN feature_relationship r ON (r.subject_id = f.feature_id) 
JOIN feature fo ON (r.object_id = fo.feature_id) 
JOIN featureloc l ON (r.object_id = l.feature_id) 
JOIN featureprop p ON (p.feature_id = l.srcfeature_id) 
JOIN analysisfeature af ON (f.feature_id = af.feature_id) 
JOIN analysis a ON (a.analysis_id = af.analysis_id) 
JOIN cvterm c ON (p.type_id = c.cvterm_id)  
JOIN feature_relationship pr ON (r.subject_id = pr.object_id) 
JOIN featureprop ppr ON (pr.subject_id = ppr.feature_id) 
JOIN cvterm cpr ON (ppr.type_id = cpr.cvterm_id)
JOIN featureprop pp ON (pr.subject_id = pp.feature_id) 
JOIN cvterm cpp ON (pp.type_id = cpp.cvterm_id)  
WHERE a.program = 'annotation_bigpi.pl' AND c.name='pipeline_id' AND p.value=? AND cpr.name='pvalue' AND cpp.name='position' ";
		push @args, $hash->{pipeline};
		$connector = " INTERSECT " if $connector;
		if($hash->{'noBigGPI'}) {
			$connector = " EXCEPT " if $connector;
			$query_predgpi = $connector . $select . ")";
		} elsif ($hash->{'pvalueBigpi'}) {
			$select .= " AND my_to_decimal(ppr.value) ";
			if ( $hash->{'pvalueQuantBigpi'} eq "exact" ) {
				$select .= "= ? ";
			}
			elsif ( $hash->{'pvalueQuantBigpi'} eq "orLess" ) {
				$select .= "<= ? ";
			}
			elsif ( $hash->{'pvalueQuantBigpi'} eq "orMore" ) {
				$select .= ">= ? ";
			}
			push @args, $hash->{'pvalueBigpi'} if $hash->{pvalueQuantBigpi};
			$query_bigpi .= $connector . $select . " ) ";
			$connector     = "1";
		} elsif ($hash->{'positionBigpi'}) {
			$select .= " AND my_to_decimal(pp.value) ";
			if ( $hash->{'positionQuantBigpi'} eq "exact" ) {
				$select .= "= ? ";
			}
			elsif ( $hash->{'positionQuantBigpi'} eq "orLess" ) {
				$select .= "<= ? ";
			}
			elsif ( $hash->{'positionQuantBigpi'} eq "orMore" ) {
				$select .= ">= ? ";
			}
			push @args, $hash->{'positionBigpi'} if $hash->{positionQuantBigpi};
			$query_bigpi .= $connector . $select . " ) ";
			$connector     = "1";
		}
	}
	if (   ( exists $hash->{'noPhobius'} && $hash->{'noPhobius'} )
		|| ( exists $hash->{'TMdom'} && $hash->{'TMdom'} ) )
	{
		my $select = "(SELECT DISTINCT r.object_id ";
		my $join =
		    "FROM feature f "
		  . "JOIN feature_relationship r ON (r.subject_id = f.feature_id) "
		  . "JOIN feature fo ON (r.object_id = fo.feature_id) "
		  . "JOIN featureloc l ON (r.object_id = l.feature_id) "
		  . "JOIN featureprop p ON (p.feature_id = l.srcfeature_id) "
		  . "JOIN analysisfeature af ON (f.feature_id = af.feature_id) "
		  . "JOIN analysis a ON (a.analysis_id = af.analysis_id) "
		  . "JOIN cvterm c ON (p.type_id = c.cvterm_id) ";
		my $conditional =
"WHERE a.program = 'annotation_phobius.pl' AND c.name ='pipeline_id' AND p.value=? ";
		push @args, $hash->{pipeline};

		$connector = " INTERSECT " if $connector;
		if ( $hash->{noPhobius} ) {
			$connector = " EXCEPT " if $connector;
			$query_Phobius = $connector . $select . $join . $conditional . ")";
		}
		elsif ( $hash->{'TMdom'} ) {
			$join .=
			    "JOIN feature_relationship pr ON (r.subject_id = pr.object_id) "
			  . "JOIN featureprop ppr ON (pr.subject_id = ppr.feature_id) "
			  . "JOIN cvterm cpr ON (ppr.type_id = cpr.cvterm_id) "
			  . "JOIN featureprop pp ON (pr.subject_id = pp.feature_id) "
			  . "JOIN cvterm cpp ON (pp.type_id = cpp.cvterm_id) ";
			$conditional .=
" AND cpr.name = 'classification' AND ppr.value= 'TRANSMEM' AND cpp.name = 'predicted_TMHs' AND my_to_decimal(pp.value) ";

			if ( $hash->{'tmQuant'} eq "exact" ) {
				$conditional .= "= ? ";
			}
			elsif ( $hash->{'tmQuant'} eq "orLess" ) {
				$conditional .= "<= ? ";
			}
			elsif ( $hash->{'tmQuant'} eq "orMore" ) {
				$conditional .= ">= ? ";
			}
			push @args, $hash->{'TMdom'} if $hash->{'tmQuant'};
			$query_Phobius = $connector . $select . $join . $conditional . ")";
			$connector     = "1";
		}
		else {
			$query_Phobius = "";
		}
		if ( $hash->{'sigP'} ne "sigPwhatever" ) {
			if ( $hash->{'sigP'} ne "sigPwhatever"
				&& !$hash->{'noPhobius'} )
			{
				my $sigPconn = "";
				if ( $hash->{'sigP'} eq "sigPyes" ) {
					$sigPconn = " INTERSECT " if $connector;
				}
				elsif ( $hash->{'sigP'} eq "sigPno" ) {
					$sigPconn = " EXCEPT " if $connector;
				}

				$query_sigP .=
				  " $sigPconn (SELECT DISTINCT r.object_id FROM feature f
                        JOIN feature_relationship r ON (r.subject_id = f.feature_id)
                        JOIN feature fo ON (r.object_id = fo.feature_id)
                        JOIN featureloc l ON (r.object_id = l.feature_id)
                        JOIN featureprop p ON (p.feature_id = l.srcfeature_id)
                        JOIN analysisfeature af ON (f.feature_id = af.feature_id)
                        JOIN analysis a ON (a.analysis_id = af.analysis_id)
                        JOIN cvterm c ON (p.type_id = c.cvterm_id)
                        JOIN feature_relationship pr ON (r.subject_id = pr.object_id)
                        JOIN featureprop ppr ON (pr.subject_id = ppr.feature_id)
                        JOIN cvterm cpr ON (ppr.type_id = cpr.cvterm_id)
                        JOIN featureprop pp ON (pr.subject_id = pp.feature_id)
                        JOIN cvterm cpp ON (pp.type_id = cpp.cvterm_id)
                        where a.program = 'annotation_phobius.pl' AND c.name = 'pipeline_id' AND p.value = ? AND cpr.name = 'classification' AND ppr.value = 'SIGNAL')";
				push @args, $hash->{pipeline};
			}
			$connector = "1";
		}
	}

	$query =
	    $query
	  . $query_gene
	  . $query_GO
	  . $query_TCDB
	  . $query_Phobius
	  . $query_sigP
	  . $query_blast
	  . $query_RPS
	  . $query_KEGG
	  . $query_ORTH
	  . $query_interpro
	  . $query_tmhmm
	  . $query_dgpi
	  . $query_bigpi
	  . $query_predgpi
	  . " ) as motherfuckerquery GROUP BY motherfuckerquery.feature_id ORDER BY motherfuckerquery.feature_id ";
	  
	if (!$query_Phobius) {
		my $quantityParameters = () = $query =~ /\?/g;
		my $counter = scalar @args;
		if($counter > $quantityParameters) {
			while(scalar @args > $quantityParameters) {
				print STDERR "
ARGS:	".$_."
" foreach (@args);
				shift @args;
#				delete $args[$counter-1];
#				$counter--;
			}
		}
	}
	  
	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$query .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$query .= " OFFSET 0 ";
		}
		else {
			$query .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}	

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my %returnedHash = ();
	my @list         = ();
	
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		push @list, $rows[$i][0];
		$returnedHash{total} = $rows[$i][1];
	}

	$returnedHash{list} = \@list;

	return \%returnedHash;
}

=head2

Method used to generate clause for any query

=cut

sub generate_clause {
	my $terms = shift;
	my $not   = shift || "";
	my $and   = shift || "";
	my $field = shift;

	my @terms  = split( /\s+/, $terms );
	my $clause = " $and (";
	my $i      = 0;
	foreach my $term (@terms) {
		my $com = "";
		$com = " or " if $i > 0;
		$clause .= "$com $field $not like $term";
		$i++;
	}
	$clause .= ")";
	return $clause;
}

=head2

Method used to realize search of rRNAs by contig and type

=cut

sub rRNA_search {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query = "select f.feature_id, COUNT(*) OVER() AS total
from feature f 
join feature_relationship r on (f.feature_id = r.object_id) 
join cvterm cr on (r.type_id = cr.cvterm_id) 
join featureprop ps on (r.subject_id = ps.feature_id) 
join cvterm cs on (ps.type_id = cs.cvterm_id) 
join featureprop pf on (f.feature_id = pf.feature_id) 
join cvterm cf on (pf.type_id = cf.cvterm_id) 
join featureloc l on (l.feature_id = f.feature_id) 
join featureprop pl on (l.srcfeature_id = pl.feature_id) 
join cvterm cp on (pl.type_id = cp.cvterm_id) 
join featureprop pd on (r.subject_id = pd.feature_id) 
join cvterm cd on (pd.type_id = cd.cvterm_id) 
where cr.name = 'based_on' and cf.name = 'tag' and pf.value='rRNA_prediction' and cs.name = 'locus_tag' and cd.name = 'description' and cp.name = 'pipeline_id' and pl.value=?";
	push @args, $hash->{pipeline};
	
	if(exists $hash->{contig} && $hash->{contig}) {
		$query .= " and l.srcfeature_id = ? ";
		push @args, $hash->{contig};
	}
	
	if(exists $hash->{type} && $hash->{type}) {
		$query .= " and pd.value=?";
		push @args, $hash->{type};
	}
	
	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$query .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$query .= " OFFSET 0 ";
		}
		else {
			$query .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}
	
	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my %returnedHash = ();
	my @list         = ();
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		push @list, $rows[$i][0];
		$returnedHash{total} = $rows[$i][1];
	}
	$returnedHash{"list"} = \@list;

	return \%returnedHash;
	
}

=head2

Method used to return tRNA data from database

=cut

sub tRNA_search {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query =
"select r.object_id AS id, fp.value AS sequence, pt.value AS amino_acid, pa.value AS codon, COUNT(*) OVER() AS total "
	  . "from feature_relationship r "
	  . "join cvterm c on (r.type_id = c.cvterm_id) "
	  . "join featureloc l on (r.subject_id = l.feature_id) "
	  . "join analysisfeature af on (af.feature_id = r.object_id) "
	  . "join analysis a on (a.analysis_id = af.analysis_id) "
	  . "join featureprop p on (p.feature_id = l.srcfeature_id) "
	  . "join cvterm cp on (p.type_id = cp.cvterm_id) "
	  . "join featureprop pt on (r.subject_id = pt.feature_id) "
	  . "join cvterm cpt on (pt.type_id = cpt.cvterm_id) "
	  . "join featureprop pa on (r.subject_id = pa.feature_id) "
	  . "join cvterm cpa on (pa.type_id = cpa.cvterm_id) "
	  . "join featureprop fp on (r.subject_id = fp.feature_id) "
	  . "join cvterm cfp on (fp.type_id = cfp.cvterm_id) "
	  . "where c.name='interval' and a.program = 'annotation_trna.pl' and cp.name='pipeline_id' and p.value=? and cpt.name='type' and cpa.name='anticodon' and cfp.name = 'sequence' ";
	push @args, $hash->{pipeline};
	my $anticodon = "";
	
	if(exists $hash->{contig} && $hash->{contig}) {
		$query .= " and l.srcfeature_id = ? ";
		push @args, $hash->{contig};
	}

	if ( $hash->{'tRNAaa'} ne "" ) {
		$query .= "and pt.value = ?";
		push @args, $hash->{'tRNAaa'};
	}
	elsif ( $hash->{'tRNAcd'} ne "" ) {
		$anticodon = reverseComplement( $hash->{'tRNAcd'} );
		$query .= "and pa.value = ?";
		push @args, $anticodon;
	}
	
	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$query .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$query .= " OFFSET 0 ";
		}
		else {
			$query .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my %returnedHash = ();
	my @list         = ();
	use Report_HTML_DB::Models::Application::TRNASearch;
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my $result = Report_HTML_DB::Models::Application::TRNASearch->new(
			id         => $rows[$i][0],
			sequence   => $rows[$i][2],
			amino_acid => $rows[$i][1],
			codon      => $rows[$i][3],
		);
		$returnedHash{total} = $rows[$i][4];
		push @list, $result;
	}
	$returnedHash{"list"} = \@list;

	return \%returnedHash;
}

=head2

Method used to return tandem repeats data from database

=cut

sub trf_search {
	my ( $self, $hash ) = @_;
	my $dbh       = $self->dbh;
	my @args      = ();
	my $connector = "";
	my $select =
"select fl.uniquename AS contig, l.fstart AS start, l.fend AS end, pp.value AS length, pc.value AS copy_number, pur.value AS sequence, fl.feature_id, COUNT(*) OVER() AS total ";
	my $join = "from feature_relationship r
                 join featureloc l on (r.subject_id = l.feature_id)
                 join feature fl on (fl.feature_id = l.srcfeature_id)
                 join featureprop pp on (r.subject_id = pp.feature_id)
                 join cvterm cp on (pp.type_id = cp.cvterm_id)
                 join featureprop pc on (r.subject_id = pc.feature_id)
                 join cvterm cc on (pc.type_id = cc.cvterm_id)
                 join featureprop pur on (pur.feature_id = r.subject_id)
                 join cvterm cpur on (pur.type_id = cpur.cvterm_id)
                 join analysisfeature af on (r.object_id = af.feature_id)
                 join analysis a on (af.analysis_id = a.analysis_id)
                 join featureprop ps on (ps.feature_id = l.srcfeature_id)
                 join cvterm cps on (ps.type_id = cps.cvterm_id) ";
	my $query =
"where a.program = 'annotation_trf.pl' and cp.name = 'period_size' and cc.name = 'copy_number' and cpur.name='sequence' and cps.name='pipeline_id' and ps.value=? ";
	push @args, $hash->{pipeline};
	
	if(exists $hash->{contig} && $hash->{contig}) {
		$query .= " and l.srcfeature_id = ? ";
		push @args, $hash->{contig};
	}

	if ( $hash->{'TRFrepSeq'} !~ /^\s*$/ ) {
		$hash->{'TRFrepSeq'} =~ s/\s+//g;
		$query .= "and lower(pur.value) ilike ? ";
		$connector = ",";
		push @args, lc("%$hash->{'TRFrepSeq'}%");
	}

	if ( $hash->{'TRFrepSize'} !~ /^\s*$/ ) {
		$hash->{'TRFrepSize'} =~ s/\s+//g;

		if ( $hash->{'TRFsize'} eq "exact" ) {
			$query .= "and pp.value = ? ";
			$connector = ",";
		}
		elsif ( $hash->{'TRFsize'} eq "orLess" ) {
			$query .= "and my_to_decimal(pp.value) <= ? ";
			$connector = ",";
		}
		elsif ( $hash->{'TRFsize'} eq "orMore" ) {
			$query .= "and my_to_decimal(pp.value) >= ? ";
			$connector = ",";
		}
		push @args, $hash->{'TRFrepSize'};
	}

	if (   $hash->{'TRFrepNumMin'} !~ /^\s*$/
		|| $hash->{'TRFrepNumMax'} !~ /^\s*$/ )
	{
		my $min = 0;
		my $max = 0;

		$hash->{'TRFrepNumMin'} =~ s/\s+//g;
		if ( $hash->{'TRFrepNumMin'} ) {
			$min++;
		}

		$hash->{'TRFrepNumMax'} =~ s/\s+//g;
		if ( $hash->{'TRFrepNumMax'} ) {
			$max++;
		}

		if ( $min && $max ) {
			if ( $hash->{'TRFrepNumMin'} == $hash->{'TRFrepNumMax'} ) {
				$query .= "and my_to_decimal(pc.value) = ? ";
				push @args, $hash->{'TRFrepNumMax'};
			}
			elsif ( $hash->{'TRFrepNumMin'} < $hash->{'TRFrepNumMax'} ) {
				$query .=
"and my_to_decimal(pc.value) >= ? and my_to_decimal(pc.value) <= ? ";
				push @args, $hash->{'TRFrepNumMin'};
				push @args, $hash->{'TRFrepNumMax'};
			}
		}
		elsif ($min) {
			$query .= "and my_to_decimal(pc.value) >= ? ";
			push @args, $hash->{'TRFrepNumMin'};
		}
		elsif ($max) {
			$query .= "and my_to_decimal(pc.value) <= ? ";
			push @args, $hash->{'TRFrepNumMax'};
		}
	}

	$query = $select . $join . $query;
	
	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$query .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$query .= " OFFSET 0 ";
		}
		else {
			$query .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my @list = ();
	my %hash = ();
	
	use Report_HTML_DB::Models::Application::TRFSearch;
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my $result = Report_HTML_DB::Models::Application::TRFSearch->new(
			contig      => $rows[$i][0],
			start       => $rows[$i][1],
			end         => $rows[$i][2],
			'length'    => $rows[$i][3],
			copy_number => $rows[$i][4],
			sequence    => $rows[$i][5],
			feature_id	=> $rows[$i][6],
		);
		push @list, $result;
		$hash{total} = $rows[$i][7];
	}

	$hash{list} = \@list;
	return \%hash;
}

=head2

Method used to return non coding RNAs data from database

=cut

sub ncRNA_search {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $select =
"select distinct r.object_id AS id, fl.uniquename AS contig, l.fstart AS end, l.fend AS start, pp.value AS description, COUNT(*) OVER() AS total ";
	my $join = " from feature_relationship r 
                join featureloc lc on (r.subject_id = lc.feature_id)
                join feature fl on (fl.feature_id = lc.srcfeature_id)
                join cvterm c on (r.type_id = c.cvterm_id)
                join featureloc l on (r.subject_id = l.feature_id)
                join analysisfeature af on (af.feature_id = r.object_id)
                join analysis a on (a.analysis_id = af.analysis_id)
                join featureprop p on (p.feature_id = l.srcfeature_id) 
                join cvterm cp on (p.type_id = cp.cvterm_id) 
                join featureprop pp on (pp.feature_id = r.subject_id) 
                join cvterm cpp on (pp.type_id = cpp.cvterm_id) ";
	my $query =
"where c.name='interval' and a.program = 'annotation_infernal.pl' and cp.name='pipeline_id' and p.value=? and cpp.name='target_description' ";
	push @args, $hash->{pipeline};
	
	if(exists $hash->{contig} && $hash->{contig}) {
		$query .= " and l.srcfeature_id = ? ";
		push @args, $hash->{contig};
	}

	if ( $hash->{'ncRNAtargetID'} !~ /^\s*$/ ) {
		$hash->{'ncRNAtargetID'} =~ s/\s+//g;
		$select .= ", ppc.value AS Target_ID";
		$join .=
"join featureprop ppc on (ppc.feature_id = r.subject_id) join cvterm cppc on (ppc.type_id = cppc.cvterm_id) ";
		$query .=
		  "and cppc.name = 'target_identifier' and lower(ppc.value) LIKE ? ";
		push @args, "%" . lc( $hash->{'ncRNAtargetID'} ) . "%";
	}

	elsif ( $hash->{'ncRNAevalue'} !~ /^\s*$/ ) {
		$hash->{'ncRNAevalue'} =~ s/\s+//g;
		$select .= ", ppe.value AS evalue";
		$join .=
"join featureprop ppe on (ppe.feature_id = r.subject_id) join cvterm cppe on (ppe.type_id = cppe.cvterm_id) ";
		if ( $hash->{'ncRNAevM'} eq "exact" ) {
			$query .=
			  "and cppe.name = 'evalue' and my_to_decimal(ppe.value) = ? ";
		}
		elsif ( $hash->{'ncRNAevM'} eq "orLess" ) {
			$query .=
			  "and cppe.name = 'evalue' and my_to_decimal(ppe.value) <= ? ";
		}
		elsif ( $hash->{'ncRNAevM'} eq "orMore" ) {
			$query .=
			  "and cppe.name = 'evalue' and my_to_decimal(ppe.value) >= ? ";
		}
		push @args, $hash->{'ncRNAevalue'};
	}
	elsif ( $hash->{'ncRNAtargetName'} !~ /^\s*$/ ) {
		$hash->{'ncRNAtargetName'} =~ s/^\s+//;
		$hash->{'ncRNAtargetName'} =~ s/\s+$//;
		$select .= ", ppn.value AS Target_name";
		$join .=
"join featureprop ppn on (ppn.feature_id = r.subject_id) join cvterm cppn on (ppn.type_id = cppn.cvterm_id) ";
		$query .= "and cppn.name = 'target_name' and lower(ppn.value) ilike ? ";
		push @args, lc( "%" . $hash->{'ncRNAtargetName'} . "%" );
	}

	elsif ( $hash->{'ncRNAtargetClass'} !~ /^\s*$/ ) {
		$select .= ", ppc.value AS Target_class";
		$join .=
"join featureprop ppc on (ppc.feature_id = r.subject_id) join cvterm cppc on (ppc.type_id = cppc.cvterm_id) ";
		$query .= "and cppc.name = 'target_class' and ppc.value = ? ";
		push @args, $hash->{'ncRNAtargetClass'};
	}

	elsif ( $hash->{'ncRNAtargetType'} !~ /^\s*$/ ) {
		$hash->{'ncRNAtargetType'} =~ s/^\s+//;
		$hash->{'ncRNAtargetType'} =~ s/\s+$//;
		$select .= ", ppt.value AS Target_type";
		$join .=
"join featureprop ppt on (ppt.feature_id = r.subject_id) join cvterm cppt on (ppt.type_id = cppt.cvterm_id) ";
		$query .= "and cppt.name = 'target_type' and lower(ppt.value) ilike ? ";
		push @args, lc( "%" . $hash->{'ncRNAtargetType'} . "%" );
	}
	elsif ( $hash->{'ncRNAtargetDesc'} !~ /^\s*$/ ) {
		$hash->{'ncRNAtargetDesc'} =~ s/^\s+//;
		$hash->{'ncRNAtargetDesc'} =~ s/\s+$//;
		$query .= "and lower(pp.value) like ? ";
		push @args, lc( "%" . $hash->{'ncRNAtargetDesc'} . "%" );
	}

	$query = $select . $join . $query;
	
	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$query .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$query .= " OFFSET 0 ";
		}
		else {
			$query .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my @list = ();
	my %hash = ();
	use Report_HTML_DB::Models::Application::NcRNASearch;
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my $result = Report_HTML_DB::Models::Application::NcRNASearch->new(
			id           => $rows[$i][0],
			contig       => $rows[$i][1],
			start        => $rows[$i][3],
			end          => $rows[$i][2],
			description  => $rows[$i][4],
			target_ID    => $rows[$i][6] ? $rows[$i][6] !~ '' : '',
			evalue       => $rows[$i][6] ? $rows[$i][6] !~ '' : '',
			target_name  => $rows[$i][6] ? $rows[$i][6] !~ '' : '',
			target_class => $rows[$i][6] ? $rows[$i][6] !~ '' : '',
			target_type  => $rows[$i][6] ? $rows[$i][6] !~ '' : ''

		);
		push @list, $result;
		$hash{total} = $rows[$i][5];
	}
	$hash{list} = \@list;
	return \%hash;
}

=head2

Method used to return transcriptional terminator data from database

=cut

sub transcriptional_terminator_search {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $select =
"select fl.uniquename AS contig, l.fstart AS start, l.fend AS end, ppConfidence.value AS confidence, ppHairpinScore.value AS hairpin_score, ppTailScore.value AS tail_score, fl.feature_id, COUNT(*) OVER() AS total ";
	
	my $join = " from feature_relationship r
                 join featureloc lc on (r.subject_id = lc.feature_id)
                 join feature fl on (fl.feature_id = lc.srcfeature_id)
                 join cvterm c on (r.type_id = c.cvterm_id)
                 join featureloc l on (r.subject_id = l.feature_id)
                 join analysisfeature af on (af.feature_id = r.object_id)
                 join analysis a on (a.analysis_id = af.analysis_id)
                 join featureprop p on (p.feature_id = l.srcfeature_id)
                 join cvterm cp on (p.type_id = cp.cvterm_id)
                 join featureprop ppConfidence on (ppConfidence.feature_id = r.subject_id)
                 join cvterm cppConfidence on (ppConfidence.type_id = cppConfidence.cvterm_id) 
                 join featureprop ppHairpinScore on (ppHairpinScore.feature_id = r.subject_id)
                 join cvterm cppHairpinScore on (ppHairpinScore.type_id = cppHairpinScore.cvterm_id) 
                 join featureprop ppTailScore on (ppTailScore.feature_id = r.subject_id)
                 join cvterm cppTailScore on (ppTailScore.type_id = cppTailScore.cvterm_id) ";
	my $query =
"where c.name='interval' and a.program = 'annotation_transterm.pl' and cp.name='pipeline_id' and p.value=? and cppConfidence.name = 'confidence' AND cppHairpinScore.name = 'hairpin' AND cppTailScore.name = 'tail' ";
	push @args, $hash->{pipeline};
	
	if(exists $hash->{contig} && $hash->{contig}) {
		$query .= " and l.srcfeature_id = ? ";
		push @args, $hash->{contig};
	}

	my $search_field;
	my $field;
	my $modifier;

	if ( $hash->{'TTconf'} !~ /^\s*$/ ) {
		$search_field = $hash->{'TTconf'} + 1;
		$modifier     = $hash->{'TTconfM'};
		$field        = "ppConfidence";
	}
	elsif ( $hash->{'TThp'} !~ /^\s*$/ ) {
		$search_field = $hash->{'TThp'} + 1;
		$modifier     = $hash->{'TThpM'};
		$field        = "ppHairpinScore";
	}
	elsif ( $hash->{'TTtail'} !~ /^\s*$/ ) {
		$search_field = $hash->{'TTtail'} + 1;
		$modifier     = $hash->{'TTtailM'};
		$field        = "ppTailScore";
	}

	$search_field =~ s/\s+//g;

	if ( $modifier eq "exact" ) {
		$query .= " and my_to_decimal($field.value) = ? ";
	}
	elsif ( $modifier eq "orLess" ) {
		$query .= " and my_to_decimal($field.value) <= ? ";
	}
	elsif ( $modifier eq "orMore" ) {
		$query .= " and my_to_decimal($field.value) >= ? ";
	}

	push @args, ($search_field - 1) if ($search_field);

	$query = $select . $join . $query;

	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$query .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$query .= " OFFSET 0 ";
		}
		else {
			$query .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my %hash = ();
	my @list    = ();
	my @columns = @{ $sth->{NAME} };
	use Report_HTML_DB::Models::Application::TranscriptionalTerminator;
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my $result = Report_HTML_DB::Models::Application::TranscriptionalTerminator->new(
			contig 			=> $rows[$i][0],
			start  			=> $rows[$i][1],
			end    			=> $rows[$i][2],
			confidence    	=> $rows[$i][3],
			hairpin_score  	=> $rows[$i][4],
			tail_score    	=> $rows[$i][5],
			feature_id		=> $rows[$i][6],
		);
		push @list, $result;
		$hash{total} = $rows[$i][7];
	}
	$hash{list} = \@list;
	return \%hash;
}

=head2

Method used to return ribosomal binding sites data from database

=cut

sub rbs_search {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $select =
"select fl.uniquename AS contig, l.fstart AS start, l.fend AS end, fl.feature_id, ppSitePattern.value AS site_pattern, ppPositionShift.value AS position_shift, ".
	" ppOldStart.value AS old_start, ppOldPosition.value AS old_position, COUNT(*) OVER() AS total, pp2.value AS new_start  ";

#	if ( $hash->{'RBSpattern'} !~ /^\s*$/ ) {
#		$select .= " AS site_pattern";
#	}
#	elsif ( $hash->{'RBSnewcodon'} !~ /^\s*$/ ) {
#		$select .= " AS old_start";
#	}
#	else {
#		$select .= " AS position_shift";
#	}
	my $join = " from feature_relationship r
                join featureloc lc on (r.subject_id = lc.feature_id) 
                join feature fl on (fl.feature_id = lc.srcfeature_id) 
                join cvterm c on (r.type_id = c.cvterm_id)
                join featureloc l on (r.subject_id = l.feature_id)
                join analysisfeature af on (af.feature_id = r.object_id)
                join analysis a on (a.analysis_id = af.analysis_id)
                join featureprop p on (p.feature_id = l.srcfeature_id)
                join cvterm cp on (p.type_id = cp.cvterm_id)
                join featureprop ppSitePattern on (ppSitePattern.feature_id = r.subject_id)
                join cvterm cppSitePattern on (ppSitePattern.type_id = cppSitePattern.cvterm_id) 
                join featureprop ppOldStart on (ppOldStart.feature_id = r.subject_id)
                join cvterm cppOldStart on (ppOldStart.type_id = cppOldStart.cvterm_id)
                join featureprop ppPositionShift on (ppPositionShift.feature_id = r.subject_id)
                join cvterm cppPositionShift on (ppPositionShift.type_id = cppPositionShift.cvterm_id) 
                join featureprop pp2 on (pp2.feature_id = r.subject_id) 
                join cvterm cpp2 on (pp2.type_id = cpp2.cvterm_id) 
                join featureprop ppOldPosition on (ppOldPosition.feature_id = r.subject_id)
                join cvterm cppOldPosition on (ppOldPosition.type_id = cppOldPosition.cvterm_id) ";
	my $query =
"where c.name='interval' and a.program = 'annotation_rbsfinder.pl' and cp.name='pipeline_id' and p.value=? ".
" and cppSitePattern.name='RBS_pattern' and cppOldStart.name='old_start_codon' and cppPositionShift.name='position_shift'  and cpp2.name='new_start_codon' and cppOldPosition.name='old_position' ";
	push @args, $hash->{pipeline};
	
	if(exists $hash->{contig} && $hash->{contig}) {
		$query .= " and l.srcfeature_id = ? ";
		push @args, $hash->{contig};
	}

	if ( $hash->{'RBSpattern'} !~ /^\s*$/ ) {
		$hash->{'RBSpattern'} =~ s/\s*//g;
		$query .= " and lower(ppSitePattern.value) like ? ";
		push @args, lc( "%" . $hash->{'RBSpattern'} . "%" );
	}
	elsif ( $hash->{'RBSshift'} ) {
		if ( $hash->{'RBSshiftM'} eq "both" ) {
			$query .= " and ppPositionShift.value != '0'";
		}
		elsif ( $hash->{'RBSshiftM'} eq "neg" ) {
			$query .=
			  " and my_to_decimal(ppPositionShift.value) < '0'";
		}
		elsif ( $hash->{'RBSshiftM'} eq "pos" ) {
			$query .=
			  " and my_to_decimal(ppPositionShift.value) >= '0'";
		}
	}
	elsif ( $hash->{'RBSnewcodon'} ) {
		$query .= " and (ppOldStart.value != pp2.value) ";
	}

	$query = $select . $join . $query;
	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$query .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$query .= " OFFSET 0 ";
		}
		else {
			$query .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my @list = ();
	my %hash = ();
	my @columns = @{ $sth->{NAME} };
	use Report_HTML_DB::Models::Application::RBSSearch;
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my $result = Report_HTML_DB::Models::Application::RBSSearch->new(
			contig 			=> $rows[$i][0],
			start  			=> $rows[$i][2],
			end    			=> $rows[$i][1],
			feature_id 		=> $rows[$i][3],
			site_pattern	=> $rows[$i][4],
			position_shift	=> $rows[$i][5],
			old_start		=> $rows[$i][6],
            old_position    => $rows[$i][7]
		);

		if ( $columns[9] eq "new_start" ) {
			$result->setNewStart( $rows[$i][9] );
		}
		$hash{total} = $rows[$i][8];
		push @list, $result;
	}
	$hash{list} = \@list;
	return \%hash;
}

=head2

Method used to return horizontal transferences data from database

=cut

sub alienhunter_search {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $select =
"select r.object_id AS id, fl.uniquename AS contig, l.fstart AS start, l.fend AS end, ppLength.value AS length, ppScore.value AS score, ppThreshold.value AS threshold, fl.feature_id, COUNT(*) OVER() AS total ";

	my $join = " from feature_relationship r
                join featureloc lc on (r.subject_id = lc.feature_id) 
                join feature fl on (fl.feature_id = lc.srcfeature_id) 
                join cvterm c on (r.type_id = c.cvterm_id) 
                join featureloc l on (r.subject_id = l.feature_id) 
                join analysisfeature af on (af.feature_id = r.object_id) 
                join analysis a on (a.analysis_id = af.analysis_id) 
                join featureprop p on (p.feature_id = l.srcfeature_id) 
                join cvterm cp on (p.type_id = cp.cvterm_id) 
                join featureprop ppLength on (ppLength.feature_id = r.subject_id) 
                join cvterm cppLength on (ppLength.type_id = cppLength.cvterm_id) 
                join featureprop ppScore on (ppScore.feature_id = r.subject_id) 
                join cvterm cppScore on (ppScore.type_id = cppScore.cvterm_id) 
                join featureprop ppThreshold on (ppThreshold.feature_id = r.subject_id) 
                join cvterm cppThreshold on (ppThreshold.type_id = cppThreshold.cvterm_id) ";
	my $query =
"where c.name='interval' and a.program = 'annotation_alienhunter.pl' and cp.name='pipeline_id' and p.value=? and cppLength.name = 'length' and cppScore.name = 'score' and cppThreshold.name = 'threshold' ";
	push @args, $hash->{pipeline};
	
	if(exists $hash->{contig} && $hash->{contig}) {
		$query .= " and l.srcfeature_id = ? ";
		push @args, $hash->{contig};
	}

	my $search_field;
	my $field;
	my $modifier;

	if ( $hash->{'AHlen'} !~ /^\s*$/ ) {
		$search_field = $hash->{'AHlen'} + 1;
		$modifier     = $hash->{'AHlenM'};
		$field		  = "ppLength";
	}
	elsif ( $hash->{'AHscore'} !~ /^\s*$/ ) {
		$search_field = $hash->{'AHscore'} + 1;
		$modifier     = $hash->{'AHscM'};
		$field		  = "ppScore";
	}
	elsif ( $hash->{'AHthr'} !~ /^\s*$/ ) {
		$search_field = $hash->{'AHthr'} + 1;
		$modifier     = $hash->{'AHthrM'};
		$field		  = "ppThreshold";
	}

	$search_field =~ s/\s+//g;

	if ( $modifier eq "exact" ) {
		$query .= " and my_to_decimal($field.value) = ? ";
	}
	elsif ( $modifier eq "orLess" ) {
		$query .= " and my_to_decimal($field.value) <= ? ";
	}
	elsif ( $modifier eq "orMore" ) {
		$query .= " and my_to_decimal($field.value) >= ? ";
	}

	push @args, ($search_field - 1) if $search_field;

	$query = $select . $join . $query;
	
	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$query .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$query .= " OFFSET 0 ";
		}
		else {
			$query .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my @list = ();
	my %hash = ();
	my @columns = @{ $sth->{NAME} };
	use Report_HTML_DB::Models::Application::AlienHunterSearch;
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my $result = Report_HTML_DB::Models::Application::AlienHunterSearch->new(
			id     		=> $rows[$i][0],
			contig 		=> $rows[$i][1],
			start  		=> $rows[$i][2],
			end    		=> $rows[$i][3],
			length 		=> $rows[$i][4],
			score  		=> $rows[$i][5],
			threshold 	=> $rows[$i][6],
			feature_id	=> $rows[$i][7],
		);

		$hash{total} = $rows[$i][8];
		push @list, $result;
	}
	$hash{list} = \@list;
	return \%hash;
}

=head2

Method used to return the reverse complement

=cut

sub reverseComplement {
	my ($sequence) = @_;
	my $reverseComplement = reverse($sequence);
	$reverseComplement =~ tr/ACGTacgt/TGCAtgca/;
	return $reverseComplement;
}

=head2

Method used to realize search by feature

=cut

sub searchGene {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query =
"SELECT me.feature_id AS feature_id, feature_relationship_props_subject_feature.value AS name, feature_relationship_props_subject_feature_2.value AS uniquename, "
	  . "featureloc_features_2.fstart AS fstart, featureloc_features_2.fend AS fend, featureprops_2.value AS type,  COUNT(*) OVER() AS total "
	  . "FROM feature me "
	  . "LEFT JOIN feature_relationship feature_relationship_objects_2 ON feature_relationship_objects_2.object_id = me.feature_id "
	  . "LEFT JOIN featureprop feature_relationship_props_subject_feature ON feature_relationship_props_subject_feature.feature_id = feature_relationship_objects_2.subject_id "
	  . "LEFT JOIN cvterm type ON type.cvterm_id = feature_relationship_props_subject_feature.type_id "
	  . "LEFT JOIN cvterm type_2 ON type_2.cvterm_id = feature_relationship_objects_2.type_id "
	  . "LEFT JOIN featureloc featureloc_features_2 ON featureloc_features_2.feature_id = me.feature_id "
	  . "LEFT JOIN featureprop featureloc_featureprop ON featureloc_featureprop.feature_id = featureloc_features_2.srcfeature_id "
	  . "LEFT JOIN cvterm type_3 ON type_3.cvterm_id = featureloc_featureprop.type_id "
	  . "LEFT JOIN feature_relationship feature_relationship_objects_4 ON feature_relationship_objects_4.object_id = me.feature_id "
	  . "LEFT JOIN featureprop feature_relationship_props_subject_feature_2 ON feature_relationship_props_subject_feature_2.feature_id = feature_relationship_objects_4.subject_id "
	  . "LEFT JOIN cvterm type_4 ON type_4.cvterm_id = feature_relationship_props_subject_feature_2.type_id "
	  . "LEFT JOIN featureprop featureprops_2 ON featureprops_2.feature_id = me.feature_id "
	  . "LEFT JOIN cvterm type_5 ON type_5.cvterm_id = featureprops_2.type_id ";
	my $where =
"WHERE type.name = 'locus_tag' AND type_2.name = 'based_on' AND type_3.name = 'pipeline_id' AND type_4.name = 'description' AND type_5.name = 'tag' AND featureloc_featureprop.value = ? ";
	push @args, $hash->{pipeline};
	
	if(exists $hash->{contig} && $hash->{contig}) {
		$where .= " AND featureloc_features_2.srcfeature_id = ? ";
		push @args, $hash->{contig};
	}

	my $connector = "";
	if ( exists $hash->{featureId} && $hash->{featureId} ) {
		if ( index( $hash->{featureId}, " " ) != -1 ) {
			$where .= " AND (";
			while ( $hash->{featureId} =~ /(\d+)+/g ) {
				$connector = " OR " if $connector;
				$where .= $connector . "me.feature_id = ? ";
				push @args, $1;
				$connector = "1";
			}
			$where .= ")";
		}
		else {

			$where .= " AND me.feature_id = ? ";
			push @args, $hash->{featureId};
			$connector = "1";
		}
	}

	if (   ( exists $hash->{geneDescription} && $hash->{geneDescription} )
		or ( exists $hash->{noDescription} && $hash->{noDescription} ) )
	{
		$connector = " AND " if $connector;
		$where .= $connector;
		my @likesDescription   = ();
		my @likesNoDescription = ();
		if ( $hash->{geneDescription} ) {
			while ( $hash->{geneDescription} =~ /(\S+)/g ) {
				push @likesDescription,
				  generate_clause( "?", "", "",
					"lower(feature_relationship_props_subject_feature_2.value)"
				  );
				push @args, lc( "%" . $1 . "%" );
			}
		}
		if ( $hash->{noDescription} ) {
			while ( $hash->{noDescription} =~ /(\S+)/g ) {
				push @likesNoDescription,
				  generate_clause( "?", "NOT", "",
					"lower(feature_relationship_props_subject_feature_2.value)"
				  );
				push @args, lc( "%" . $1 . "%" );
			}
		}

		if (    exists $hash->{individually}
			and $hash->{individually}
			and scalar(@likesDescription) > 0 )
		{
			if ( scalar(@likesNoDescription) > 0 ) {
				foreach my $like (@likesDescription) {
					$where .= " AND " . $like;
				}
				foreach my $notLike (@likesNoDescription) {
					$where .= " AND " . $notLike;
				}
			}
			else {
				foreach my $like (@likesDescription) {
					$where .= " AND " . $like;
				}
			}
		}
		elsif ( scalar(@likesDescription) > 0 ) {
			my $and = "";
			if ( scalar(@likesNoDescription) > 0 ) {
				foreach my $notLike (@likesNoDescription) {
					$where .= " AND " . $notLike;
				}
				$and = "1";
			}
			if ($and) {
				$and = " AND ";
			}
			else {
				$and = " OR ";
			}
			$where .= " AND (";
			my $counter = 0;
			foreach my $like (@likesDescription) {
				if ( $counter == 0 ) {
					$where .= $like;
					$counter++;
				}
				else {
					$where .= $and . $like;
				}
			}
			$where .= " ) ";
		}
		elsif ( scalar(@likesDescription) <= 0
			and scalar(@likesNoDescription) > 0 )
		{
			foreach my $like (@likesNoDescription) {
				$where .= " AND " . $like;
			}
		}
	}

	if ( exists $hash->{geneID} && $hash->{geneID} ) {
		$where .=
" AND lower(feature_relationship_props_subject_feature.value) LIKE ? ";
		push @args, lc( "%" . $hash->{geneID} . "%" );
	}
	
	$where .= " ORDER BY feature_relationship_props_subject_feature.value ASC ";

	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$where .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$where .= " OFFSET 0 ";
		}
		else {
			$where .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}
	
	$query .= $where;

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my %returnedHash = ();
	my @list         = ();

	use Report_HTML_DB::Models::Application::Feature;
	for ( my $i = 0; $i < scalar @rows ; $i++ ) {
		my $feature;
		if($rows[$i][5] eq "CDS") {	
			my %hashBlast = ();
			$hashBlast{pipeline_id} = $hash->{pipeline};
			$hashBlast{feature_id} = $rows[$i][0];
			my $identifierDescriptionHash = getIdentifierAndDescriptionSimilarity($self, getFirstBlastResult($self, \%hashBlast)->{feature_id});
			my $uniquename =($identifierDescriptionHash->{description} ? $identifierDescriptionHash->{description} : $rows[$i][2]) ;
			$uniquename =~ s/\w+\_*\.+\w\s//g;
			$uniquename =~ s/\w*_[\w\d]*//g;
			$feature = Report_HTML_DB::Models::Application::Feature->new(
				feature_id => $rows[$i][0],
				uniquename => $uniquename, 
				name       => $rows[$i][1],
				fstart     => $rows[$i][3],
				fend       => $rows[$i][4],
				type       => $rows[$i][5],
			);
		} else {
			my $uniquename = $rows[$i][2];
			$uniquename =~ s/\w+\_*\.+\w\s//g;
			$uniquename =~ s/\w*_[\w\d]*//g;


			$feature = Report_HTML_DB::Models::Application::Feature->new(
				feature_id => $rows[$i][0],
				uniquename => $uniquename,
				name       => $rows[$i][1],
				fstart     => $rows[$i][3],
				fend       => $rows[$i][4],
				type       => $rows[$i][5],
			);
		}
		$returnedHash{total} = $rows[$i][6];
		push @list, $feature;
	}

	$returnedHash{list} = \@list;

	return \%returnedHash;
}

sub getFirstBlastResult {
	my ($self, $hash) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query = "SELECT DISTINCT f.feature_id
FROM feature f
JOIN feature_relationship r ON (r.subject_id = f.feature_id)
JOIN feature fo ON (r.object_id = fo.feature_id)
JOIN analysisfeature af ON (f.feature_id = af.feature_id)
JOIN analysis a ON (a.analysis_id = af.analysis_id)
JOIN analysisprop ap ON (ap.analysis_id = a.analysis_id)
JOIN featureloc l ON (r.object_id = l.feature_id)
JOIN featureprop p ON (p.feature_id = srcfeature_id)
JOIN cvterm c ON (p.type_id = c.cvterm_id)
JOIN feature_relationship ra ON (ra.object_id = f.feature_id)
JOIN cvterm cra ON (ra.type_id = cra.cvterm_id)
JOIN featureprop pfo ON (ra.subject_id = pfo.feature_id)
JOIN cvterm cpfo ON (cpfo.cvterm_id = pfo.type_id)
JOIN featureprop pr ON (r.object_id = pr.feature_id)
JOIN cvterm cpr ON (pr.type_id = cpr.cvterm_id)

WHERE a.program = 'annotation_blast.pl'
  AND c.name ='pipeline_id'
  AND p.value = ?
  AND cra.name = 'alignment'
  AND cpfo.name = 'subject_id'
  AND r.object_id = ?
  AND ap.value LIKE '%database_code=INSD%' LIMIT 1";

	push @args, $hash->{pipeline_id};
	push @args, $hash->{feature_id};
	my $sth = $dbh->prepare($query);
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };

	my %hash  = ();
	$hash{feature_id} = $rows[0][0];

	return \%hash;
}

=head2

Method used to realize search for basic content of any feature
=cut

sub geneBasics {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query = "
	SELECT srcfeature.feature_id AS feature_id, feature_relationship_props_subject_feature.value AS name, srcfeature.uniquename AS uniquename, 
	featureloc_features_2.fstart AS	fstart, featureloc_features_2.fend AS fend, featureprops_2.value AS value, a.program
	FROM feature me
	LEFT JOIN feature_relationship feature_relationship_objects_2 ON feature_relationship_objects_2.object_id = me.feature_id    
	LEFT JOIN featureprop feature_relationship_props_subject_feature ON feature_relationship_props_subject_feature.feature_id = feature_relationship_objects_2.subject_id
	LEFT JOIN cvterm type ON type.cvterm_id = feature_relationship_props_subject_feature.type_id
	LEFT JOIN cvterm type_2 ON type_2.cvterm_id = feature_relationship_objects_2.type_id
	LEFT JOIN featureprop featureprops_2 ON featureprops_2.feature_id = me.feature_id
	LEFT JOIN cvterm type_3 ON type_3.cvterm_id = featureprops_2.type_id
	LEFT JOIN featureloc featureloc_features_2 ON featureloc_features_2.feature_id = me.feature_id
	LEFT JOIN feature srcfeature ON srcfeature.feature_id = featureloc_features_2.srcfeature_id
	LEFT JOIN featureprop featureloc_featureprop ON featureloc_featureprop.feature_id = featureloc_features_2.srcfeature_id
	LEFT JOIN cvterm type_4 ON type_4.cvterm_id = featureloc_featureprop.type_id 
	LEFT JOIN feature_relationship feature_relationship_objects_4 ON feature_relationship_objects_4.object_id = me.feature_id
	LEFT JOIN featureprop feature_relationship_props_subject_feature_2 ON feature_relationship_props_subject_feature_2.feature_id = feature_relationship_objects_4.subject_id
	LEFT JOIN cvterm type_5 ON type_5.cvterm_id = feature_relationship_props_subject_feature_2.type_id
	LEFT JOIN analysisfeature af ON (af.feature_id = me.feature_id)
	LEFT JOIN analysis_relationship ar ON (ar.object_id = af.analysis_id)
	LEFT JOIN analysis a ON (a.analysis_id = ar.subject_id)
	WHERE ( ( featureloc_featureprop.value = ? AND me.feature_id = ? AND type.name =
		'locus_tag' AND type_2.name = 'based_on' AND type_3.name = 'tag' AND
		type_4.name = 'pipeline_id' AND type_5.name = 'description' ) )
	GROUP BY srcfeature.feature_id,
		feature_relationship_props_subject_feature.value,
		feature_relationship_props_subject_feature_2.value,
		featureloc_features_2.fstart, featureloc_features_2.fend,
		featureprops_2.value, a.program ";
	push @args, $hash->{pipeline};
	push @args, $hash->{feature_id};
	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my @list = ();

	use Report_HTML_DB::Models::Application::Feature;
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my $feature = Report_HTML_DB::Models::Application::Feature->new(
			feature_id => $rows[$i][0],
			name       => $rows[$i][1],
			uniquename => $rows[$i][2],
			fstart     => $rows[$i][3],
			fend       => $rows[$i][4],
			type       => $rows[$i][5],
			predictor  => $rows[$i][6]
		);
		push @list, $feature;
	}

	return \@list;
}

=head2

Method used to get gene by position

=cut

sub geneByPosition {
	my ( $self, $hash ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query =
	    "SELECT me.feature_id AS feature_id, COUNT(*) OVER() AS total "
	  . "FROM feature me "
	  . "LEFT JOIN feature_relationship feature_relationship_objects_2 ON feature_relationship_objects_2.object_id = me.feature_id "
	  . "LEFT JOIN featureprop feature_relationship_props_subject_feature ON feature_relationship_props_subject_feature.feature_id = feature_relationship_objects_2.subject_id "
	  . "LEFT JOIN cvterm type ON type.cvterm_id = feature_relationship_props_subject_feature.type_id "
	  . "LEFT JOIN cvterm type_2 ON type_2.cvterm_id = feature_relationship_objects_2.type_id "
	  . "LEFT JOIN featureprop featureprops_2 ON featureprops_2.feature_id = me.feature_id "
	  . "LEFT JOIN cvterm type_3 ON type_3.cvterm_id = featureprops_2.type_id "
	  . "LEFT JOIN featureloc featureloc_features_2 ON featureloc_features_2.feature_id = me.feature_id "
	  . "LEFT JOIN feature srcfeature ON srcfeature.feature_id = featureloc_features_2.srcfeature_id "
	  . "LEFT JOIN featureprop featureloc_featureprop ON featureloc_featureprop.feature_id = featureloc_features_2.srcfeature_id "
	  . "LEFT JOIN cvterm type_4 ON type_4.cvterm_id = featureloc_featureprop.type_id "
	  . "WHERE ( ( featureloc_featureprop.value = ? AND featureloc_features_2.fstart >= ? AND featureloc_features_2.fend <= ? AND featureloc_features_2.srcfeature_id = ? AND type.name = 'locus_tag' AND type_2.name = 'based_on' AND type_3.name = 'tag' AND type_4.name = 'pipeline_id' ) ) "
	  . "GROUP BY me.feature_id, featureloc_features_2.fstart, featureloc_features_2.fend, featureprops_2.value, srcfeature.uniquename, srcfeature.feature_id "
	  . "ORDER BY MIN( feature_relationship_props_subject_feature.value )";
	push @args, $hash->{pipeline};
	push @args, $hash->{start};
	push @args, $hash->{end};
	push @args, $hash->{contig};

	if (   exists $hash->{pageSize}
		&& $hash->{pageSize}
		&& exists $hash->{offset}
		&& $hash->{offset} )
	{
		$query .= " LIMIT ? ";
		push @args, $hash->{pageSize};
		if ( $hash->{offset} == 1 ) {
			$query .= " OFFSET 0 ";
		}
		else {
			$query .= " OFFSET ? ";
			push @args, $hash->{offset};
		}
	}
	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };
	my %hash = ();
	my @list = ();

	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		push @list, $rows[$i][0];
		$hash{total} = $rows[$i][1];
	}
	
	$hash{list} = \@list;

	return \%hash;
}

=head2

Method used to realize search for description of non coding RNA

=cut

sub ncRNA_description {
	my ( $self, $feature_id, $pipeline ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query =
"SELECT me.object_id AS object_id, feature_relationship_props_subject_feature_2.value AS value "
	  . "FROM feature_relationship me  "
	  . "JOIN cvterm type ON type.cvterm_id = me.type_id "
	  . "LEFT JOIN analysisfeature feature_relationship_analysis_feature_feature_object_2 ON feature_relationship_analysis_feature_feature_object_2.feature_id = me.object_id "
	  . "LEFT JOIN analysis analysis ON analysis.analysis_id = feature_relationship_analysis_feature_feature_object_2.analysis_id "
	  . "LEFT JOIN featureloc feature_relationship_featureloc_subject_feature_2 ON feature_relationship_featureloc_subject_feature_2.feature_id = me.subject_id "
	  . "LEFT JOIN featureprop featureloc_featureprop ON featureloc_featureprop.feature_id = feature_relationship_featureloc_subject_feature_2.srcfeature_id "
	  . "LEFT JOIN cvterm type_2 ON type_2.cvterm_id = featureloc_featureprop.type_id "
	  . "LEFT JOIN featureprop feature_relationship_props_subject_feature_2 ON feature_relationship_props_subject_feature_2.feature_id = me.subject_id "
	  . "LEFT JOIN cvterm type_3 ON type_3.cvterm_id = feature_relationship_props_subject_feature_2.type_id "
	  . "WHERE ( ( analysis.program = 'annotation_infernal.pl' AND featureloc_featureprop.value = ? AND me.object_id = ? AND type.name = 'interval' AND type_2.name = 'pipeline_id' AND type_3.name = 'target_description' ) ) "
	  . "GROUP BY me.object_id, feature_relationship_props_subject_feature_2.value "
	  . "ORDER BY feature_relationship_props_subject_feature_2.value ASC";
	push @args, $pipeline;
	push @args, $feature_id;
	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows    = @{ $sth->fetchall_arrayref() };
	my %hash    = ();
	my @columns = @{ $sth->{NAME} };

	for ( my $i = 0 ; $i < scalar @columns ; $i++ ) {
		$hash{ $columns[$i] } = $rows[0][$i];
	}

	return \%hash;
}

=head2

Method used to realize search by subevidences

=cut

sub subevidences {
	my ( $self, $feature_id ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query =
"SELECT subev_id, subev_type, subev_number, subev_start, subev_end, subev_strand, is_obsolete, program FROM get_subevidences(?) ORDER BY subev_id ASC";
	push @args, $feature_id;

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };

	my %component_name = (
		'annotation_interpro.pl' => 'Domain search - InterProScan',
		'annotation_blast.pl'    => 'Similarity search - BLAST',
		'annotation_rpsblast.pl' => 'Similarity search - RPS-BLAST',
		'annotation_phobius.pl' =>
		  'Transmembrane domains and signal peptide search - Phobius',
		'annotation_pathways.pl'  => 'Pathway classification - KEGG',
		'annotation_orthology.pl' => 'Orthology assignment - eggNOG',
		'annotation_tcdb.pl'      => 'Transporter classification - TCDB',
		'annotation_dgpi.pl'      => 'GPI anchor - DGPI',
		'annotation_predgpi.pl'	=> 'PreDGPI',
		'annotation_tmhmm.pl'     => 'TMHMM',
		'annotation_hmmer.pl'	=> 'HMMER',
		"annotation_signalP.pl" => 'SignalP',
		'annotation_bigpi.pl'   => 'BIGPI',
	);

	my @list = ();
	use Report_HTML_DB::Models::Application::Subevidence;
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my $subevidence = Report_HTML_DB::Models::Application::Subevidence->new(
			id                  => $rows[$i][0],
			type                => $rows[$i][1],
			number              => $rows[$i][2],
			start               => $rows[$i][3],
			end                 => $rows[$i][4],
			strand              => $rows[$i][5],
			is_obsolete         => $rows[$i][6],
			program             => $rows[$i][7],
			program_description => $component_name{ $rows[$i][7] }
		);
		push @list, $subevidence;
	}

	return \@list;
}

=head2

Method used to realize search by interval evidence properties

=cut

sub intervalEvidenceProperties {
	my ( $self, $feature_id ) = @_;
	my $dbh = $self->dbh;

	my $query =
	  "select c.name, p.value, l.fstart, l.fend 
	  from featureprop p 
	  join cvterm c on (p.type_id = c.cvterm_id) 
	  join feature_relationship r on (r.subject_id = p.feature_id) 
	  join cvterm cr on (r.type_id = cr.cvterm_id) 
	  join featureloc l on (r.subject_id = l.feature_id)
	  where cr.name='interval' and r.object_id=? ORDER BY r.subject_id ASC;";

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute($feature_id);
	my @rows = @{ $sth->fetchall_arrayref() };

	my @list = ();
	my %property = ();
	
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my %hash = ();
		
		$hash{ key } = $rows[$i][0];
		$hash{ key_value } = $rows[$i][1];
		$hash{ fstart } = $rows[$i][2];
		$hash{ fend } = $rows[$i][3];
		
		if ( !exists $property{ $hash{key} } ) {
			if ( $hash{key} eq "anticodon" ) {
				$property{ $hash{key} } = $hash{key_value};
				$property{codon} = reverseComplement( $hash{key_value} );
			}
			else {
				$property{ $hash{key} } = $hash{key_value};
			}
			$property{ fstart } = $hash{fstart};
			$property{ fend } = $hash{fend};
		}
		else {
			my %tempHash = ();
			foreach my $key ( keys %property ) {
				if ( defined $key && $key ) {
					$tempHash{$key} = $property{$key};
				}
			}
			push @list, \%tempHash;
			%property = ();
			if ( $hash{key} eq "anticodon" ) {
				$property{ $hash{key} } = $hash{key_value};
				$property{codon} = reverseComplement( $hash{key_value} );
			}
			else {
				$property{ $hash{key} } = $hash{key_value};
			}
			$property{ fstart } = $hash{fstart};
			$property{ fend } = $hash{fend};
		}
	}
	push @list, \%property if scalar @list == 0;

	return \@list;
}

=head2

Method used to realize search by similarity evidence properties

=cut

sub similarityEvidenceProperties {
	my ( $self, $feature_id ) = @_;
	my $dbh = $self->dbh;

	my $query =
	  "SELECT key, key_value FROM get_similarity_evidence_properties(?)";

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute($feature_id);
	my @rows = @{ $sth->fetchall_arrayref() };

	my @list    = ();
	my @columns = @{ $sth->{NAME} };

	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		my %hash = ();
		for ( my $j = 0 ; $j < scalar @columns ; $j++ ) {
			$hash{ $columns[$j] } = $rows[$i][$j];
		}
		push @list, \%hash;
	}
	my %returnedhash = ();
	for ( my $i = 0 ; $i < scalar @list ; $i++ ) {
		my $result = $list[$i];
		if ( $result->{key} eq "anticodon" ) {
			$returnedhash{ $result->{key} } = $result->{key_value};
			$returnedhash{codon} = reverseComplement( $result->{key_value} );
		}
		else {
			$returnedhash{ $result->{key} } = $result->{key_value};
		}
	}
	$returnedhash{id} = $feature_id;

	return \%returnedhash;

}

=head2

Method used to get identifier and description of similarity

=cut

sub getIdentifierAndDescriptionSimilarity {
	my ($self, $feature_id) = @_;
	my $dbh = $self->dbh;

	my $query =
	  "select p.value from feature_relationship r 
join feature q on (r.subject_id = q.feature_id)         
join featureprop p on (p.feature_id = r.subject_id)
join cvterm c on (p.type_id = c.cvterm_id)
join cvterm cr on (r.type_id = cr.cvterm_id)
join cvterm cq on (q.type_id = cq.cvterm_id)
where cr.name='alignment' 
and cq.name='subject_sequence' and c.name='subject_id' and r.object_id=? ";

	my $sth = $dbh->prepare($query);
	print STDERR $query;

	$sth->execute($feature_id);
	my @rows = @{ $sth->fetchall_arrayref() };

	my %hash = ();
	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {

		my $response = $rows[$i][0];
		my @values = ();
		if ($response =~ /\|/g) {
			if ($response =~ /CDD/g) {
				$response =~ /\|\w+\|(\d*)([\w\ ;.,]*)/g;
				while ($response =~ /\|\w+\|(\d*)([\w\ ;.,]*)/g) {
					push @values, $1;
					push @values, $2;
				}
			}  else {
				while ($response =~ /(?:\w+)\|(\w+\.*\w*)\|([\w\ \:\[\]\<\>\.\-\+\*\(\)\&\\%\$\#\@\!\/]*)$/g) {
					push @values, $1;
					push @values, $2;
				}
			} 
		} else {
			while ($response =~ /(\w+)([\w\s]*)/g) {
				push @values, $1;
				push @values, $2;
			}
		}
		$hash{identifier} = $values[0];
		$hash{description} = $values[1];

	}
	return \%hash;
}

=head2

Method used to get feature ID by uniquename

=cut

sub get_feature_id {
	my ( $self, $uniquename ) = @_;
	my $dbh = $self->dbh;

	my $query = "SELECT feature_id FROM feature WHERE uniquename = ? LIMIT 1";

	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute($uniquename);
	my @rows = @{ $sth->fetchall_arrayref() };

	return $rows[0][0];
}

=head2

Method used to get target class

=cut

sub get_target_class {
	my ( $self, $pipeline_id ) = @_;
	my $dbh  = $self->dbh;
	my @args = ();
	my $query =
"select DISTINCT ppc.value as value 
	from feature_relationship r 
	join featureloc l on (r.subject_id = l.feature_id) 
	join featureprop p on (p.feature_id = l.srcfeature_id) 
	join cvterm cp on (p.type_id = cp.cvterm_id) 
	join featureprop ppc on (ppc.feature_id = r.subject_id) 
	join cvterm cppc on (ppc.type_id = cppc.cvterm_id) 
	WHERE cppc.name= 'target_class' and cp.name='pipeline_id' and p.value=?";
	push @args, $pipeline_id;
	my $sth = $dbh->prepare($query);
	print STDERR $query;
	$sth->execute(@args);
	my @rows = @{ $sth->fetchall_arrayref() };

	my @list = ();

	for ( my $i = 0 ; $i < scalar @rows ; $i++ ) {
		push @list, $rows[$i][0];
	}

	return \@list;
}

=head1 NAME

services::Model::SearchDatabaseRepository - DBI Model Class

=head1 SYNOPSIS

See L<HTML_DIR>

=head1 DESCRIPTION

DBI Model Class.

=head1 AUTHOR

Wendel Hime L. Castro,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

