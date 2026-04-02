#!/bin/bash
# Run Gemma 4 26B MoE Q8 — recommended model for interactive use
# 81.6 tok/s generation, Q8 quality, flash attention enabled

LLAMA="$HOME/gemma4/llama.cpp/build/bin/llama-cli"
MODEL="$HOME/gemma4/gemma-4-26B-A4B-it-Q8_0.gguf"

# Optional: override model via argument
# Usage: ./run.sh [q4|q8|31b-q4|31b-q8|31b-spec-q4|31b-spec-q8]
case "$1" in
  q4)
    MODEL="$HOME/gemma4/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf"
    echo "Running 26B MoE Q4..."
    ;;
  31b-q8)
    MODEL="$HOME/gemma4/gemma-4-31B-it-Q8_0.gguf"
    echo "Running 31B Dense Q8 (highest quality, ~18 tok/s)..."
    ;;
  31b-q4)
    MODEL="$HOME/gemma4/gemma-4-31B-it-Q4_K_M.gguf"
    echo "Running 31B Dense Q4 (~27 tok/s)..."
    ;;
  31b-spec-q8)
    echo "Running 31B Dense Q8 + Speculative Decoding (~38 tok/s)..."
    exec "$HOME/gemma4/llama.cpp/build/bin/llama-speculative" \
      -m "$HOME/gemma4/gemma-4-31B-it-Q8_0.gguf" \
      -md "$HOME/gemma4/gemma-4-E2B-it-Q8_0.gguf" \
      -ngl 99 -ngld 99 \
      -cnv
    ;;
  31b-spec-q4)
    echo "Running 31B Dense Q4 + Speculative Decoding (~38 tok/s)..."
    exec "$HOME/gemma4/llama.cpp/build/bin/llama-speculative" \
      -m "$HOME/gemma4/gemma-4-31B-it-Q4_K_M.gguf" \
      -md "$HOME/gemma4/gemma-4-E2B-it-Q8_0.gguf" \
      -ngl 99 -ngld 99 \
      -cnv
    ;;
  ""|q8)
    echo "Running 26B MoE Q8 (recommended, ~82 tok/s)..."
    ;;
  *)
    echo "Usage: $0 [q4|q8|31b-q4|31b-q8|31b-spec-q4|31b-spec-q8]"
    echo ""
    echo "  q8 (default)   26B MoE Q8  — 81.6 tok/s, 25GB, recommended"
    echo "  q4             26B MoE Q4  — 84.8 tok/s, 15.7GB, slightly lower quality"
    echo "  31b-q8         31B Dense Q8 — 17.8 tok/s, 30.4GB, highest quality"
    echo "  31b-q4         31B Dense Q4 — 27.1 tok/s, 17.1GB"
    echo "  31b-spec-q8    31B Dense Q8 + Spec — 37.8 tok/s, best 31B speed"
    echo "  31b-spec-q4    31B Dense Q4 + Spec — 38.3 tok/s"
    exit 1
    ;;
esac

exec "$LLAMA" \
  -m "$MODEL" \
  -ngl 99 \
  -fa on \
  -cnv
