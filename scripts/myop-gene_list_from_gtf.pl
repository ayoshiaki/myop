#!/usr/bin/perl

use strict;
use warnings;

my %genes;

while (<>) {
  chomp;
  if ($_ =~ /^\s*$/) {
    next;
  }
  my @fields = split (/\t/, $_);
  my $attr = $fields[8];
  if($attr =~ m/gene_id\s"(.+)?";\s+t.+/) {
    $genes{$1} = 1;
  }
}

foreach my $key (keys %genes) {
  print $key."\n";
}
