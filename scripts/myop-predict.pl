#!/usr/bin/perl

use File::Basename;
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Bio::SeqIO;
use Bio::DB::Fasta;
use Cwd 'abs_path';
use Digest::MD5 'md5_hex';
use FileHandle;
use IPC::Open2;
use MCE;
use MCE::Mutex;
use File::Basename 'dirname';

my $predictor;
my $genome;
my $transcriptome;
my $localmodel;
my $fasta;
my $ncpu = 1;
my $ghmm_model = "fixed_transition";
my $list_model = 0;
my $max_pass1_length = 400000;
my $step = 1;
my $help;

GetOptions("cpu=i" => \$ncpu,
           "genome|g=s" => \$genome,
           "transcriptome=s" => \$transcriptome,
           "local=s" => \$localmodel,
           "fasta=s" => \$fasta,
           "ghmm_model|m=s" => \$ghmm_model,
           "max_pass1_length=i" => \$max_pass1_length,
           "help" => \$help);

my $witherror = 0;

sub print_help {
  print STDERR "USAGE: " . basename($0) . " [-g <genome> | -t <transcriptome> | -l <local predictor>] -f <fasta file> [-c <number of cpu>] \n";
}

if ($help) {
  print_help();
  exit(-1);
}

if ($genome) {
  $predictor = abs_path(dirname(abs_path($0)) . "/../genome/" . $genome);
}

if ($transcriptome) {
  $predictor = abs_path(dirname(abs_path($0)) . "/../transcriptome/" . $transcriptome);
}

if ($localmodel) {
  $predictor = abs_path($localmodel);
}

# if(! defined ($predictor)){
#   $witherror = 1;
#   print STDERR "ERROR: missing the predictor location!\n";
# } else {
#   if (substr($predictor, 0, 1) eq "."  || substr($predictor, 0, 1) eq "/") {
#     $predictor = abs_path($predictor);
#   } else {
#     if ($genome) {
#       $predictor = abs_path(dirname(abs_path($0)) . "/../genome/" . $predictor)
#     }
#     if ($transcriptome) {
#       $predictor = abs_path(dirname(abs_path($0)) . "/../transcriptome/" . $predictor)
#     }
#   }
# }

if (! defined ($fasta)) {
  $witherror = 1;
  print STDERR "ERROR: missing fasta file name !\n";
}

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

if( $witherror) {
  print_help();
  exit(-1);
}

$fasta = abs_path($fasta);

my $ghmm_model_name = $ghmm_model;
$ghmm_model = "../ghmm/model/ghmm_$ghmm_model".".model";
my $ghmm_partial = "../ghmm/model/ghmm_partial".".model";

#
# validate the fasta file.
#
my $ids = `grep ">" $fasta`;
my %is_uniq;
my @all_ids = split (/\n/, $ids);
if(($#all_ids ) < 0)  {
    print STDERR "ERROR: not a valid fasta file !\n";
    exit(-1);
}
foreach my $id ( @all_ids) {
  if(!($id =~ /^>/)){
    print STDERR "ERROR: not a valid fasta file !\n";
    print STDERR "ERROR: I have found this strange line: \"$id\"!\n";
    exit(-1);
  }
  if($id =~ /^>\s+/) {
    print STDERR "ERROR: your fasta contains a sequence with an empty identification\n";
    print STDERR "ERROR: try to remove the spaces that appear between '>' and the id: \"$id\"\n";
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




my @tasks;
my @tasks2;
my $db = Bio::DB::Fasta->new ("$fasta", '-reindex' => 1 );
foreach my $id ($db->ids) {
  my $seqobj = $db->get_Seq_by_id($id);
  my $length = $seqobj->length;
  if($length >= $max_pass1_length)
    {
      my $start;
      for($start = 1; ; $start += $max_pass1_length)
        {
          my $end = $start + $max_pass1_length - 1;
          if($end >=  $length) {
              $end = $length;
          }
          my $seq = $db->seq("$id:$start,$end");
          my $gc = gc_content($seq);
          my %task_entry;
          $task_entry{seqname} = $id;
          $task_entry{start} = $start;
          $task_entry{end} = $end;
          $task_entry{gc} = $gc;
          $task_entry{length} = $length;
          push @tasks, \%task_entry;
	  if($end == $length) {
	    last;
	  }
        }
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
      $task_entry{length} = $length;
      push @tasks2, \%task_entry;
    }
}
my $total_seq = $#tasks + 1;


my $gtf_string = "";
my $a = MCE::Mutex->new;
undef $db; # destroy Bio::DB::Fasta



sub preserve_order_pass1 {
  my %tmp; my $order_id = 1;
  my %tmp2;

  return sub {
    my ($chunk_id, $tasks_ref, $data) = @_;
    $tmp{$chunk_id} = $data;
    $tmp2{$chunk_id} = $tasks_ref;

    while (1) {
      last unless exists $tmp{$order_id};
      my @result = @{$tmp{$order_id}};
      my @ts = @{$tmp2{$order_id}};
      my $task = $ts[0];
      my @seq = @{$result[0]};
      my $id = $task->{seqname};
      my $seqname = $task->{seqname}.":".$task->{start}.",".$task->{end};

      for(my $k = 0; $k <= $#seq; ) {
	my $split_point = (($k + $task->{start})/$max_pass1_length)*$max_pass1_length;
	if (!($seq[$k] =~  m/N|Ns|Nf/)) {
	  my $start = $k + $task->{start} - 100;
	  if ($start <= 0) {$start= 1;}
	  while(($k < $#seq) && !($seq[$k] =~/N|Ns|Nf/)) { $k++ ;}
	  my $end = $k + $task->{start} + 100;
	  if($end >= $task->{length}) { $end = $task->{length}-1 ; }
	  if(scalar( @tasks2) > 0) {
	    my $t = $tasks2[$#tasks2];
	    if (($id eq $t->{seqname}) && (scalar (@tasks2) > 0) && ( ( $start >= $split_point && $t->{end} <= $split_point) || ($start - $t->{end} <= 50))) {
	      $start = $t->{start};
	      $t = $tasks2[$#tasks2];
	      if($t->{seqname} eq $id){
		$t = pop @tasks2;
	      }
	    }
	  }
	  #print STDERR  "PUSH ".$id.": ".$start.",".$end." ".($end - $start + 1)." ".scalar(@tasks2)."\n";
	  my %task_entry;
	  $task_entry{seqname} = $id;
	  $task_entry{start} = $start;
	  $task_entry{end} = $end;
	  push @tasks2, \%task_entry;
	}
	$k ++;
      }
      delete $tmp{$order_id++};
    }
  }
}

my $gid = 0;
sub preserve_order_pass2 {
  my %tmp; my $order_id = 1;
  my %tmp2;
  return sub {
    my ($chunk_id, $tasks_ref, $data) = @_;
    $tmp{$chunk_id} = $data;
    $tmp2{$chunk_id} = $tasks_ref;

    while (1) {
      last unless exists $tmp{$order_id};
      opendir (PRED, "$predictor") or die "Cant open $predictor: $!\n";
      chdir(PRED);

      my @result = @{$tmp{$order_id}};
      my @t = @{$tmp2{$order_id}};
      my $task = $t[0];
      my $seq = $result[0];
      my $pid = open2(*Reader, *Writer, "scripts/tops_to_gtf_".$ghmm_model_name.".pl") or die "cant execute tops_to_gtf : $!";
      print Writer $seq;
      close(Writer);

      while (my $got = <Reader>) {
	my $gtf_string = $got;
	foreach my $l (split (/\n/, $gtf_string)) {
	  my @f = split(/\t/, $l);
	  if( scalar (@f) > 3) {
	    if (($f[2] =~ /start/) && ($f[6] eq "+")) {
	      $gid ++;
	      print "\n";
	    } elsif (($f[2] =~ /stop/) && ($f[6] eq "-")) {
	      $gid ++;
	      print "\n";
	    }
	    my $gname = "myop.$gid";
	    $f[8] = "gene_id \"$gname\"; transcript_id \"$gname\";\n";
	    print join("\t", @f);
	  } else {
	    print "\n";
	  }
	}
      }
      delete $tmp{$order_id++};
      close(PRED);
    }
    return;
  }
}


my $mce = MCE->new (input_data=>\@tasks,  max_workers => $ncpu, chunk_size => 1, gather => preserve_order_pass1,
  user_func =>
  sub {
    my ($mce, $chunk_ref, $chunk_id) = @_;
    my @result;
    my @result_t;
    my $task = $chunk_ref->[0];
    my $id = $task->{seqname};
    my $mid = get_closest_ghmm_id($task->{gc});
    my $seqname = $task->{seqname}.":".$task->{start}.",".$task->{end};
    $a->lock;
    my $db2 = Bio::DB::Fasta->new ("$fasta", '-reindex' => 0);
    my $x = $db2->seq($seqname);
    undef $db2;
    $a->unlock;
    if(!defined $x )
    {
      print STDERR "error: $seqname \n";
      next;
    }
    if($x =~ /^\s*$/) {
      print STDERR "warning extracting: $seqname\n";
      next;
    }
    my $seq = ">".($task->{seqname})."\n".($x)."\n";

    opendir (GHMM, "$predictor/ghmm.".$mid) or die "Cant open $predictor/ghmm: $!\n";
    chdir(GHMM);
    my $pid = open2(*Reader, *Writer, "myop-fasta_to_tops  | tops-viterbi_decoding -m $ghmm_partial 2> /dev/null ") or die "cant execute viterbi_decoding:$!";
    print Writer $seq;
    close(Writer);
    my $got = <Reader> ;
    chomp($got);
    my @seq = split(/ /,$got);
    shift @seq;
    shift @seq;
    push @result, \@seq;
    closedir(GHMM);
    push @result_t, $task;
    MCE->gather($chunk_id, \@result_t, \@result);
  });

$mce->run;
my $x = 1;
foreach my $t (@tasks2) {
  print STDERR $t->{seqname}."\tsegment\tgene\t".$t->{start}."\t".$t->{end}."\t.\t.\ts".$x."\n";
  $x ++;
}



my $mce2 = MCE->new (input_data=>\@tasks2,  max_workers => $ncpu, chunk_size => 1, gather => preserve_order_pass2,
  user_func =>
  sub {
    my ($mce, $chunk_ref, $chunk_id) = @_;
    my @result;
    my @result_t;
    foreach ( @{$chunk_ref} ) {
      my $task = $_;
      my $id = $task->{seqname};
      my $seqname = $task->{seqname}.":".$task->{start}.",".$task->{end};
      $a->lock;
      my $db2 = Bio::DB::Fasta->new ("$fasta", '-reindex' => 0);
      my $x = $db2->seq($seqname);
      my $gc = gc_content($x);
      my $mid = get_closest_ghmm_id($gc);
      undef $db2;
      $a->unlock;

      if(!defined $x )
      {
	print STDERR "error: $seqname \n";
	next;
      }
      if($x =~ /^\s*$/) {
	print STDERR "warning extracting: $seqname\n";
	next;
      }
      my $seq = ">".($task->{seqname})."\n".($x)."\n";


      opendir (GHMM, "$predictor/ghmm.$mid") or die "Cant open $predictor/ghmm.$mid: $!\n";
      chdir(GHMM);
      my $pid = open2(*Reader, *Writer, "myop-fasta_to_tops  | tops-viterbi_decoding -m $ghmm_model 2> /dev/null") or die "cant execute viterbi_decoding:$!";
      print Writer $seq;
      close(Writer);
      while (my $got = <Reader>) {
	push @result,  "<$seqname>,$got";
      }
      closedir(GHMM);
      push @result_t, $task;
    }
    MCE->gather($chunk_id, \@result_t, \@result);
  }
);

$mce2->run;


sub gc_content {
  my $seq = shift;
  my @seq = split(//, $seq);
  my $gc = 0.0;
  my $masked = 0;
  foreach my $n (@seq) {
    if( $n =~ /G|g|C|c/) {
      $gc ++;
    }
   if( ! $n =~ /A|C|G|T|a|c|g|t/ ) {
      $masked++;
   }
  }
  if(length ($seq) <= 0) {
    return 0.0;
  }
  return int(($gc / (length ($seq)-$masked)) * 100.0);
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



