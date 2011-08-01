#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my $dir;

GetOptions("directory=s" => \$dir);

if (! defined $dir) {
  print STDERR "USAGE: $0 -d <directory>\n";
}

opendir (DIR, "$dir") or die "cant open $dir: $!\n";
my @files = grep { /.fasta$/  } readdir(DIR);
closedir(DIR);

my $id = 1;
foreach my $file (@files) {
  open (IN, "<$file") or die "cant open $file" ;
  $/ = ">";
  <IN>;
  foreach my $fasta (<IN>) {
    print ">seq$id $fasta\n";
    $id++;
  }
  close(IN);
}
