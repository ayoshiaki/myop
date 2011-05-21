#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

my $metaparfile = "cnf/meta.cnf";
my $configdir = "cnf/";
my %metapar;
# read metaparameters file
open (META, "<$metaparfile") or die "Cant open $metaparfile: $!\n";
foreach my $line (<META>)
  {
    chomp($line);
    my @fields = split(/\s*=\s*/, $line);
    # remove spaces;
    $fields[0] = trim_spaces($fields[0]);
    $fields[1] = trim_spaces($fields[1]);
    $metapar{$fields[0]} = $fields[1];
  }
close(META);


my $start_codon_length=$metapar{start_length};
my $start_codon_offset=$metapar{start_offset};
my $intron_short_length = $metapar{intron_short_length};
my $intergenic_length = $metapar{intergenic_length};
my $stop_codon_length= $metapar{stop_codon_length};
my $stop_codon_offset=$metapar{stop_codon_offset};
my $acceptor_length= $metapar{acceptor_length};
my $acceptor_initial_pattern_length = $metapar{acceptor_initial_pattern_length};
my $donor_initial_pattern_length = $metapar{donor_initial_pattern_length};
my $acceptor_offset=$metapar{acceptor_offset};
my $donor_length=$metapar{donor_length};
my $donor_offset=$metapar{donor_offset};
my $start_initial_pattern_length=$metapar{start_initial_pattern_length};
my $branch_length = $metapar{branch_length};

# Fixing offsets
my $fixed_donor_offset = $donor_offset + $donor_initial_pattern_length;
my $fixed_stop_offset = $stop_codon_offset;
my $donor_signal_length = $donor_length + $donor_initial_pattern_length;
my $acceptor_signal_length = $branch_length + $acceptor_length + $acceptor_initial_pattern_length;
my $start_signal_length = $start_codon_length + 3 + $start_initial_pattern_length;
my $stop_signal_length = $stop_codon_length;
my $exon_length_start = $start_codon_length - $start_codon_offset + $start_initial_pattern_length;
my $exon_length_stop = $stop_codon_offset;
my $exon_length_acceptor =  $acceptor_length - $acceptor_offset - 2 + $acceptor_initial_pattern_length;
my $exon_length_donor = $donor_offset + $donor_initial_pattern_length;
my $exon_delta_initial = $exon_length_start + $exon_length_donor;
my $exon_delta_internal = $exon_length_acceptor + $exon_length_donor;
my $exon_delta_final = $exon_length_acceptor + $exon_length_stop;
my $exon_delta_single = $exon_length_start + $exon_length_stop;
my $intron_delta = $branch_length + $acceptor_offset + 2 + $donor_length- $donor_offset;
my $intron_short_offset_forward = $donor_length - $donor_offset;
my $intron_short_offset_reverse = $branch_length + $acceptor_offset + 2 + $intron_short_length;
my $branch_offset = $branch_length + $acceptor_offset;

$metapar {intron_delta} = $intron_delta;
$metapar{branch_offset} = $branch_offset;

# create new configuration files from templates
opendir ( DIR, $configdir ) || die "Error in opening dir $configdir\n";
while( (my $filename = readdir(DIR))){
  if($filename =~ /^\.+$/) {
    next;
  }
  if($filename eq "meta.cnf") {
    next;
  }
  my $config;

  if((-e "ghmm/cnf/$filename" ) && ((-C "ghmm/cnf/$filename") <=  (-C "$metaparfile")) && ((-C "ghmm/cnf/$filename") <=(-C "$configdir/$filename"))){
    next;
  }
  print STDERR "Setup config file: $configdir$filename\n";
  open (FILE, "<$configdir/$filename") or die "Cant open $configdir/$filename:$!\n";
  while(<FILE>) {
    $config .= $_;
  }
  close(FILE);


  # replace all metaparameters
  foreach my $parname (keys %metapar)
    {
      $config =~ s/<$parname>/$metapar{$parname}/g;
    }

  # this code below evalutes expressions that are inside the ${<expression>}
  my $outconfig;
  my $reading_eval = 0;
  my $evalexpr;
  for(my $i = 0; $i < length($config); $i++)
    {
      my $c = substr($config, $i, 1);
      my $cc = substr($config, $i+1, 1);
      if($c eq '$' && $cc eq '{')
        {
          $reading_eval = 1;
          $i++;
          next;
        }
      if($reading_eval && !($c eq '}')) {
        $evalexpr .= $c;
        next;
      }
      if($reading_eval && $c eq '}')
        {
          $outconfig .= eval($evalexpr);
          $evalexpr = "";
          $reading_eval = 0;
          next;
        }
      $outconfig .= $c;
    }

  my @config_lines = split (/\n/, $outconfig);
  my %revcomppar ;
  foreach my $l (@config_lines)
    {
      if($l =~ m/#\s*myop_revcomp:\s*(.+)\s*=\s*(.+)\s*/)
        {
          my $par = trim_spaces($1);
          my $value = trim_spaces($2);
          $revcomppar{$par} = $value;
        }
    }

  open (OUT, ">ghmm/cnf/$filename") or die "cant open ghmm/cnf/$filename";
  foreach my $l (@config_lines) {
    if(!($l =~ m/^#\s*myop_revcomp/)) {
      print OUT $l."\n";
    }
  }
  close(OUT);

  if(scalar(keys %revcomppar) > 0)
    {
      my $extension = get_file_extension($filename);
      my $revcomp_file = remove_extension($filename)."_rev".".$extension";

      open (OUT, ">ghmm/cnf/$revcomp_file") or die "cant open ghmm/cnf/$revcomp_file:$!";
      foreach my $l (@config_lines) {
        if(!($l =~ m/^#\s*myop_revcomp/)) {
          if($l =~ m/(#?)\s*(.+)\s*=\s*(.+)\s*/)
            {
              my $comment = $1;
              if(!defined $comment){
                $comment = "";
              }
              my $par = trim_spaces($2);
              my $value = trim_spaces($3);
              if(defined $revcomppar{$par})
                {
                  print OUT $comment.$par ."=".$revcomppar{$par}."\n";
                }
              else
                {
                  print OUT $l."\n";
                }
            }
        }
      }
      close(OUT);
    }


}
closedir(DIR);

sub get_file_extension {
  my $file = shift;
  my @seg = split (/\./, $file);
  return $seg[$#seg];
}

sub remove_extension {
  my $file = shift;
  my @seg = split (/\./, $file);
  my $result = $seg[0];
  for(my $i = 1; $i < $#seg; $i++){
    $result .= ".".$seg[$i];
  }
  return $result;
}

sub trim_spaces {
  my $v = shift;
  $v =~ s/^\s+//;     $v =~ s/\s+$//;
  return $v;
}
