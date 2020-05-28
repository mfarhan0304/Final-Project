#!/usr/bin/env bash
# Copyright 2015   David Snyder
# Apache 2.0.
#
# This script trains PLDA models and does scoring.

use_existing_models=false
use_lda=false
simple_length_norm=true # If true, replace the default length normalization
                         # performed in PLDA by an alternative that
                         # normalizes the length of the iVectors to be equal
                         # to the square root of the iVector dimension.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. utils/parse_options.sh || exit 1;

if [ $# != 8 ]; then
  echo "Usage: $0 <train-data-dir> <enroll-data-dir> <test-data-dir> <train-ivec-dir> <enroll-ivec-dir> <test-ivec-dir> <trials-file> <scores-dir>"
fi

train_data_dir=$1
enroll_data_dir=$2
test_data_dir=$3
train_ivec_dir=$4
enroll_ivec_dir=$5
test_ivec_dir=$6
trials=$7
scores_dir=$8

if [ "$use_existing_models" == "true" ]; then
  for f in ${train_ivec_dir}/mean.vec ${train_ivec_dir}/plda ; do
    [ ! -f $f ] && echo "No such file $f" && exit 1;
  done
else
  if [ "$use_lda" == "true" ]; then
    # Decrease the dimensionality prior to PLDA using LDA.
    $train_cmd $train_ivec_dir/log/lda.log \
      ivector-compute-lda --total-covariance-factor=0.0 --dim=88 \
      "ark:ivector-subtract-global-mean scp:${train_ivec_dir}/ivector.scp ark:- |" \
      ark:${train_data_dir}/utt2spk $train_ivec_dir/transform.mat || exit 1;

    $train_cmd $train_ivec_dir/log/plda.log \
      ivector-compute-plda ark:$train_data_dir/spk2utt \
      "ark:ivector-subtract-global-mean scp:${train_ivec_dir}/ivector.scp ark:- | transform-vec ${train_ivec_dir}/transform.mat ark:- ark:- | ivector-normalize-length ark:-  ark:- |" \
      $train_ivec_dir/plda || exit 1;
  else
    $train_cmd $train_ivec_dir/log/plda.log \
      ivector-compute-plda ark:$train_data_dir/spk2utt \
      "ark:ivector-normalize-length scp:${train_ivec_dir}/ivector.scp ark:- |" \
      $train_ivec_dir/plda || exit 1;
  fi
fi

if [ "$use_lda" == "true" ]; then
  $train_cmd $scores_dir/log/plda_scoring.log \
    ivector-plda-scoring --normalize-length=true \
    --simple-length-normalization=$simple_length_norm \
    --num-utts=ark:${enroll_ivec_dir}/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 ${train_ivec_dir}/plda - |" \
    "ark:ivector-mean ark:${enroll_data_dir}/spk2utt scp:${enroll_ivec_dir}/ivector.scp ark:- | ivector-subtract-global-mean ${train_ivec_dir}/mean.vec ark:- ark:- | transform-vec ${train_ivec_dir}/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-subtract-global-mean ${train_ivec_dir}/mean.vec scp:${test_ivec_dir}/ivector.scp ark:- | transform-vec ${train_ivec_dir}/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$trials' | cut -d\  --fields=1,2 |" $scores_dir/plda_scores || exit 1;
else
  $train_cmd $scores_dir/log/plda_scoring.log \
    ivector-plda-scoring --normalize-length=true \
    --simple-length-normalization=$simple_length_norm \
    --num-utts=ark:${enroll_ivec_dir}/num_utts.ark \
    "ivector-copy-plda --smoothing=0.0 ${train_ivec_dir}/plda - |" \
    "ark:ivector-subtract-global-mean ${train_ivec_dir}/mean.vec scp:${enroll_ivec_dir}/spk_ivector.scp ark:- | ivector-normalize-length ark:- ark:- |" \
    "ark:ivector-normalize-length scp:${test_ivec_dir}/ivector.scp ark:- | ivector-subtract-global-mean ${train_ivec_dir}/mean.vec ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
    "cat '$trials' | cut -d\  --fields=1,2 |" $scores_dir/plda_scores || exit 1;
fi
