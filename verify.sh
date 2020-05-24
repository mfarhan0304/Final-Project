#!/usr/bin/env bash
. ./cmd.sh
. ./path.sh

set -e

if [ $# != 2 ]; then
  echo "Usage: $0 <id> <gender>"
fi

id=$1
gender=$2
threshold=-6.91388
rootdir=./apps/${id}/test
featsdir=${rootdir}/feats

mkdir -p $rootdir

cp ./apps/wav_verify.scp $rootdir/wav.scp
echo "${id} ${gender}" > $rootdir/spk2gender
echo "${id} test" > $rootdir/spk2utt
echo "${id} test target" > $rootdir/trial
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

local/plda_scoring.sh --use-existing-models true data/train ${rootdir}/../enroll ${rootdir} \
  exp/ivectors_train ${rootdir}/../enroll/feats ${featsdir} \
  "${id} test" ${rootdir}/scores

score=`awk '{print $NF}' ${rootdir}/scores/plda_scores`
if (( $(echo "$score >= $threshold" | bc -l) )); then
  echo "true";
else
  echo "false";
fi
#$train_cmd exp/convertion/log/feat_to_post.log \
#  feat-to-post scp:exp/ivectors_enroll/ivector.scp \
#  ark:exp/ivectors_enroll/ivector.post
#
##$train_cmd exp/adaptation/log/map_adapt.log \
## gmm-adapt-map --spk2utt=ark:${rootdir}/spk2utt \
## exp/full_ubm/final.ubm scp:exp/ivectors_enroll/ivector.scp \
## ark:exp/ivectors_enroll/ivectors.post \
## exp/maps/map_adapt
