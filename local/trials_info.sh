echo 'All'
awk '{count[$3]++} END {for (word in count) print word, count[word]}' data/eval_test/trials

echo 'Female'
awk '{count[$3]++} END {for (word in count) print word, count[word]}' data/eval_test_female/trials

echo 'Male'
awk '{count[$3]++} END {for (word in count) print word, count[word]}' data/eval_test_male/trials
