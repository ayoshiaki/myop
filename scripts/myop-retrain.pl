#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my $directory;
my $ncpu = 1;

GetOptions("cpu=i" => \$ncpu,
           "directory=s" => \$directory);
my $witherror = 0;
if (! defined ($directory)){
  $witherror = 1;
  print STDERR "ERROR: missing output directory !\n";
}
if( $witherror) {
  print STDERR "USAGE: $0 -d <model directory> -c <number of cpu>\n";
  exit(-1);
}

opendir (MODEL, "$directory") or die "cant open  $directory: $!\n";
chdir(MODEL);
system ("myop-setup.pl -c $ncpu");
system ("myop-generate_training_set.pl -c $ncpu");
system ("myop-train_submodels.pl -c $ncpu");
system ("myop-build_ghmm.pl");
closedir(MODEL);

