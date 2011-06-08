#!/usr/bin/perl

use strict;
use warnings;

use GTF;
use Bio::SeqIO;
use Bio::DB::Fasta;
use Getopt::Long;
use File::Path;
use Bio::Seq;

# Mandatory arguments
my $fasta_filename;
my $gene_list_filename;
my $transcript_map_filename;
my $gtf_filename;
my $output_directory;

getopts();

# reading the data
my $db = Bio::DB::Fasta->new ("$fasta_filename");


my @geneNames;
open (GENES, "<$gene_list_filename") or die "$!";
while(<GENES>) {
    chomp;
    push @geneNames, $_;
}
close (GENES);

my %geneToTranscripts;
open (GENES, "<$transcript_map_filename") or die "$!";
while(<GENES>) {
    chomp;
    my ($name1, $name2) = split("\t", $_);
    push @{$geneToTranscripts{$name2}}, $name1;
}
close (GENES);

my $gtf = GTF::new({gtf_filename => $gtf_filename, 
		    warning_fh => \*STDERR});
my $genes = $gtf->genes;
my %geneIdToGene;
foreach my $gene (@{$genes}) {
  $geneIdToGene{$gene->gene_id()}{$gene->seqname()} = $gene;
}


mkpath("$output_directory");
foreach my $gname (@geneNames) {
    my %min;
    my %max;
    my %first;
    if(! defined $geneToTranscripts{$gname} ) {
	print STDERR "NOT FOUND: $gname\n";
    }
    foreach my $txname (@{$geneToTranscripts{$gname}})
      {
	foreach my $seqname (keys %{$geneIdToGene{$txname}}) 
	  {
	    if(!defined ($first{$seqname}) )
	      {
		$first{$seqname} = 1;
		my $gene = $geneIdToGene{$txname}{$seqname};
		my $min2 = 1e100;
		my $max2 = 0;
		foreach my $tx (@{$gene->{Transcripts}}) 
		  {
		    my $b = $tx->start();
		    my $e = $tx->stop() ;
		    if($b > $e) {
		      my $aux = $b;
		      $b = $e;
		      $e = $aux;
		    }
		    if($min2 > $b) {
		      $min2 = $b;
		    }
		    if($max2 < $e) {
		      $max2 = $e;
		    }
		  }
		$min{$seqname} = $min2;
		$max{$seqname} = $max2;
	      } else {
		my $gene = $geneIdToGene{$txname}{$seqname};
		my $min2 = 1e100;
		my $max2 = 0;
		foreach my $tx (@{$gene->{Transcripts}}) 
		  {
		    my $b = $tx->start();
		    my $e = $tx->stop() ;
		    if($b > $e) {
		      my $aux = $b;
		      $b = $e;
		      $e = $aux;
		    }
		    if($min2 > $b) {
		      $min2 = $b;
		    }
		    if($max2 < $e) {
		      $max2 = $e;
		    }
		  }
		if($min{$seqname} > $min2) {
		  $min{$seqname} = $min2;
		}
		if($max{$seqname} < $max2 ) {
		  $max{$seqname} = $max2;
		}
	      } 
	  }
      }
    foreach my $seqname (keys %min) 
      {
	$min{$seqname} -= 100;
	$max{$seqname} += 100;
      }
    
    foreach my $txname (@{$geneToTranscripts{$gname}})
      {
	foreach my $seqname (keys %{$geneIdToGene{$txname}}) 
	  {
	    if($min{$seqname} < 0) {
	      $min{$seqname} = 1;
	    }
	    my $loc = "$seqname:$min{$seqname}-$max{$seqname}";
	    mkpath($output_directory."/".$seqname);
            my $fname = $gname;
            $fname =~ s/\(/_/g;
            $fname =~ s/\)/_/g;
            $fname =~ s/:/_/g;
	    my $seq = $db->seq($loc);
	    if(defined $seq) {
	      open (FASTA, ">$output_directory/$seqname/$fname.fa");
	      print FASTA ">".$gname."\n".$seq."\n";
	      close(FASTA);
	    } else {
	      print STDERR "cant find sequence: $loc\n";
	    }

	    
	    my $gtf;
	    open ($gtf, ">>$output_directory/$seqname/$fname.gtf");
	    my $gene = $geneIdToGene{$txname}{$seqname};
	    $gene->offset(-$min{$seqname} + 1) ;
	    $gene->set_seqname($gname);
	    $gene->set_id($gname);
	    $gene->output_gtf($gtf);
	    close($gtf);
	}
    }
}


sub getopts {
    GetOptions("fasta=s" => \$fasta_filename, 
	       "list=s" => \$gene_list_filename,
	       "transcript_map=s" => \$transcript_map_filename,
	       "gtf=s" => \$gtf_filename,
	       "output=s" => \$output_directory);
    
    if(!defined ($fasta_filename)) {
	print STDERR "Missing fasta file ! \n";
	print STDERR "$0 -f <fasta>  -l <gene list> -o <output directory>\n";
	exit();
    }


    if(!defined ($gene_list_filename)) {
	print STDERR "A list of genes is  missing ! \n";
	print STDERR "$0 -f <fasta>   -s <gene list> -o <output directory>\n";
	exit();
    }

    if(!defined ($transcript_map_filename)) {
	print STDERR "A list of transcript is  missing ! \n";
	print STDERR "$0 -f <fasta>   -s <gene list> -o <output directory>\n";
	exit();
    }

    if(!defined ($gtf_filename)) {
	print STDERR "The gtf is missing ! \n";
	print STDERR "$0 -f <fasta> -s <gene list> -o <output directory>\n";
	exit();
    }


}


