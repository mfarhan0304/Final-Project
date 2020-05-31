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
stage=8
if [ $stage -le 0 ]; then
  # Path to some, but not all of the training corpora
  data_root="./data/init"

  # Prepare Final Project evaluation data.
  local/prepare_dir.pl $data_root "train" ./data
  local/prepare_dir.pl $data_root "eval_enroll" ./data
  local/prepare_dir.pl $data_root "eval_test" ./data
fi

if [ $stage -le 1 ]; then
  # Make MFCCs and compute the energy-based VAD for each dataset
  for name in train eval_enroll eval_test; do
    steps/make_mfcc.sh --nj $nj --cmd "$train_cmd" data/${name} exp/make_mfcc $mfccdir
    steps/compute_cmvn_stats.sh data/${name} exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${name}
    sid/compute_vad_decision.sh --nj $nj --cmd "$train_cmd" data/${name} exp/make_vad $vaddir
    utils/fix_data_dir.sh data/${name}
  done
fi

if [ $stage -le 2 ]; then
  steps/train_mono.sh --boost-silence 1.25 --cmd "$train_cmd" \
    data/train data/lang exp/mono
  steps/align_si.sh --boost-silence 1.25 --cmd "$train_cmd" \
    data/train data/lang exp/mono exp/mono_ali
fi

if [ $stage -le 3 ]; then
  # Train the UBM.
  steps/train_ubm.sh --cmd "$train_cmd" 128 \
    data/train data/lang exp/mono_ali \
    exp/hmm_ubm
fi

if [ $stage -le 4 ]; then
  # Train the i-vector extractor
  sid/train_ivector_extractor.sh --cmd "$train_cmd" \
    --nj 1 --num-threads 8 --num-processes 8 \
    --ivector-dim 250 \
    --num-iters 5 \
    exp/hmm_ubm/final.ubm data/train \
    exp/extractor
fi

if [ $stage -le 5 ]; then
  # Extract i-vectors for the data. We'll use this for things like LDA or PLDA.
  # The train data
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
    exp/extractor data/train \
    exp/ivectors_train

  # The eval enroll data
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
    exp/extractor data/eval_enroll \
    exp/ivectors_eval_enroll

  # The eval test data
  sid/extract_ivectors.sh --cmd "$train_cmd" --nj $nj \
    exp/extractor data/eval_test \
    exp/ivectors_eval_test
fi

if [ $stage -le 6 ]; then
  local/split_gender.sh data/train data/eval_enroll data/eval_test \
    exp/ivectors_train exp/ivectors_eval_enroll exp/ivectors_eval_test
fi

if [ $stage -le 6 ]; then
  #  Create a gender independent PLDA model and do scoring
  local/plda_scoring.sh data/train data/eval_enroll data/eval_test \
    exp/ivectors_train exp/ivectors_eval_enroll exp/ivectors_eval_test $trials \
    exp/scores_ind_pooled
  local/plda_scoring.sh --use-existing-models true data/train data/eval_enroll_female data/eval_test_female \
    exp/ivectors_train exp/ivectors_eval_enroll_female exp/ivectors_eval_test_female $trials_female \
    exp/scores_ind_female
  local/plda_scoring.sh --use-existing-models true data/train data/eval_enroll_male data/eval_test_male \
    exp/ivectors_train exp/ivectors_eval_enroll_male exp/ivectors_eval_test_male $trials_male \
    exp/scores_ind_male
fi

if [ $stage -le 7 ]; then
  #  Create a gender independent PLDA model and do scoring
  local/cosine_scoring.sh data/eval_enroll data/eval_test \
    exp/ivectors_eval_enroll exp/ivectors_eval_test $trials \
    exp/scores_ind_pooled
  local/cosine_scoring.sh data/eval_enroll_female data/eval_test_female \
    exp/ivectors_eval_enroll_female exp/ivectors_eval_test_female $trials_female \
    exp/scores_ind_female
  local/cosine_scoring.sh data/eval_enroll_male data/eval_test_male \
    exp/ivectors_eval_enroll_male exp/ivectors_eval_test_male $trials_male \
    exp/scores_ind_male
fi

if [ $stage -le 8 ]; then
  echo "HMM-ind EER"
  for x in ind; do
    for y in female male pooled; do
      eer=`compute-eer <(python local/prepare_for_eer.py $trials exp/scores_${x}_${y}/cosine_scores) 2> exp/scores_${x}_${y}/cosine_score.log`
      echo "${x} ${y}: $eer"
    done
  done
fi
