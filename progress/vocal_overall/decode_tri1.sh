. path.sh
. cmd.sh

model=$1
testset=$2
numjob=$3

lm=data/lang_lyric_exten

if [[ "$model" != *"tri1"* ]]; then
  echo "$model is not tri1 model"
  exit 1;
fi

utils/mkgraph.sh \
  $lm\_test_tgsmall $model $model/graph_tgsmall || exit 1;
steps/decode.sh --nj $numjob --cmd "$decode_cmd" \
  $model/graph_tgsmall $testset \
  $model/decode_test_clean_tgsmall || exit 1;

grep WER $model/decode_test_clean_tgsmall/wer* | utils/best_wer.sh
