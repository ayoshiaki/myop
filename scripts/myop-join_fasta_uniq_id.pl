#!/usr/bin/perl

use File::Basename;
use strict;
use warnings;
use Getopt::Long;

my $dir;

GetOptions("directory=s" => \$dir);

if (! defined $dir) {
  print STDERR "USAGE: " . basename($0) . "  -d <directory>\n";
}

opendir (DIR, "$dir") or die "cant open $dir: $!\n";
my @files = grep { /.fasta$/  } readdir(DIR);
closedir(DIR);

my $id = 1;
foreach my $file (@files) {
  open (IN, "<$dir/$file") or die "cant open $dir/$file" ;
  $/ = ">";
  <IN>;
  foreach my $fasta (<IN>) {
    print ">seq$id $file $fasta\n";
    $id++;
  }
  close(IN);
}
