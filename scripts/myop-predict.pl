#!/usr/bin/perl 

use strict; 
use warnings;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;

my $metaparfile = "cnf/meta.cnf";
my $configdir = "ghmm/cnf/";
my $ncpu = 1;
GetOptions("cpu=i" => \$ncpu);

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

my @tasks_forward;
my @tasks_reverse;
opendir ( DIR, $configdir ) || die "Error in opening dir $configdir\n";
while( (my $filename = readdir(DIR))){
  if($filename =~ /^\.+$/) {
    next;
  }
  if($filename =~ /_rev/) {
    push @tasks_reverse, $filename;
  } else {
    push @tasks_forward, $filename;
  }
}
closedir(DIR);

my @tasks = (@tasks_forward, @tasks_reverse);
my $pm = new Parallel::ForkManager($ncpu);
foreach my $task (@tasks) {
  print "Generating training set: $task\n";
  open (IN, "<$configdir/$task") or die "cant open $task:$!";
  foreach my $line (<IN>) {
    if($line =~ m/myop_generate_training_set\s*=\s*(.+)/) 
      {
	my $cmd = $1;
	$cmd =~ s/\"//g;
	system($cmd);
      }
  }
  close(IN);
}
$pm->wait_all_children;




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
