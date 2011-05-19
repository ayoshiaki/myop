#!/usr/bin/env perl
use strict;
use warnings;

use Bio::SeqIO;
select  STDIN; $| = 1; # make stdin  unbuffered
select  STDOUT; $| = 1; # make stdout  unbuffered
my $in = Bio::SeqIO->new(-fh => \*STDIN, '-format' => 'Fasta');

while (my $seq = $in -> next_seq())
{
    my $name = $seq->id();
    $name =~ s/\t/ /g;
    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
    my @symbols = split("", $seq->seq());
    print "$name:\t".uc(join(" ", @symbols))."\n";
}
