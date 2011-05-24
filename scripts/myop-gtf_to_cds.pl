#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;
use File::Copy;
use Bio::SeqIO;
use Bio::DB::Fasta;
use GTF;
my $gtf_file;
my $fasta;

GetOptions("gtf=s" => \$gtf_file,
          "fasta=s" => \$fasta);

my $witherror = 0;
if( ! defined ($gtf_file)) {
  $witherror = 1;
  print STDERR "ERROR: missing gtf file name !\n";
}
if (! defined ($fasta)) {
  $witherror = 1;
  print STDERR "ERROR: missing fasta file name !\n";
}
if( $witherror) {
  print STDERR "USAGE: $0 -g <gtf file> - f <fasta file>\n";
  exit(-1);
}

my $gtf = GTF::new({gtf_filename => $gtf_file,
                    warning_fh => \*STDERR});
my $genes = $gtf->genes;
my $db = Bio::DB::Fasta->new ("$fasta");
my $seqio = Bio::SeqIO->new ('-format' => 'Fasta', -fh => \*STDOUT);
foreach my $gene (@{$genes}) {
  my $source = $gene->seqname();

  foreach my $tx (@{$gene->transcripts()}) {
    my $seq = "";
    foreach my $cds (@{$tx->cds()}) {
      my $start  = $cds->start();
      my $stop = $cds->stop();
      my $x = $db->seq("$source:$start,$stop");
      $seq .= $x;
    }
    if ($gene->strand eq "-") {
      my $seqobj = Bio::PrimarySeq->new (-seq => $seq,
                                         -alphabet =>'dna',
                                         -id => "XX");
      $seqobj = $seqobj->revcom();
      $seq = $seqobj->seq();
    }
    my $seqobj = Bio::PrimarySeq->new (-seq => $seq,
                                       -alphabet =>'dna',
                                         -id => $gene->gene_id());

    $seqio->write_seq($seqobj);
  }
}











