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

# create new configuration files from templates
opendir ( DIR, $configdir ) || die "Error in opening dir $configdir\n";
while( (my $filename = readdir(DIR))){
  if($filename =~ /^\.+$/) {
    next;
  }
  my $config;
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
