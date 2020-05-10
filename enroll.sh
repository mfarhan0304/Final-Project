#!/usr/bin/env bash
. ./cmd.sh
. ./path.sh

set -e

if [ $# != 2 ]; then
  echo "Usage: $0 <id> <gender>"
fi

id=$1
gender=$2
rootdir=./apps/${id}/enroll
featsdir=${rootdir}/feats

mkdir -p $rootdir

cp ./apps/wav_enroll.scp $rootdir/wav.scp
echo "${id} ${gender}" > $rootdir/spk2gender
echo "${id} enroll0 enroll1 enroll2 enroll3 enroll4" > $rootdir/spk2utt
utils/spk2utt_to_utt2spk.pl $rootdir/spk2utt > $rootdir/utt2spk


steps/make_mfcc.sh --nj 1 --cmd "$enroll_cmd" \
  ${rootdir} exp/make_mfcc ${featsdir}
steps/compute_cmvn_stats.sh ${rootdir} exp/make_mfcc ${featsdir}
utils/fix_data_dir.sh ${rootdir}
sid/compute_vad_decision.sh --nj 1 --cmd "$enroll_cmd" \
  ${rootdir} exp/make_vad ${featsdir}
utils/fix_data_dir.sh ${rootdir}

sid/extract_ivectors.sh --nj 1 --cmd "$enroll_cmd" \
  exp/extractor ${rootdir} ${featsdir}

echo $featsdir
#$train_cmd exp/convertion/log/feat_to_post.log \
#  feat-to-post scp:exp/ivectors_enroll/ivector.scp \
#  ark:exp/ivectors_enroll/ivector.post
#
##$train_cmd exp/adaptation/log/map_adapt.log \
## gmm-adapt-map --spk2utt=ark:${rootdir}/spk2utt \
## exp/full_ubm/final.ubm scp:exp/ivectors_enroll/ivector.scp \
## ark:exp/ivectors_enroll/ivectors.post \
## exp/maps/map_adapt
