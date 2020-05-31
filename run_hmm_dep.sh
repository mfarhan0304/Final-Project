#!/usr/bin/env bash
# Copyright      2017   David Snyder
#                2017   Johns Hopkins University (Author: Daniel Garcia-Romero)
#                2017   Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0.
#
# See README.txt for more info on data required.
# Results (mostly EERs) are inline in comments below.
#
# This example demonstrates a "bare bones" NIST SRE 2016 recipe using ivectors.
# It is closely based on "X-vectors: Robust DNN Embeddings for Speaker
# Recognition" by Snyder et al.  In the future, we will add score-normalization
# and a more effective form of PLDA domain adaptation.
#
# Pretrained models are available for this recipe.  See
# http://kaldi-asr.org/models.html and
# https://david-ryan-snyder.github.io/2017/10/04/model_sre16_v2.html
# for details.

. ./cmd.sh
. ./path.sh
set -e
mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc

# Trials
trials=data/eval_test/trials
trials_female=data/eval_test_female/trials
trials_male=data/eval_test_male/trials

nj=10
stage=4
gaus=128
var=250
if [ $stage -le 0 ]; then
  # Path to some, but not all of the training corpora
  data_root="./data/init"

  # Prepare Final Project evaluation data.
  local/prepare_dir.pl $data_root "train" ./data
  local/prepare_dir.pl $data_root "eval_enroll" ./data
  local/prepare_dir.pl $data_root "eval_test" ./data

  local/split_gender1.sh data/train data/eval_enroll data/eval_test
fi

if [ $stage -le 1 ]; then
  # Make MFCCs and compute the energy-based VAD for each dataset
  for name in train_female train_male eval_enroll_female eval_enroll_male eval_test_female eval_test_male; do
    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/${name} exp/make_mfcc $mfccdir
    steps/compute_cmvn_stats.sh data/${name} exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${name}
    sid/compute_vad_decision.sh --nj $nj --cmd "$train_cmd" data/${name} exp/make_vad $vaddir
    utils/fix_data_dir.sh data/${name}
  done
fi

if [ $stage -le 2 ]; then
  steps/train_mono.sh --boost-silence 1.25 --cmd "$train_cmd" \
    data/train_female data/lang exp/mono_female
  steps/align_si.sh --boost-silence 1.25 --cmd "$train_cmd" \
    data/train_female data/lang exp/mono_female exp/mono_ali_female

  steps/train_mono.sh --boost-silence 1.25 --cmd "$train_cmd" \
    data/train_male data/lang exp/mono_male
  steps/align_si.sh --boost-silence 1.25 --cmd "$train_cmd" \
    data/train_male data/lang exp/mono_male exp/mono_ali_male
fi

if [ $stage -le 3 ]; then
  # Train the UBM.
  steps/train_ubm.sh --cmd "$train_cmd" $gaus \
    data/train_female data/lang exp/mono_ali_female \
    exp/hmm_ubm_female

  steps/train_ubm.sh --cmd "$train_cmd" $gaus \
    data/train_male data/lang exp/mono_ali_male \
    exp/hmm_ubm_male
fi

if [ $stage -le 4 ]; then
  # Train the i-vector extractor
  sid/train_ivector_extractor.sh --cmd "$train_cmd" \
    --nj 1 --num-threads 8 --num-processes 8 \
    --ivector-dim $var \
    --num-iters 5 \
    exp/hmm_ubm_female/final.ubm data/train_female \
    exp/extractor_female

  sid/train_ivector_extractor.sh --cmd "$train_cmd" \
    --nj 1 --num-threads 8 --num-processes 8 \
    --ivector-dim $var \
    --num-iters 5 \
    exp/hmm_ubm_male/final.ubm data/train_male \
    exp/extractor_male
fi

if [ $stage -le 5 ]; then
  # Extract i-vectors for the data. We'll use this for things like LDA or PLDA.
  # The train data
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
    exp/extractor_female data/train_female \
    exp/ivectors_train_female
  # The eval enroll data
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
    exp/extractor_female data/eval_enroll_female \
    exp/ivectors_eval_enroll_female
  # The eval test data
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
    exp/extractor_female data/eval_test_female \
    exp/ivectors_eval_test_female

  # The train data
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
    exp/extractor_male data/train_male \
    exp/ivectors_train_male
  # The eval enroll data
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
    exp/extractor_male data/eval_enroll_male \
    exp/ivectors_eval_enroll_male
  # The eval test data
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
    exp/extractor_male data/eval_test_male \
    exp/ivectors_eval_test_male
fi

if [ $stage -le 6 ]; then
  $train_cmd exp/ivectors_train_female/log/compute_mean.log \
    ivector-mean scp:exp/ivectors_train_female/ivector.scp \
    exp/ivectors_train_female/mean.vec || exit 1;
  $train_cmd exp/ivectors_train_male/log/compute_mean.log \
    ivector-mean scp:exp/ivectors_train_male/ivector.scp \
    exp/ivectors_train_male/mean.vec || exit 1;
fi

if [ $stage -le 7 ]; then
  #  Create a gender independent PLDA model and do scoring
  local/plda_scoring.sh data/train_female data/eval_enroll_female data/eval_test_female \
    exp/ivectors_train_female exp/ivectors_eval_enroll_female exp/ivectors_eval_test_female $trials_female \
    exp/scores_dep_female
  local/plda_scoring.sh data/train_male data/eval_enroll_male data/eval_test_male \
    exp/ivectors_train_male exp/ivectors_eval_enroll_male exp/ivectors_eval_test_male $trials_male \
    exp/scores_dep_male

  # Pool the gender dependent results.
  mkdir -p exp/scores_dep_pooled
  cat exp/scores_dep_male/plda_scores exp/scores_dep_female/plda_scores \
      > exp/scores_dep_pooled/plda_scores
fi

if [ $stage -le 8 ]; then
  echo "HMM-dep EER"
  for x in dep; do
    for y in female male pooled; do
      eer=`compute-eer <(python local/prepare_for_eer.py $trials exp/scores_${x}_${y}/plda_scores) 2> exp/scores_${x}_${y}/plda_score.log`
      echo "${x} ${y}: $eer"
    done
  done
fi
