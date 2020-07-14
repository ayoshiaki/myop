#!/usr/bin/perl

use File::Basename;
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;
use File::Copy qw(copy move);
use File::Path qw(rmtree remove_tree);
use Cwd 'abs_path';
use File::Basename 'dirname';

my $repository;
my $gtf ;
my $fasta;
my $output_dir;
my $ncpu = 1;
my $help;
my $verbose;
my $add;

GetOptions("cpu=i" => \$ncpu,
          "repository=s" => \$repository,
          "gtf=s" => \$gtf,
          "fasta=s" => \$fasta,
          "output_dir=s" => \$output_dir,
          "help" => \$help,
          "verbose" => \$verbose,
          "add=s" => \$add);

sub print_help {
  print STDERR "USAGE: " . basename($0) . "  [-r <repository name>] -g <gtf file> -f <fasta file> -o <output directory> [-c <number of cpu>]\n";
}

if ($help) {
  print_help();
  exit(-1);
}

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
  $repository = abs_path(dirname(abs_path($0)) . "/../template");
}

if( $witherror) {
  print_help();
  exit(-1);
}

#
# validate the fasta file.
#
my $ids = `grep ">" $fasta`;
my %is_uniq;
my @all_ids = split (/\n/, $ids);
if(scalar(@all_ids) < 0)  {
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

# validate gtf file

# my $validate_gtf = abs_path(dirname(abs_path($0)) . "/../lib/validate_gtf.pl");
# if ($verbose) {
#   system("perl -Mlib=" . dirname(abs_path($0)) ."/../lib " . "$validate_gtf $gtf $fasta") or die "invalid gtf file!";
# } else {
#   system("perl -Mlib=" . dirname(abs_path($0)) ."/../lib " . "$validate_gtf $gtf $fasta >/dev/null 2>&1") or die "invalid gtf file!";
# }

remove_tree ("${output_dir}_old");
move (${output_dir}, "${output_dir}_old");
# copy (${repository}, "${output_dir}") or die "cant create ${output_dir}";
!system ("cp -r $repository $output_dir") or die "cant create ${output_dir}";

mkdir "$output_dir/dataset";
mkdir "$output_dir/ghmm";
mkdir "$output_dir/ghmm/cnf";
mkdir "$output_dir/ghmm/dataset";
mkdir "$output_dir/ghmm/model";




copy ($gtf, "$output_dir/dataset/train.gtf");
copy ($fasta, "$output_dir/dataset/train.fa");
if ((!$repository =~ m|://|)) {
  $repository = abs_path("$repository");
}
opendir(GHMM, "$output_dir") or die "cant open directory $output_dir!\n";
chdir (GHMM);
if ($verbose) {
  system ("myop-retrain -v  -d . -c $ncpu");
} else {
  system ("myop-retrain  -d . -c $ncpu");
}
closedir(GHMM);

if ($add) {
  if ($add eq "genome") {
    !system ("myop-add-genome $output_dir") or die "cant add $output_dir"
  } elsif ($add eq "transcriptome") {
    !system ("myop-add-transcriptome $output_dir") or die "cant add $output_dir"
  }
}



