#!/usr/bin/perl
use warnings; #sed replacement for -w perl parameter
# Copyright 2017   David Snyder
# Apache 2.0
#

if (@ARGV != 3) {
  print STDERR "Usage: $0 <path-to-input> <dir-type> <path-to-output>\n";
  print STDERR "e.g. $0 ./data/init 'train' ./data\n";
  exit(1);
}

($db_base, $dir_type, $out_dir) = @ARGV;

# Handle enroll
$out_dir = "$out_dir/$dir_type";
if (system("mkdir -p $out_dir")) {
  die "Error making directory $out_dir";
}

$tmp_dir = "$out_dir/tmp";
if (system("mkdir -p $tmp_dir") != 0) {
  die "Error making directory $tmp_dir";
}

open(GNDR, ">$out_dir/spk2gender") || die "Could not open the output file $out_dir/spk2gender";
open(SPKR, ">$out_dir/utt2spk") || die "Could not open the output file $out_dir/utt2spk";
open(WAV, ">$out_dir/wav.scp") || die "Could not open the output file $out_dir/wav.scp";
open(TXT, ">$out_dir/text") || die "Could not open the output file $out_dir/text";

if (system("cp $db_base/docs/wav_$dir_type.sph $tmp_dir/sph.list") != 0) {
  die "Error getting list of sph files";
}

open(WAVLIST, "<$tmp_dir/sph.list") or die "cannot open wav list";

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

if ($dir_type eq "eval_test") {
    open(TRL, ">$out_dir/trials") || die "Could not open the output file $out_dir_test/trials";
    open(SPKR, "<$out_dir/utt2spk") || die "Could not open the output file $out_dir_test/utt2spk";

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
}


if (system("utils/utt2spk_to_spk2utt.pl $out_dir/utt2spk >$out_dir/spk2utt") != 0) {
  die "Error creating spk2utt file in directory $out_dir";
}
if (system("utils/fix_data_dir.sh $out_dir") != 0) {
  die "Error fixing data dir $out_dir";
}
