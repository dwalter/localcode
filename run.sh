#!/bin/bash
# Run local models — chat or API server
#
# Usage: ./run.sh [mode]
#
# --- Gemma 4 ---
#   q8 (default)      Gemma 4 26B MoE Q8    — 82 tok/s,  25.0G
#   q4                Gemma 4 26B MoE Q4    — 85 tok/s,  15.7G
#   31b-q8            Gemma 4 31B Dense Q8  — 18 tok/s,  30.4G  (highest quality)
#   31b-q4            Gemma 4 31B Dense Q4  — 28 tok/s,  17.1G
#   31b-tq4           Gemma 4 31B TQ4_1S   — 18 tok/s,  18.9G  (38% smaller, experimental)
#   31b-spec-q8       Gemma 4 31B Q8 + Spec — 31 tok/s
#   31b-spec-q4       Gemma 4 31B Q4 + Spec — 39 tok/s
#
# --- Qwen3.5 ---
#   qwen-9b           Qwen3.5-9B Q8         —  ~80 tok/s,  9.5G
#   qwen-27b          Qwen3.5-27B Q4        —  ~28 tok/s, 16.7G  (thinking off)
#   qwen-27b-think    Qwen3.5-27B Q4        —  ~28 tok/s, 16.7G  (thinking on)
#   qwen-35b-moe      Qwen3.5-35B-A3B Q4   — ~fast,      21.4G  (3B active params)
#   qwopus            Qwopus v2 27B Q4      —  ~28 tok/s, 16.5G  (Opus-distilled)
#
# --- API servers (for opencode) ---
#   server            Gemma 4 26B MoE Q8    (default, recommended)
#   server-31b        Gemma 4 31B TQ4_1S
#   server-qwen-27b   Qwen3.5-27B Q4
#   server-qwen-moe   Qwen3.5-35B-A3B Q4
#   server-qwopus     Qwopus v2 27B Q4

DIR="$HOME/localcode"
SERVER="$DIR/llama-cpp-turboquant/build/bin/llama-server"
LLAMA="$DIR/llama.cpp/build/bin/llama-cli"
SPEC="$DIR/llama.cpp/build/bin/llama-speculative"

# Defaults (Gemma 4 26B MoE Q8, no special flags)
MODEL="$DIR/gemma-4-26B-A4B-it-Q8_0.gguf"
EXTRA_FLAGS=""

server_start() {
    local model="$1"; shift
    local label="$1"; shift
    echo "Starting API server: $label on http://127.0.0.1:8080"
    exec "$SERVER" \
      -m "$model" \
      --host 127.0.0.1 --port 8080 \
      -ngl 99 -fa on --jinja \
      -ctk q8_0 -ctv turbo4 \
      -c 131072 \
      "$@"
}

case "$1" in
  # --- Gemma 4 chat ---
  ""|q8)
    echo "Gemma 4 26B MoE Q8 (~82 tok/s)..."
    ;;
  q4)
    MODEL="$DIR/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf"
    echo "Gemma 4 26B MoE Q4 (~85 tok/s)..."
    ;;
  31b-q8)
    MODEL="$DIR/gemma-4-31B-it-Q8_0.gguf"
    echo "Gemma 4 31B Dense Q8 (~18 tok/s)..."
    ;;
  31b-q4)
    MODEL="$DIR/gemma-4-31B-it-Q4_K_M.gguf"
    echo "Gemma 4 31B Dense Q4 (~28 tok/s)..."
    ;;
  31b-tq4)
    MODEL="$DIR/gemma-4-31B-it-TQ4_1S-config-i.gguf"
    echo "Gemma 4 31B TQ4_1S (~18 tok/s, 18.9GB)..."
    ;;
  31b-spec-q8)
    echo "Gemma 4 31B Q8 + Speculative (~31 tok/s)..."
    exec "$SPEC" \
      -m "$DIR/gemma-4-31B-it-Q8_0.gguf" \
      -md "$DIR/gemma-4-E2B-it-Q8_0.gguf" \
      -ngl 99 -ngld 99 -cnv
    ;;
  31b-spec-q4)
    echo "Gemma 4 31B Q4 + Speculative (~39 tok/s)..."
    exec "$SPEC" \
      -m "$DIR/gemma-4-31B-it-Q4_K_M.gguf" \
      -md "$DIR/gemma-4-E2B-it-Q8_0.gguf" \
      -ngl 99 -ngld 99 -cnv
    ;;

  # --- Qwen3.5 chat ---
  qwen-9b)
    MODEL="$DIR/Qwen3.5-9B-Q8_0.gguf"
    EXTRA_FLAGS="--jinja --chat-template-kwargs {\"enable_thinking\":false}"
    echo "Qwen3.5-9B Q8 (~80 tok/s)..."
    ;;
  qwen-27b)
    MODEL="$DIR/Qwen3.5-27B-Q4_K_M.gguf"
    EXTRA_FLAGS="--jinja --chat-template-kwargs {\"enable_thinking\":false}"
    echo "Qwen3.5-27B Q4 (~28 tok/s, thinking off)..."
    ;;
  qwen-27b-think)
    MODEL="$DIR/Qwen3.5-27B-Q4_K_M.gguf"
    EXTRA_FLAGS="--jinja --chat-template-kwargs {\"enable_thinking\":true}"
    echo "Qwen3.5-27B Q4 (~28 tok/s, thinking on)..."
    ;;
  qwen-35b-moe)
    MODEL="$DIR/Qwen3.5-35B-A3B-Q4_K_M.gguf"
    EXTRA_FLAGS="--jinja --chat-template-kwargs {\"enable_thinking\":false}"
    echo "Qwen3.5-35B-A3B Q4 (3B active params)..."
    ;;
  qwopus)
    MODEL="$DIR/Qwen3.5-27B-Qwopus-v2-Q4_K_M.gguf"
    EXTRA_FLAGS="--jinja --chat-template-kwargs {\"enable_thinking\":true}"
    echo "Qwopus v2 27B Q4 (Opus-distilled reasoning)..."
    ;;

  # --- API servers ---
  server)
    server_start "$DIR/gemma-4-26B-A4B-it-Q8_0.gguf" "Gemma 4 26B MoE Q8"
    ;;
  server-31b)
    server_start "$DIR/gemma-4-31B-it-TQ4_1S-config-i.gguf" "Gemma 4 31B TQ4_1S"
    ;;
  server-qwen-27b)
    server_start "$DIR/Qwen3.5-27B-Q4_K_M.gguf" "Qwen3.5-27B Q4" \
      --chat-template-kwargs '{"enable_thinking":false}'
    ;;
  server-qwen-moe)
    server_start "$DIR/Qwen3.5-35B-A3B-Q4_K_M.gguf" "Qwen3.5-35B-A3B Q4 (MoE)" \
      --chat-template-kwargs '{"enable_thinking":false}'
    ;;
  server-qwopus)
    server_start "$DIR/Qwen3.5-27B-Qwopus-v2-Q4_K_M.gguf" "Qwopus v2 27B Q4" \
      --chat-template-kwargs '{"enable_thinking":true}'
    ;;

  *)
    echo "Usage: $0 [mode]"
    echo ""
    echo "Gemma 4:  q8 (default) | q4 | 31b-q8 | 31b-q4 | 31b-tq4 | 31b-spec-q8 | 31b-spec-q4"
    echo "Qwen3.5:  qwen-9b | qwen-27b | qwen-27b-think | qwen-35b-moe | qwopus"
    echo "Servers:  server | server-31b | server-qwen-27b | server-qwen-moe | server-qwopus"
    exit 1
    ;;
esac

exec "$LLAMA" \
  -m "$MODEL" \
  -ngl 99 -fa on \
  $EXTRA_FLAGS \
  -cnv
