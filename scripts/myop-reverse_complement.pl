#!/usr/bin/perl

use File::Basename;
use strict;
use warnings;
use Getopt::Long;

use Bio::SeqIO;
my $threshold ;
GetOptions("threshold=i" => \$threshold);

my $in = Bio::SeqIO->new(-fh => \*STDIN, '-format' => 'Fasta');
my $out = Bio::SeqIO->new(-fh => \*STDOUT, '-format' => 'Fasta');

while (my $seq = $in -> next_seq())
{
  my  $reversed_obj = $seq->revcom;
  $out->write_seq($reversed_obj);

}
