#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;
use Bio::SeqIO;
use Bio::DB::Fasta;
use Cwd 'abs_path';
use Digest::MD5 'md5_hex';
use FileHandle;
use IPC::Open2;

my $predictor;
my $fasta;
my $ncpu;
my $max_length = 500000;
my $ghmm_model = "intron_short";
my $list_model = 0;
GetOptions("cpu=i" => \$ncpu,
           "predictor=s" => \$predictor,
           "fasta=s" => \$fasta,
           "max_length=i" => \$max_length,
           "ghmm_model=s" => \$ghmm_model,
           "list_model" => \$list_model);

my $overlap = $max_length/5;
if($overlap > 10000) {
  $overlap  = 10000;
}
my $witherror = 0;
if(! defined ($predictor)){
  $witherror = 1;
  print STDERR "ERROR: missing the predictor location!\n";
}

$predictor = abs_path($predictor);

if((!($witherror) && $list_model)) {
  print "Avaliable GHMM model:\n";

  opendir (DIR, "$predictor/ghmm/model") or die "cant open $predictor/ghmm/model:$!\n";
  while(my $filename = readdir(DIR)){
    if ($filename =~ /^ghmm_(.+).model/) {
      print "\t".$1."\n";
    }
  }
  closedir(DIR);

 exit(-1);
}
my $ghmm_model_name = $ghmm_model;
print STDERR "Using $ghmm_model\n";

if (! defined ($fasta)) {
  $witherror = 1;
  print STDERR "ERROR: missing fasta file name !\n";
}
if(! defined ($predictor)){
  $witherror = 1;
  print STDERR "ERROR: missing the predictor location!\n";
}
if( $witherror) {
  print STDERR "USAGE: $0 -p <predictor directory> -f <fasta file> [-c <number of cpu>] -o <output directory>\n";
  exit(-1);
}
$ghmm_model = "../ghmm/model/ghmm_$ghmm_model".".model";

#
# validate the fasta file.
#
my $ids = `grep ">" $fasta`;
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

#
# We have to know the metaparameters
#
my %metapar;
my $metaparfile = "$predictor/cnf/meta.cnf";
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




# 1. The first step is to build a list of "tasks" which each task is represented by a tuple (seqname, start, end, gc_content).
#    a. if the sequence length is greater than $max_length then split it in smaller subsequences, and then create subtasks.
my @tasks;
my $db = Bio::DB::Fasta->new ("$fasta");
foreach my $id ($db->ids) {
  my $seqobj = $db->get_Seq_by_id($id);
  my $length = $seqobj->length;
  if($length > $max_length)
    {
      my $start;
      for($start = 1; $start < ($length - $max_length); $start += ($max_length - $overlap))
        {
          my $end = $start + $max_length - 1;
          my $seq = $db->seq("$id:$start,$end");
          my $gc = gc_content($seq);
          my %task_entry;
          $task_entry{seqname} = $id;
          $task_entry{start} = $start;
          $task_entry{end} = $end;
          $task_entry{gc} = $gc;
          push @tasks, \%task_entry;
        }
      # the last subsequence is different
      $start = $length - $max_length + 1;
      my $end = $start + $max_length - 1;
      my $seq = $db->seq("$id:$start,$end");
      my $gc = gc_content($seq);
      my %task_entry ;
      $task_entry{seqname} = $id;
      $task_entry{start} = $start;
      $task_entry{end} = $end;
      $task_entry{gc} = $gc;
      push @tasks, \%task_entry;
    }
  else
    {
      my $end = $length;
      my $seq = $db->seq("$id");
      my $gc = gc_content($seq);
      my %task_entry;
      $task_entry{seqname} = $id;
      $task_entry{start} = 1;
      $task_entry{end} = $end;
      $task_entry{gc} = $gc;
      push @tasks, \%task_entry;
    }
}


while (scalar @tasks) {
  my $tempfile = File::Temp->new(UNLINK=>0);
  flock ($tempfile, 8);
  my @tasks_chunk;
  for (my $i = 0; $i < $ncpu && (scalar @tasks); $i++) {
    my $t = pop @tasks;
    push @tasks_chunk, $t;
  }
  # Run tasks in parallel
  my $pm = new Parallel::ForkManager($ncpu);
  foreach my $task (@tasks_chunk) {
    $pm->start and next;
    my $mid = get_closest_ghmm_id($task->{gc});
    my $seqname = $task->{seqname}.":".$task->{start}.",".$task->{end};
    my $x = $db->seq($seqname);
    if($x =~ /^\s*$/) {
      print STDERR "warning extracting: $seqname\n";
    }
    my $seq = ">".($task->{seqname})."\n".($x)."\n";

    opendir (GHMM, "$predictor/ghmm.$mid") or die "Cant open $predictor/ghmm.$mid: $!\n";
    chdir(GHMM);
    my $pid = open2(*Reader, *Writer, "myop-fasta_to_tops.pl | viterbi_decoding -m $ghmm_model 2> /dev/null") or die "cant execute viterbi_decoding:$!";
    print Writer $seq;
    close(Writer);
    my $filename = $tempfile->filename;

    open (OUT, ">>$filename") or die "cant open $filename:$!\n";
    while (my $got = <Reader>) {
      # get an exclusive lock
      flock(OUT, 2);
      print OUT "<$seqname>,$got";
    }
    close (OUT);
    closedir(GHMM);
    $pm->finish;
  }
  $pm->wait_all_children;

  $tempfile->unlink_on_destroy(1);
  seek($tempfile, 0,0);

  #
  # Translate the viterbi output to GTF format.
  #
  opendir (GHMM, "$predictor") or die "Cant open $predictor: $!\n";
  chdir(GHMM);
  my $input = $tempfile->filename;
  my $cmd = "cat $input | scripts/tops_to_gtf_".$ghmm_model_name.".pl";
  my $result = `$cmd`;
  print $result;
  closedir(GHMM);
}

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
  return int(($gc / length ($seq)) * 100.0);
}


sub get_closest_ghmm_id {
  my $gc = shift;
  my $bands = $metapar{isochore_nband};
  my $maxgc = $metapar{isochore_max}* 100.0;
  my $mingc = $metapar{isochore_min}* 100.0;
  if($bands < 2) {
        $bands = 2;
  }
  my $increment = ($maxgc - $mingc)/($bands-1);

  my $min_diff = 10000;
  my $model_id = 0;
  for (my $i = 0; $i < $bands; $i++){
    my $band_center = $i*$increment + $mingc;
    my $diff =  ($band_center - $gc);
    if($diff < 0) { $diff = $diff *(-1); }
    if($diff < $min_diff) {
      $min_diff = $diff;
      $model_id =$i;
    }
  }
  return $model_id;
}

sub trim_spaces {
  my $v = shift;
  $v =~ s/^\s+//;     $v =~ s/\s+$//;
  return $v;
}
