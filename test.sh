#!/bin/bash
. ./cmd.sh
. ./path.sh

# Acoustic model parameters
numLeavesTri1=2500
numGaussTri1=15000
numLeavesMLLT=2500
numGaussMLLT=15000
numLeavesSAT=2500
numGaussSAT=15000
numGaussUBM=400
numLeavesSGMM=7000
numGaussSGMM=9000

feats_nj=10
train_nj=10
decode_nj=6

<< com
echo ============================================================================
echo "                Data & Lexicon & Language Preparation                     "
echo ============================================================================

local/Ti_data_prep.sh $wavedir data 500 100 || exit 1;

local/timit_prepare_dict.sh || exit 1;

utils/prepare_lang.sh --position-dependent-phones false data/local/dict 'sil' data/local/lang data/lang || exit 1;

local/Ti_format_data.sh || exit 1



echo ============================================================================
echo "         MFCC Feature Extration & CMVN for Training and Test set          "
echo ============================================================================

# Now make MFCC features.
mfccdir=mfcc

for x in train dev test; do 
  steps/make_mfcc_pitch.sh --cmd "$train_cmd" --nj $feats_nj data/$x exp/make_mfcc/$x $mfccdir
  steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir
done
com

echo ============================================================================
echo "                     MonoPhone Training & Decoding                        "
echo ============================================================================

utils/subset_data_dir.sh data/train 25000 data/train.25000  || exit 1;

steps/train_mono.sh --boost-silence 1.25 --nj "$train_nj" --cmd "$train_cmd" data/train.25000 data/lang exp/mono || exit 1;

utils/mkgraph.sh --mono data/lang_test_bg exp/mono exp/mono/graph

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/mono/graph data/dev exp/mono/decode_dev

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/mono/graph data/test exp/mono/decode_test
 


echo ============================================================================
echo "           tri1 : Deltas + Delta-Deltas Training & Decoding               "
echo ============================================================================

steps/align_si.sh --boost-silence 1.25 --nj "$train_nj" --cmd "$train_cmd" \
 data/train data/lang exp/mono exp/mono_ali

# Train tri1, which is deltas + delta-deltas, on train data.
steps/train_deltas.sh --cmd "$train_cmd" \
 $numLeavesTri1 $numGaussTri1 data/train data/lang exp/mono_ali exp/tri1

utils/mkgraph.sh data/lang_test_bg exp/tri1 exp/tri1/graph

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri1/graph data/dev exp/tri1/decode_dev

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri1/graph data/test exp/tri1/decode_test
 

echo ============================================================================
echo "                 tri2 : LDA + MLLT Training & Decoding                    "
echo ============================================================================

steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
  data/train data/lang exp/tri1 exp/tri1_ali

steps/train_lda_mllt.sh --cmd "$train_cmd" \
 --splice-opts "--left-context=3 --right-context=3" \
 $numLeavesMLLT $numGaussMLLT data/train data/lang exp/tri1_ali exp/tri2

utils/mkgraph.sh data/lang_test_bg exp/tri2 exp/tri2/graph

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri2/graph data/dev exp/tri2/decode_dev

steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri2/graph data/test exp/tri2/decode_test

echo ============================================================================
echo "              tri3 : LDA + MLLT + SAT Training & Decoding                 "
echo ============================================================================

# Align tri2 system with train data.
steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" \
 --use-graphs true data/train data/lang exp/tri2 exp/tri2_ali

# From tri2 system, train tri3 which is LDA + MLLT + SAT.
steps/train_sat.sh --cmd "$train_cmd" \
 $numLeavesSAT $numGaussSAT data/train data/lang exp/tri2_ali exp/tri3

utils/mkgraph.sh data/lang_test_bg exp/tri3 exp/tri3/graph

steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri3/graph data/dev exp/tri3/decode_dev

steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" \
 exp/tri3/graph data/test exp/tri3/decode_test


#sat_ali
steps/align_fmllr.sh --nj $train_nj --cmd "$train_cmd" data/train data/lang exp/tri3 exp/tri3_ali || exit 1;

#quick
steps/train_quick.sh --cmd "$train_cmd" 4200 40000 data/train data/lang exp/tri3_ali exp/tri4 || exit 1;

utils/mkgraph.sh data/lang_test_bg exp/tri4 exp/tri4/graph  || exit 1;

#test tri4 model
steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" exp/tri4/graph data/test exp/tri4/decode_test
steps/decode_fmllr.sh --nj "$decode_nj" --cmd "$decode_cmd" exp/tri4/graph data/dev exp/tri4/decode_dev


# DNN with pre-training
#quick_ali
steps/align_fmllr.sh --nj $train_nj --cmd "$train_cmd" data/train data/lang exp/tri4 exp/tri4_ali || exit 1;
local/nnet/run_dnn.sh
