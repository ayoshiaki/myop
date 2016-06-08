#!/usr/bin/perl

use File::Basename;
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;

my $metaparfile = "cnf/meta.cnf";
my $configdir = "ghmm/cnf/";
my $ncpu = 1;
my $verbose;
GetOptions("cpu=i" => \$ncpu,
           "verbose" => \$verbose);

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
my @task_isochore;
my @tasks = (@tasks_forward, @tasks_reverse);
opendir (GHMM, "ghmm") or die "cant open directory ghmm:$!";
chdir(GHMM);
close(GHMM);
mkdir "model";
my $pm = new Parallel::ForkManager($ncpu);
foreach my $task (@tasks) {
  my $model_name = remove_extension($task).".model";
  if(-e "model/$model_name" && (-C "model/$model_name") <= (-C "cnf/$task")) {
    next;
  }
  $pm->start and next;
  open (IN, "<cnf/$task") or die "cant open $task:$!";
  foreach my $line (<IN>) {
    if($line =~ m/#\s*myop_train\s*=\s*(.+)/)
      {
        my $cmd = $1;
        $cmd =~ s/\"//g;
        if ($verbose) {
          print STDERR "Creating model: [ $cmd ]\n";
        }
        !system("$cmd 2> /dev/null ") or die "cant execute $cmd:$!";
      }
  }
  close(IN);
  $pm->finish;
}
$pm->wait_all_children;
foreach my $task (@tasks) {
  my $model_name = remove_extension($task).".model";
  open (IN, "<cnf/$task") or die "cant open $task:$!";
  foreach my $line (<IN>) {
    if($line =~ m/#\s*myop_isochore\s*=\s*1/){
      push @task_isochore, $task;
      if ($verbose) {
        print STDERR $task." is isochore dependent \n";
      }
    }
  }
  close(IN);
}


my $bands = $metapar{isochore_nband};
my $mingc = $metapar{isochore_min};
my $maxgc = $metapar{isochore_max};
my $main_folder = "ghmm";

for (my $i = 0; $i < $bands; $i++) {
  foreach my $task (@task_isochore) {
    my $model_name = remove_extension($task).".model";
    opendir (GHMM, "../ghmm.$i") or die "cant open directory ghmm.$i:$!";
    chdir(GHMM);
    if(-e "model/$model_name" && (-C "model/$model_name") <= (-C "../ghmm/cnf/$task")) {
      next;
    }
    mkdir "model";
    open (IN, "<../ghmm/cnf/$task") or die "cant open $task:$!";
    foreach my $line (<IN>) {
      if($line =~ m/#\s*myop_train\s*=\s*(.+)/)
        {
          my $cmd = $1;
          $cmd =~ s/\"//g;
          if ($verbose) {
            print "Creating isochore dependent model: [ $cmd ] \n";
          }
          !system("$cmd  2> /dev/null") or die "cant execute $cmd:$!";
        }
    }
    close(GHMM);
    close(IN);
  }
}



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
