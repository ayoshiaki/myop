#!/usr/bin/perl

use strict;
use warnings;

opendir (DIR, "scripts/") or die "cant open scripts/:$!";

while( (my $filename = readdir(DIR))){
  if($filename =~ /^\.+$/) {
    next;
  }
  if($filename =~ /^build_ghmm/) {
    system("scripts/$filename");
  }
}


closedir(DIR);
