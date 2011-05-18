#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;
use File::Copy;

my $branch = "master";
my $repository;
my $gtf ;
my $fasta;
my $output_dir;
my $ncpu = 1;

GetOptions("cpu=i" => \$ncpu,
          "repository=s" => \$repository,
          "branch=s" => \$branch,
          "gtf=s" => \$gtf,
          "fasta=s" => \$fasta,
          "output_dir=s" => \$output_dir);
my $witherror = 0;
if( ! defined ($gtf)) {
  $witherror = 1;
  print STDERR "ERROR: missing gtf file name !\n";
}
if (! defined ($fasta)) {
  $witherror = 1;
  print STDERR "ERROR: missing fasta file name !\n";
}
if (! defined ($output_dir)){
  $witherror = 1;
  print STDERR "ERROR: missing output directory !\n";
}
if(! defined ($repository)){
  $witherror = 1;
  print STDERR "ERROR: missing repository location!\n";
}
if( $witherror) {
  print STDERR "USAGE: $0 -r <repository name> [-b <branch>] -g <gtf file> - f <fasta file> -c <number of cpu> -o <output directory>\n";
  exit(-1);
}

!system ("git clone $repository -b $branch $output_dir") or die "cant clone the repository !\n";
mkdir "$output_dir/dataset";
mkdir "$output_dir/ghmm";
mkdir "$output_dir/ghmm/cnf";
mkdir "$output_dir/ghmm/dataset";
mkdir "$output_dir/ghmm/model";
copy ($gtf, "$output_dir/dataset/train.gtf");
copy ($fasta, "$output_dir/dataset/train.fa");
opendir(GHMM, "$output_dir") or die "cant open directory $output_dir!\n";
chdir (GHMM);
system ("myop-retrain.pl -d . -c $ncpu");
closedir(GHMM);





