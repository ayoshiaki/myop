#!/usr/bin/perl

use File::Basename;
use strict;
use warnings;
use Cwd            qw( abs_path );
use File::Basename qw( dirname );
use Getopt::Long;

my $ncpu = 1;
my $verbose;

GetOptions("cpu=i" => \$ncpu,
           "verbose" => \$verbose);

opendir (DIR, "scripts/") or die "cant open scripts/:$!";

while( (my $filename = readdir(DIR))){
  if($filename =~ /^\.+$/) {
    next;
  }
  if($filename =~ /^build_ghmm/) {
    if ($verbose) {
      !system("perl -Mlib=" . dirname(abs_path($0)) ."/../lib " . " scripts/$filename >/dev/null 2>&1") or die "cant execute script/$filename";
    } else {
      !system("perl -Mlib=" . dirname(abs_path($0)) ."/../lib " . " scripts/$filename") or die "cant execute script/$filename";
    }
  }
}


closedir(DIR);
