#!/usr/bin/perl
use warnings; #sed replacement for -w perl parameter
# Copyright 2017   David Snyder
# Apache 2.0
#

if (@ARGV != 2) {
  print STDERR "Usage: $0 <path-to-scores> <threshold>\n";
  print STDERR "e.g. $0 ./exp/scores_ind_pooled/plda_scores -6.2931\n";
  exit(1);
}

($scores_file, $threshold) = @ARGV;

open(SCRS, "<$scores_file") || die "Could not open the output file $scores_file";

while(<SCRS>) {
  chomp;
  $scoring = $_;
  ($claimant, $audio_file, $score) = split(" ",$scoring);
  ($origin) = split("_",$audio_file);

  if (($claimant == $origin) && ($score < $threshold)) {
    print "False Rejection  $scoring\n";
  } elsif (($claimant != $origin) && ($score >= $threshold)) {
    print "False Acceptance $scoring\n";
  }else {
    print "Correct\t\t $scoring\n";
  }
}
close(SCRS) || die;
