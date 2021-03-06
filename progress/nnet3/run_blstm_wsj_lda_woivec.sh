#!/bin/bash

# This script is deprecated, see run_tdnn_lstm.sh

# this is a basic lstm script
# LSTM script runs for more epochs than the TDNN script
# and each epoch takes twice the time

# At this script level we don't support not running on GPU, as it would be painfully slow.
# If you want to run without GPU you'd have to call lstm/train.sh with --gpu false

stage=9
train_stage=-10
affix=
common_egs_dir=

# LSTM options
splice_indexes="-2,-1,0,1,2 0 0"
lstm_delay=" [-1,1] [-2,2] "
label_delay=5
num_lstm_layers=$4
cell_dim=$2
hidden_dim=$2
recurrent_projection_dim=$3
non_recurrent_projection_dim=$3
chunk_width=20
chunk_left_context=40
chunk_right_context=0

if [ $num_lstm_layers -eq 3 ]; then
  lstm_delay=" [-1,1] [-2,2] [-3,3] "
fi

if [ $num_lstm_layers -eq 4 ]; then
  lstm_delay=" [-1,1] [-2,2] [-3,3] [-4,4] "
fi

# training options
num_epochs=$1
initial_effective_lrate=0.0004
final_effective_lrate=0.000005
num_jobs_initial=2
num_jobs_final=2
momentum=0.5
num_chunk_per_minibatch=100
samples_per_iter=20000
remove_egs=true

#decode options
extra_left_context=
extra_right_context=
frames_per_chunk=

#End configuration section

echo "$0 $@" # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh


if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi
train_set=paper/train_clean_utt
test_sets=paper/test_clean_utt
gmm=paper/tri3b_utt        # this is the source gmm-dir that we'll use for alignments; it

gmm_dir=exp/${gmm}
ali_dir=exp/paper/tri3b_ali_utt_new
lang=data/lang_lyric_exten
train_data_dir=data/${train_set}
test_data_dir=data/${test_sets}
ali=1


dir=exp/nnet3/sp_exp/blstm/lda_woivec/layer${num_lstm_layers}_epoch${num_epochs}_celldim${cell_dim}_rp${3}_lr0.0004

if [ $label_delay -gt 0 ]; then dir=${dir}_ld$label_delay; fi

if [ $stage -le 7 ]; then
  steps/align_fmllr.sh $train_data_dir data/lang_lyric_exten $gmm_dir $ali_dir
fi



if [ $stage -le 8 ]; then
  steps/nnet3/lstm/train2.sh --stage $train_stage \
    --label-delay $label_delay \
    --lstm-delay "$lstm_delay" \
    --num-epochs $num_epochs --num-jobs-initial $num_jobs_initial --num-jobs-final $num_jobs_final \
    --num-chunk-per-minibatch $num_chunk_per_minibatch \
    --samples-per-iter $samples_per_iter \
    --splice-indexes "$splice_indexes" \
    --feat-type lda \
    --cmvn-opts "--norm-means=false --norm-vars=false" \
    --initial-effective-lrate $initial_effective_lrate --final-effective-lrate $final_effective_lrate \
    --momentum $momentum \
    --cmd "$decode_cmd" \
    --num-lstm-layers $num_lstm_layers \
    --cell-dim $cell_dim \
    --hidden-dim $hidden_dim \
    --recurrent-projection-dim $recurrent_projection_dim \
    --non-recurrent-projection-dim $non_recurrent_projection_dim \
    --chunk-width $chunk_width \
    --chunk-left-context $chunk_left_context \
    --chunk-right-context $chunk_right_context \
    --egs-dir "$common_egs_dir" \
    --remove-egs $remove_egs \
    $train_data_dir data/lang_lyric_exten $ali_dir $dir  || exit 1;
fi

if [ $stage -le 9 ]; then
  if [ -z $extra_left_context ]; then
    extra_left_context=$chunk_left_context
  fi
  if [ -z $extra_right_context ]; then
    extra_right_context=$chunk_right_context
  fi
  if [ -z $frames_per_chunk ]; then
    frames_per_chunk=$chunk_width
  fi
  graph_dir=$gmm_dir/graph_tgsmall
  # use already-built graphs
    num_jobs=4
    steps/nnet3/decode2.sh --nj $num_jobs --cmd "$decode_cmd" \
      --extra-left-context $extra_left_context \
      --extra-right-context $extra_right_context \
      --frames-per-chunk "$frames_per_chunk" \
      --transform-dir $gmm_dir/decode_fmllr_test_clean/ \
      $graph_dir $test_data_dir $dir/decode_fmllr || exit 1;
fi

