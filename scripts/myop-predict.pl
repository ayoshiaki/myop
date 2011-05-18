#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;
use Bio::SeqIO;

my $predictor;
my $fasta;
my $output_dir;
my $ncpu;
my $max_length = 500000;
my $overlap = 100000;

GetOptions("cpu=i" => \$ncpu,
           "predictor=s" => \$predictor,
           "fasta=s" => \$fasta,
           "max_length=i" => \$max_length,
           "overlap=i" => \$overlap,
           "output_dir=s" => \$output_dir);
my $witherror = 0;
if (! defined ($fasta)) {
  $witherror = 1;
  print STDERR "ERROR: missing fasta file name !\n";
}
if (! defined ($output_dir)){
  $witherror = 1;
  print STDERR "ERROR: missing output directory !\n";
}
if(! defined ($predictor)){
  $witherror = 1;
  print STDERR "ERROR: missing the predictor location!\n";
}
if( $witherror) {
  print STDERR "USAGE: $0 -p <predictor directory> -f <fasta file> [-c <number of cpu>] -o <output directory>\n";
  exit(-1);
}



my $in = Bio::SeqIO->new(-fh => \*STDIN, '-format' => 'Fasta');
my $pm = new Parallel::ForkManager($ncpu);
while (my $seq = $in->next_seq())
{
  $pm->start and next;
  if($seq->length() > $max_length) {
  }
  $pm->finish;
}
$pm->wait_all_children;

