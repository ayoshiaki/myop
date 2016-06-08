#!/usr/bin/perl

use File::Basename;
use strict;
use warnings;

use Getopt::Long;


my $fasta_filename;
my $seq = "";
my $first = 1;
my $nline = 1;
select STDIN; $| = 1;
select STDOUT; $| = 1;
while(<STDIN>) {

    chomp;
    my $line = $_;
    if($line =~ /^>/) {
        for(my $begin = 0; $begin < length($seq); $begin+=100)
        {
            my $out = substr($seq,$begin, 100);
            print uc($out)."\n";
        }
        $seq = "";
        print $line."\n";

    } else {
        $line =~ tr/a-z/A-Z/;
        $seq .= $line;
    }
}
for(my $begin = 0; $begin < length($seq); $begin+=100)
{
    my $out = substr($seq,$begin, 100);
    print uc($out)."\n";
}
$first  = 0;



