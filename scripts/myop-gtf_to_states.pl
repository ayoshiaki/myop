#!/usr/bin/perl -w

use File::Basename;
use strict;
use warnings;

use GTF;
use Data::Dumper;
my @gtf_files = @ARGV;

if($#gtf_files < 0) {
  print STDERR "USAGE: " . basename($0) . "  <file1.gtf> <file2.gtf> ...\n";
  exit();
}


# reading all GTFs
my %sites;
my $result = "";
foreach my $gtf_file (@gtf_files)
{
    my $gtf = GTF::new({gtf_filename => $gtf_file});
    # print STDERR "PROCESSING $gtf_file\n";
    foreach my $gene (@{$gtf->genes()})
    {
	if($gene->strand() eq "+")
	{
	    $result .= process_forward($gene);
	} else {
	   $result .=  process_reverse($gene);
	}
    }
}
print "STATES:\t$result\n";
print "STATES_REV:\t".reverse_str($result)."\n";

sub reverse_str {
    my $seq = shift;
    my $result = "";
    my @symbols = split(/ /, $seq) ;
    for(my $i = scalar(@symbols) -1 ; $i >= 0; $i--)
    {
	my $s = $symbols[$i];
 	if($s eq "start") {
	    $result .= "rstart ";
	} elsif($s eq "stop") {
	    $result .= "rstop ";
	} elsif( $s eq "ES") {
	    $result .= "rES ";
	} elsif ($s =~ m/^E(\d)(\d)/) {
	    $result .= "rE".$2.$1." " ;
	} elsif ($s =~ m/^EI(\d)/) {
	    $result .= "rEI$1 ";
	} elsif ($s =~ m/^ET(\d)/) {
	    $result .= "rET$1 ";
	} elsif ($s eq "N") {
	    $result .= "N ";
	} else {
	    $result .= "r".$s." ";
	}
    }
    return $result;
}

sub process_forward {
    my $gene = shift;
    my $result ="";
    foreach my $tx (@{$gene->transcripts()})
    {
	my @start_codons = @{$tx->start_codons()};
	my @stop_codons = @{$tx->stop_codons()};
	my $last_right_site;
	my $outphase;
	my $inphase;
	foreach my $cds (@{$tx->cds()} )
	{
	    my $left_site;
	    my $right_site;
	    my $is_start_codon = 0;
	    foreach my $start_codon (@start_codons)
	    {
		if($cds->start() ==  $start_codon->start())
		{
		    $is_start_codon = 1;
		    last;
		}
	    }
	    my $is_stop_codon = 0;
	    foreach my $stop_codon (@stop_codons)
	    {
		if(($cds->stop() + 1) ==  $stop_codon->start())
		{
		    $is_stop_codon = 1;
		    last;
		}
	    }
	    if($is_start_codon) {
		$outphase = ($cds->stop() - $cds->start() ) % 3;
		$inphase = ($outphase +  1)%3;
		if(scalar @{$tx->cds()} == 1)
		{
		    $result .= "N start ES stop N ";
		} else {
		    $result .= "N start EI".$outphase." "."don".$inphase." I".$inphase." acc".$inphase." "
		}
	    } elsif ($is_stop_codon)  {
		$result .= "ET$inphase stop N ";
	    }else{
		my $oinphase = $inphase;
		$outphase = ($inphase + $cds->stop() - $cds->start())  % 3;
		$inphase = ($outphase + 1) %3;

		$result .= "E$oinphase$outphase don$inphase I$inphase acc$inphase ";

	    }
	}
    }
    return $result;
}


sub process_reverse {
    my $gene = shift;
    my $result = "";
    foreach my $tx (@{$gene->transcripts()})
    {
	my @start_codons = @{$tx->start_codons()};
	my @stop_codons = @{$tx->stop_codons()};
	my $last_right_site;
	my $outphase ;
	my $inphase ;
	my $has_start = 0;
	for(my $c = scalar(@{$tx->cds()}) -1 ; $c >= 0; $c--){
	    my $cds = ${$tx->cds()}[$c];
	    my $left_site;
	    my $right_site;
	    my $is_start_codon = 0;
	    foreach my $start_codon (@start_codons)
	    {
		if($cds->stop() ==  $start_codon->stop())
		{
		    $is_start_codon = 1;
		    last;
		}
	    }
	    my $is_stop_codon = 0;
	    foreach my $stop_codon (@stop_codons)
	    {
		if(($cds->start() - 1) ==  $stop_codon->stop())
		{
		    $is_stop_codon = 1;
		    last;
		}
	    }
	    if($is_start_codon) {
		$outphase = ($cds->stop() - $cds->start()) % 3;
		$inphase = ($outphase+1)%3;
		if(scalar @{$tx->cds()} == 1)
		{
		    $result .= "N start ES stop N ";
		} else {
		    $result .= "N start EI".$outphase." "."don".$inphase." I".$inphase." acc".$inphase." ";
		}
		$has_start = 1;
	    } elsif ($is_stop_codon && $has_start)  {
		$result .= "ET$inphase stop N ";
		$has_start = 0;
	    }elsif ($has_start) {
		my $oinphase = $inphase;
		$outphase = ($inphase + $cds->stop() - $cds->start()) % 3;
		$inphase = ($outphase + 1) %3;
		$result .=  "E$oinphase$outphase don$inphase I$inphase acc$inphase ";
	    }
	}
    }
    return $result;
}



