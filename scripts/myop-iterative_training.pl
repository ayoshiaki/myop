#!/usr/bin/perl

use File::Basename;
use strict;
use warnings;
use Getopt::Long;
use File::Temp qw/ tempfile tempdir /;
use File::Copy;
use File::Copy::Recursive qw/ dircopy /;
use File::Path qw/ rmtree /;


my $fasta;
my $pre_trained_model;
my $out_directory;
my $max_iter;
my $ncpu = 1;

GetOptions("fasta=s" => \$fasta,
           "pre_trained_model=s" => \$pre_trained_model,
           "out=s" => \$out_directory,
           "iter=s" => \$max_iter,
           "cpu=i" => \$ncpu);

my $with_errors = 0;
if( !defined $fasta ) {
  print STDERR "ERROR: missing fasta file: $!\n";
  $with_errors = 1;
}
if( !defined $pre_trained_model ) {
  print STDERR "ERROR: missing initial model: $!\n";
  $with_errors = 1;
}
if( !defined $out_directory ) {
  print STDERR "ERROR: missing output directory: $!\n";
  $with_errors = 1;
}

if( !defined $max_iter ) {
  print STDERR "ERROR: missing the number of iterations: $!\n";
  $with_errors = 1;
}


if($with_errors ) {
  print STDERR "USAGE: " . basename($0) . "  -f <fasta> -p <initial model> -i <number of iterations> -o <output directory>\n";
  print STDERR "\t -d switch on debug mode\n";
  exit(-1);
}

mkdir $out_directory or die "cant create directory $out_directory: $!\n";
my $part = 0;
dircopy $pre_trained_model, "$out_directory/model_$part" or die "$!\n";

while($part < $max_iter){
  my $dir = tempdir( CLEANUP => 1);
  my $current_model = "$out_directory/model_$part";
  my $gene_list_from_pred = "$dir/gene_list_$part.txt";
  my $tx_table = "$dir/tx_table_$part.txt";
  my $splited_genes = "$dir/genes";
  my $err = "$dir/err";
  my $out = "$dir/out";
  my $pred_output = "$dir/pred_$part.gtf";
  my $train_fasta = "$dir/train.fa";
  my $train_gtf = "$dir/train.gtf";
  !system ("myop-predict  -p $current_model -f $fasta -c $ncpu > $pred_output 2> $err") or create_error_and_exit ($dir, "$!");
  copy $pred_output, "$out_directory/pred_$part.gtf";
  if ($part >= 1) {
    my $prev = "$out_directory/pred_".($part - 1).".gtf";
    my $diff = `diff $out_directory/pred_$part.gtf $prev`;
    if($diff =~ m/^\s*$/) {
      last;
    }
  }

  !system ("myop-gene_list_from_gtf  $pred_output > $gene_list_from_pred") or create_error_and_exit ($dir, "$!");
  !system ("myop-clone_column  <$gene_list_from_pred >$tx_table") or create_error_and_exit ($dir, "$!");
  !system ("myop-clean_gene_list  -f $fasta -l $gene_list_from_pred  -t $tx_table -g $pred_output -o $splited_genes 1> $err 2> $out") or create_error_and_exit ($dir, "$!");
  !system ("touch   $train_fasta $train_gtf ") or create_error_and_exit ($dir, "$!");
  system ("for j in $splited_genes/*/*.fa; do echo \"\" >>$train_fasta ; cat \$j >>$train_fasta ; done");
  system ("for j in $splited_genes/*/*.gtf; do echo \"\" >>$train_gtf ; cat \$j >>$train_gtf ; done");
  $part ++;
  !system ("myop-train  -r $current_model -g $train_gtf -f $train_fasta -c $ncpu -o $out_directory/model_$part > $err 2> $out") or create_error_and_exit ($dir, "$!");

  rmtree ($dir);
}


sub create_error_and_exit {
  my $dir = shift;
  my $msg = shift;
  dircopy  ($dir, "$out_directory/debug");
  die $msg;
}

