#!/bin/bash
# Run Gemma 4 models — chat or API server
#
# Usage: ./run.sh [mode]
#
#   q8 (default)   26B MoE Q8  — 82 tok/s, 25GB, recommended for chat
#   q4             26B MoE Q4  — 85 tok/s, 15.7GB
#   31b-q8         31B Dense Q8 — 18 tok/s, 30.4GB, highest quality
#   31b-q4         31B Dense Q4 — 28 tok/s, 17.1GB
#   31b-tq4        31B TQ4_1S  — 18 tok/s, 18.9GB (38% smaller, experimental)
#   31b-spec-q8    31B Q8 + Spec — 31 tok/s
#   31b-spec-q4    31B Q4 + Spec — 39 tok/s
#   server         26B MoE Q8 as API server on :8080 (for opencode)
#   server-31b     31B TQ4_1S  as API server on :8080

SERVER="$HOME/gemma4/llama-cpp-turboquant/build/bin/llama-server"
LLAMA="$HOME/gemma4/llama.cpp/build/bin/llama-cli"
SPEC="$HOME/gemma4/llama.cpp/build/bin/llama-speculative"
MODEL="$HOME/gemma4/gemma-4-26B-A4B-it-Q8_0.gguf"

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
    echo "Running 31B Dense Q4 (~28 tok/s)..."
    ;;
  31b-tq4)
    MODEL="$HOME/gemma4/gemma-4-31B-it-TQ4_1S-config-i.gguf"
    echo "Running 31B TQ4_1S (~18 tok/s, 18.9GB)..."
    ;;
  31b-spec-q8)
    echo "Running 31B Dense Q8 + Speculative Decoding (~31 tok/s)..."
    exec "$SPEC" \
      -m "$HOME/gemma4/gemma-4-31B-it-Q8_0.gguf" \
      -md "$HOME/gemma4/gemma-4-E2B-it-Q8_0.gguf" \
      -ngl 99 -ngld 99 \
      -cnv
    ;;
  31b-spec-q4)
    echo "Running 31B Dense Q4 + Speculative Decoding (~39 tok/s)..."
    exec "$SPEC" \
      -m "$HOME/gemma4/gemma-4-31B-it-Q4_K_M.gguf" \
      -md "$HOME/gemma4/gemma-4-E2B-it-Q8_0.gguf" \
      -ngl 99 -ngld 99 \
      -cnv
    ;;
  server)
    echo "Starting API server: 26B MoE Q8 on http://127.0.0.1:8080"
    echo "OpenAI-compat: http://127.0.0.1:8080/v1"
    echo "Then run: opencode"
    exec "$SERVER" \
      -m "$HOME/gemma4/gemma-4-26B-A4B-it-Q8_0.gguf" \
      --host 127.0.0.1 --port 8080 \
      -ngl 99 -fa on --jinja \
      -ctk q8_0 -ctv turbo4 \
      -c 131072
    ;;
  server-31b)
    echo "Starting API server: 31B TQ4_1S on http://127.0.0.1:8080"
    echo "OpenAI-compat: http://127.0.0.1:8080/v1"
    exec "$SERVER" \
      -m "$HOME/gemma4/gemma-4-31B-it-TQ4_1S-config-i.gguf" \
      --host 127.0.0.1 --port 8080 \
      -ngl 99 -fa on --jinja \
      -ctk q8_0 -ctv turbo4 \
      -c 131072
    ;;
  ""|q8)
    echo "Running 26B MoE Q8 (recommended, ~82 tok/s)..."
    ;;
  *)
    echo "Usage: $0 [q4|q8|31b-q4|31b-q8|31b-tq4|31b-spec-q4|31b-spec-q8|server|server-31b]"
    exit 1
    ;;
esac

exec "$LLAMA" \
  -m "$MODEL" \
  -ngl 99 \
  -fa on \
  -cnv
