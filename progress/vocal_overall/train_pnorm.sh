#!/bin/bash

# This is p-norm neural net training, with the "fast" script, on top of adapted
# 40-dimensional features.

stage=1
train_stage=-10
use_gpu=true
numjob=4
lm=data/lang_lyric_exten
mdl=exp/paper/fmllr/tri3b_utt
ali=exp/paper/nnet/tri3b_ali_all_clean_utt
trainset=data/paper/train_clean_utt
testset=data/paper/test_clean_utt

. cmd.sh
. ./path.sh
. utils/parse_options.sh

if [ $stage -le -2 ]; then
  dataset=data/paper/all_clean_utt
  utils/combine_data.sh $dataset $trainset $testset
fi
if [ $stage -le -1 ]; then
  dataset=data/paper/all_clean_utt
  steps/align_fmllr.sh --nj $numjob --cmd "$train_cmd" \
    $dataset $lm $mdl $ali || exit 1;
fi

if $use_gpu; then
  if ! cuda-compiled; then
    cat <<EOF && exit 1 
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA 
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
  fi
  parallel_opts="--gpu 1"
  num_threads=1
  minibatch_size=512
  dir=exp/paper/nnet_valid/gpu_pnorm_utt_800_160
else
  # with just 4 jobs this might be a little slow.
  num_threads=8
  parallel_opts="--num-threads $num_threads" 
  minibatch_size=128
  dir=exp/paper/nnet/threads_pnorm_utt
fi

. ./cmd.sh
. utils/parse_options.sh

if [ ! -f $dir/final.mdl ]; then
  local/nnet2/train_pnorm_fast3.sh --stage $train_stage \
   --samples-per-iter 200000 \
   --parallel-opts "$parallel_opts" \
   --minibatch-size "$minibatch_size" \
   --num-jobs-nnet 8 \
   --initial-learning-rate 0.01 --final-learning-rate 0.001 \
   --num-hidden-layers 2 \
   --pnorm-input-dim 800 --pnorm-output-dim 160 \
   --num-epochs 15 \
   --splice-width 4 \
   --cmd "$decode_cmd" \
   $trainset $testset $lm $ali $dir || exit 1
fi

if [ $stage -le 1 ]; then
  utils/mkgraph.sh $lm\_test_tgsmall $mdl $mdl/graph_tgsmall || exit 1;
  steps/nnet2/decode.sh --nj $numjob --cmd "$decode_cmd" \
    --transform-dir $mdl/decode_fmllr_test_clean_tgsmall \
    $mdl/graph_tgsmall $testset $dir/decode_test_clean_tgsmall || exit 1;
  #steps/lmrescore.sh --cmd "$decode_cmd" $datadir/lang_lyric_test_{tgsmall,tgmed} \
    #$datadir/vocal/test_clean $dir/decode_vocal_test_clean_{tgsmall,tgmed} || exit 1;
fi

exit 0;
