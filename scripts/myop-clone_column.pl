#!/usr/bin/perl

use strict;
use warnings;

# Clone a column into two identical columns. 
# (separeted with \t)

while (<>) {
    chomp;
    print $_."\t".$_."\n";
}
