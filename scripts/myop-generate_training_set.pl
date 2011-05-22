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

#
# validate the fasta file.
#
my $ids = `grep ">" dataset/train.fa`;
my %is_uniq;
my @all_ids = split (/\n/, $ids);
foreach my $id ( @all_ids) {
  if(!($id =~ /^>/)){
    print STDERR "ERROR: not a valid fasta file !\n";
    print STDERR "ERROR: i have found this strange line: \"$id\"!\n";
    exit(-1);
  }
  if($id =~ /^>\s+/) {
    print STDERR "ERROR: your fasta contains a sequence with an empty identification\n";
    print STDERR "ERROR: try to remove the spaces that appears between '>' and the id: \"$id\"\n";
    exit(-1);
  }

  if($id =~ /^>\s*$/) {
    print STDERR "ERROR: your fasta contains a sequence with an empty identification\n";
    exit(-1);
  }
  if(defined $is_uniq{$id}) {
    print STDERR "ERROR: each sequence must have different identification, $id is duplicated\n";
    exit(-1);
  }
  $is_uniq{$id} = 1;
}
system ("segseq-reindex dataset/train.fa");

do_tasks(\@tasks_forward);
do_tasks(\@tasks_reverse);
#####
my $bands = $metapar{isochore_nband};
my $mingc = $metapar{isochore_min};
my $maxgc = $metapar{isochore_max};
my $main_folder = "ghmm";

# Defs
my $head = 0;
my $body = 1;
my $training_set = "dataset/train.fa";
my $gtf = "dataset/train.gtf";

# Receives a string with the sequence and returns its gc content.
sub gc_content {
  my $seq = shift;
  my @seq = split(//, $seq);
  my $gc = 0.0;
  foreach my $n (@seq) {
    if( $n =~ /G|g|C|c/) {
      $gc ++;
    }
  }
  if(length ($seq) <= 0) {
    return 0.0;
  }
  return ($gc / length ($seq));
}

# Receives an alpha and a beta and computes the weight like Augustus does.
sub compute_weight {
  my $band = $_[0];
  my $gc = $_[1];
  return int(10*exp(-200*($band - $gc)**2) + 1);
}

# Removes / from the end of the string
if ($main_folder =~ /\/$/) {
  chop $main_folder;
}
my %gc_by_id;
my @seq = ("","");
my @new_seq = ("","");
my $first_time = 1;
open (IN, "<dataset/train.fa") or die "cant open dataset/train.fa:$!";
while (<IN>) {

  chomp;

  if ($_ =~ /^>.*/) {
    if ($first_time) {
      $seq[$head] = $_;
      $first_time = 0;
    }
    else {
      my $id = $seq[$head];
      $id =~ s/^>//s;
      $gc_by_id{$id} = gc_content($seq[$body]);
      $seq[$head] = $_;
      $seq[$body] = "";
    }
  }
  else {
    $seq[$body] .= $_;
  }
}
close (IN);

# Removes folders.
if($bands < 2) {
  $bands = 2;
}
my $increment = ($maxgc - $mingc)/($bands-1);
open (TOUCH, ">ghmm/dataset/sequence_weights.txt"); print TOUCH ""; close(TOUCH);
for (my $i = 0; $i < $bands; $i++) {
  my $band_center = $i * $increment + $mingc;
  system ("mkdir -p $main_folder.$i/model");
  system ("mkdir -p $main_folder.$i/dataset");

  my %weight_hash = ();
  print STDERR "specific gc model: ".$band_center."\n";
  open (WEIGTHS, ">$main_folder.$i/dataset/sequence_weights.txt");
  foreach my $id ( keys %gc_by_id) {
      my $weight = compute_weight ($band_center, $gc_by_id{$id});
      print WEIGTHS $id."\t".$weight."\n";
  }
  close(WEIGTHS);
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
sub do_tasks {
  my @tasks = @{(shift(@_))};
  my $pm = new Parallel::ForkManager($ncpu);
  foreach my $task (@tasks) {
    $pm->start and next;
    my $training_set_filename = "";
    my $cmd  = "";
    open (IN, "<$configdir/$task") or die "cant open $task:$!";
    foreach my $line (<IN>) {
      if($line =~ m/^\s*training_set\s*=\s*\"(.+)\"/)
        {
          $training_set_filename = "ghmm/".$1;
        }
      if($line =~ m/#\s*myop_generate_training_set\s*=\s*(.+)/)
        {
          $cmd = $1;
          $cmd =~ s/\"//g;
        }
    }
    close(IN);
    if(!($cmd  =~ m/^\s*$/) && ((-e "$training_set_filename" && (-C "$training_set_filename" >= -C "$configdir/$task")) || ((! -e "$training_set_filename") )))
      {
        print STDERR "Generating training set: [ $cmd ] !\n";
        system($cmd);
      }
    $pm->finish;
  }
  $pm->wait_all_children;
}
