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

# Handle enroll
$out_dir_enroll = "$out_dir/eval_enroll";
if (system("mkdir -p $out_dir_enroll")) {
  die "Error making directory $out_dir_enroll";
}

$tmp_dir_enroll = "$out_dir_enroll/tmp";
if (system("mkdir -p $tmp_dir_enroll") != 0) {
  die "Error making directory $tmp_dir_enroll";
}

open(GNDR, ">$out_dir_enroll/spk2gender") || die "Could not open the output file $out_dir_enroll/spk2gender";
open(SPKR, ">$out_dir_enroll/utt2spk") || die "Could not open the output file $out_dir_enroll/utt2spk";
open(WAV, ">$out_dir_enroll/wav.scp") || die "Could not open the output file $out_dir_enroll/wav.scp";
open(TXT, ">$out_dir_enroll/text") || die "Could not open the output file $out_dir_enroll/text";

if (system("cp $db_base/docs/wav_enrollment.sph $tmp_dir_enroll/sph.list") != 0) {
  die "Error getting list of sph files";
}

open(WAVLIST, "<$tmp_dir_enroll/sph.list") or die "cannot open wav list";

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

# Handle test
$out_dir_test= "$out_dir/eval_test";
if (system("mkdir -p $out_dir_test")) {
  die "Error making directory $out_dir_test";
}

$tmp_dir_test = "$out_dir_test/tmp";
if (system("mkdir -p $tmp_dir_test") != 0) {
  die "Error making directory $tmp_dir_test";
}

open(GNDR, ">$out_dir_test/spk2gender") || die "Could not open the output file $out_dir_test/spk2gender";
open(SPKR, ">$out_dir_test/utt2spk") || die "Could not open the output file $out_dir_test/utt2spk";
open(WAV, ">$out_dir_test/wav.scp") || die "Could not open the output file $out_dir_test/wav.scp";
open(TXT, ">$out_dir_test/text") || die "Could not open the output file $out_dir_test/text";

if (system("cp $db_base/docs/wav_test.sph $tmp_dir_test/sph.list") != 0) {
  die "Error getting list of sph files";
}

open(WAVLIST, "<$tmp_dir_test/sph.list") or die "cannot open wav list";

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
close(GNDR) || die;
close(WAVLIST) || die;

open(TRL, ">$out_dir_test/trials") || die "Could not open the output file $out_dir_test/trials";
open(SPKR, "<$out_dir_test/utt2spk") || die "Could not open the output file $out_dir_test/utt2spk";

while(<SPKR>) {
    chomp;
    ($utt, $spk) = split(" ",$_);
    foreach my $key (keys %spk2gender) {
        if ($key == $spk) {
            print TRL "$key $utt target\n";
        } else {
            print TRL "$key $utt nontarget\n";
        }
    }
}

close(TRL) || die;
close(SPKR) || die;

if (system("utils/utt2spk_to_spk2utt.pl $out_dir_enroll/utt2spk >$out_dir_enroll/spk2utt") != 0) {
  die "Error creating spk2utt file in directory $out_dir_enroll";
}
if (system("utils/utt2spk_to_spk2utt.pl $out_dir_test/utt2spk >$out_dir_test/spk2utt") != 0) {
  die "Error creating spk2utt file in directory $out_dir_test";
}
if (system("utils/fix_data_dir.sh $out_dir_enroll") != 0) {
  die "Error fixing data dir $out_dir_enroll";
}
if (system("utils/fix_data_dir.sh $out_dir_test") != 0) {
  die "Error fixing data dir $out_dir_test";
}
