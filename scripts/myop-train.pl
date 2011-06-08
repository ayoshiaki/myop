#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;
use File::Copy;
use Cwd 'abs_path';

my $branch ;
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

#
# validate the fasta file.
#
my $ids = `grep ">" $fasta`;
my %is_uniq;
my @all_ids = split (/\n/, $ids);
if(($#all_ids -1) < 0)  {
    print STDERR "ERROR: not a valid fasta file !\n";
    exit(-1);
}
foreach my $id ( @all_ids) {
  if(!($id =~ /^>/)){
    print STDERR "ERROR: not a valid fasta file !\n";
    print STDERR "ERROR: I have found this strange line: \"$id\"!\n";
    exit(-1);
  }
  if($id =~ /^>\s+/) {
    print STDERR "ERROR: your fasta contains a sequence with an empty identification\n";
    print STDERR "ERROR: try to remove the spaces that appears between '>' and the id: \"$id\"\n";
    exit(-1);
  }

  if($id =~ /^>\s*$/) {
    print STDERR "ERROR: your fasta contains a sequence with an empty identification\n";
    exit(-1);
  }
  if(defined $is_uniq{$id}) {
    print STDERR "ERROR: each sequence must have different identification, $id is duplicated\n";
    exit(-1);
  }
  $is_uniq{$id} = 1;
}


!system ("git clone $repository  $output_dir") or die "cant clone the repository !\n";
mkdir "$output_dir/dataset";
mkdir "$output_dir/ghmm";
mkdir "$output_dir/ghmm/cnf";
mkdir "$output_dir/ghmm/dataset";
mkdir "$output_dir/ghmm/model";




copy ($gtf, "$output_dir/dataset/train.gtf");
copy ($fasta, "$output_dir/dataset/train.fa");
if ((!$repository =~ m|://|) || (!defined $branch)) {
  $repository = abs_path("$repository");
  $branch = `cd $repository && git branch | grep "^*" | awk -F" " '{print \$2}'`;
}
opendir(GHMM, "$output_dir") or die "cant open directory $output_dir!\n";
chdir (GHMM);
!system ("git checkout $branch") or die "cant ccheckout $branch !\n";
system ("myop-retrain.pl -d . -c $ncpu");
closedir(GHMM);





