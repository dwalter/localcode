#!/bin/bash
# Benchmark all Gemma 4 models with flash attention
# Results are comparable to those in README.md

BENCH="$HOME/gemma4/llama.cpp/build/bin/llama-bench"
SPEC="$HOME/gemma4/llama.cpp/build/bin/llama-speculative"
DIR="$HOME/gemma4"

N_PROMPT=512
N_GEN=200

echo "============================================"
echo " Gemma 4 Benchmark — M3 Ultra"
echo " Prompt tokens: $N_PROMPT | Gen tokens: $N_GEN"
echo "============================================"
echo ""

echo "--- Base models (flash attention) ---"
$BENCH \
  -m "$DIR/gemma-4-26B-A4B-it-Q8_0.gguf" \
  -m "$DIR/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf" \
  -m "$DIR/gemma-4-31B-it-Q8_0.gguf" \
  -m "$DIR/gemma-4-31B-it-Q4_K_M.gguf" \
  -ngl 99 -fa 1 -p $N_PROMPT -n $N_GEN

echo ""
echo "--- 31B Dense + Speculative Decoding (E2B Q8 draft) ---"

PROMPT="Write a detailed and comprehensive implementation of a binary search tree in Python, including insert, delete, search, and traversal methods."

echo "31B Q8 + Spec:"
$SPEC \
  -m "$DIR/gemma-4-31B-it-Q8_0.gguf" \
  -md "$DIR/gemma-4-E2B-it-Q8_0.gguf" \
  -ngl 99 -ngld 99 -n $N_GEN -p "$PROMPT" 2>&1 | grep -E "decoded|llama_perf"

echo ""
echo "31B Q4 + Spec:"
$SPEC \
  -m "$DIR/gemma-4-31B-it-Q4_K_M.gguf" \
  -md "$DIR/gemma-4-E2B-it-Q8_0.gguf" \
  -ngl 99 -ngld 99 -n $N_GEN -p "$PROMPT" 2>&1 | grep -E "decoded|llama_perf"
