#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

use Bio::SeqIO;
my $threshold ;
my $delta = 0;
GetOptions("threshold=i" => \$threshold, 
    "delta=i" => \$delta);



my $in = Bio::SeqIO->new(-fh => \*STDIN, '-format' => 'Fasta');
print "SEQ_LENGTH:\t";
while (my $seq = $in -> next_seq())
{
    my $name = $seq->id();
    $name =~ s/\t/ /g;
    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
    my @symbols = split("", $seq->seq());
    my $length = (scalar(@symbols) - $delta);
    if(defined $threshold){
	if (scalar(@symbols) < $threshold) {
	    print "".($length)." ";
	}    
    } else {
	print "".($length)." ";
    }
}
