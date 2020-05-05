#!/usr/bin/perl
use warnings; #sed replacement for -w perl parameter
# Copyright 2017   David Snyder
# Apache 2.0
#

if (@ARGV != 2) {
  print STDERR "Usage: $0 <path-to-input> <path-to-output>\n";
  print STDERR "e.g. $0 ./data/init ./data\n";
  exit(1);
}

($db_base, $out_dir) = @ARGV;

# Handle train
$out_dir_train = "$out_dir/train";
if (system("mkdir -p $out_dir_train")) {
  die "Error making directory $out_dir_train";
}

$tmp_dir_train = "$out_dir_train/tmp";
if (system("mkdir -p $tmp_dir_train") != 0) {
  die "Error making directory $tmp_dir_train";
}

open(GNDR, ">$out_dir_train/spk2gender") || die "Could not open the output file $out_dir_train/spk2gender";
open(SPKR, ">$out_dir_train/utt2spk") || die "Could not open the output file $out_dir_train/utt2spk";
open(WAV, ">$out_dir_train/wav.scp") || die "Could not open the output file $out_dir_train/wav.scp";
open(TXT, ">$out_dir_train/text") || die "Could not open the output file $out_dir_train/text";

if (system("cp $db_base/docs/wav_train.sph $tmp_dir_train/sph.list") != 0) {
  die "Error getting list of sph files";
}

open(WAVLIST, "<$tmp_dir_train/sph.list") or die "cannot open wav list";

%spk2gender = ();
while(<WAVLIST>) {
  chomp;
  $sph = $_;
  @t = split("[.|/]",$sph);
  $utt = $t[-2];

  ($spk, $gender, $types) = split("_",$utt);
  $type = substr($types, 0, 1);

  $stnc = "";
  if ($type == 1) {
    $stnc = "SUARA SAYA ADALAH KATA SANDI SAYA";
  } elsif ($type == 2) {
    $stnc = "KATA SUARA SAYA";
  } elsif ($type == 3) {
    $stnc = "SANDI";
  }

  print TXT "$utt $stnc\n";
  print WAV "$utt $sph\n";
  print SPKR "$utt $spk\n";
  if ((not exists($spk2gender{$spk}))) {
    $spk2gender{$spk} = $gender;
    print GNDR "$spk $gender\n";
  }
}
close(TXT) || die;
close(WAV) || die;
close(SPKR) || die;
close(GNDR) || die;
close(WAVLIST) || die;


if (system("utils/utt2spk_to_spk2utt.pl $out_dir_train/utt2spk >$out_dir_train/spk2utt") != 0) {
  die "Error creating spk2utt file in directory $out_dir_train";
}
if (system("utils/fix_data_dir.sh $out_dir_train") != 0) {
  die "Error fixing data dir $out_dir_train";
}
