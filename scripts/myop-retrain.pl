#!/usr/bin/perl

use File::Basename;
use strict;
use warnings;
use Getopt::Long;

my $directory;
my $ncpu = 1;
my $verbose;

GetOptions("cpu=i" => \$ncpu,
           "directory=s" => \$directory,
           "verbose" => \$verbose);
my $witherror = 0;
if (! defined ($directory)){
  $witherror = 1;
  print STDERR "ERROR: missing output directory !\n";
}
if( $witherror) {
  print STDERR "USAGE: " . basename($0) . "  -d <model directory> -c <number of cpu>\n";
  exit(-1);
}

opendir (MODEL, "$directory") or die "cant open  $directory: $!\n";
chdir(MODEL);
if ($verbose) {
  !system ("myop-setup -v -c $ncpu") or die "cant train";
  !system ("myop-generate_training_set -v -c $ncpu") or die "cant train";
  !system ("myop-train_submodels -v -c $ncpu") or die "cant train";
  !system ("myop-build_ghmm -v") or die "cant train";
} else {
  !system ("myop-setup  -c $ncpu") or die "cant train";
  !system ("myop-generate_training_set  -c $ncpu") or die "cant train";
  !system ("myop-train_submodels  -c $ncpu") or die "cant train";
  !system ("myop-build_ghmm ") or die "cant train";
}
closedir(MODEL);

