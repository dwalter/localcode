#!/bin/bash
# oc.sh — opencode with auto-managed llama-server
#
# Starts llama-server if not already running, shares it across concurrent
# sessions, and shuts it down when the last session exits.
#
# Model selection via LOCALCODE_MODEL env var (default: gemma-26b):
#
#   opencode                         # Gemma 4 26B MoE Q8 (default)
#   LOCALCODE_MODEL=qwen-27b opencode
#   LOCALCODE_MODEL=qwen-35b-moe opencode
#   LOCALCODE_MODEL=qwopus opencode
#   LOCALCODE_MODEL=gemma-31b opencode

DIR="$HOME/localcode"
SERVER_BIN="$DIR/llama-cpp-turboquant/build/bin/llama-server"
PORT=8080
SESSION_DIR="/tmp/localcode-sessions"
SERVER_PID_FILE="/tmp/localcode-server.pid"

# Model selection
case "${LOCALCODE_MODEL:-gemma-26b}" in
  gemma-26b|"")
    MODEL="$DIR/gemma-4-26B-A4B-it-Q8_0.gguf"
    MODEL_LABEL="Gemma 4 26B MoE Q8"
    MODEL_FLAGS=""
    ;;
  gemma-31b)
    MODEL="$DIR/gemma-4-31B-it-TQ4_1S-config-i.gguf"
    MODEL_LABEL="Gemma 4 31B TQ4_1S"
    MODEL_FLAGS=""
    ;;
  qwen-27b)
    MODEL="$DIR/Qwen3.5-27B-Q4_K_M.gguf"
    MODEL_LABEL="Qwen3.5-27B Q4"
    MODEL_FLAGS="--chat-template-kwargs {\"enable_thinking\":false}"
    ;;
  qwen-35b-moe)
    MODEL="$DIR/Qwen3.5-35B-A3B-Q4_K_M.gguf"
    MODEL_LABEL="Qwen3.5-35B-A3B Q4 (MoE)"
    MODEL_FLAGS="--chat-template-kwargs {\"enable_thinking\":false}"
    ;;
  qwopus)
    MODEL="$DIR/Qwen3.5-27B-Qwopus-v2-Q4_K_M.gguf"
    MODEL_LABEL="Qwopus v2 27B Q4"
    MODEL_FLAGS="--chat-template-kwargs {\"enable_thinking\":true}"
    ;;
  *)
    echo "Unknown LOCALCODE_MODEL: ${LOCALCODE_MODEL}"
    echo "Options: gemma-26b (default), gemma-31b, qwen-27b, qwen-35b-moe, qwopus"
    exit 1
    ;;
esac

mkdir -p "$SESSION_DIR"

# Register this session
SESSION_FILE="$SESSION_DIR/$$"
touch "$SESSION_FILE"

cleanup() {
    rm -f "$SESSION_FILE"

    # Count remaining sessions (excluding stale PIDs)
    local remaining=0
    for f in "$SESSION_DIR"/*; do
        [[ -f "$f" ]] || continue
        local pid="${f##*/}"
        kill -0 "$pid" 2>/dev/null && remaining=$((remaining + 1))
    done

    if [[ "$remaining" -eq 0 && -f "$SERVER_PID_FILE" ]]; then
        local spid
        spid=$(cat "$SERVER_PID_FILE")
        if kill -0 "$spid" 2>/dev/null; then
            echo "Last session ended — stopping llama-server (pid $spid)"
            kill "$spid"
            wait "$spid" 2>/dev/null
        fi
        rm -f "$SERVER_PID_FILE"
    fi
}

trap cleanup EXIT

# Start server if port not already in use
if ! lsof -i ":$PORT" -sTCP:LISTEN -t &>/dev/null; then
    echo "Starting llama-server: $MODEL_LABEL on :$PORT"
    "$SERVER_BIN" \
        -m "$MODEL" \
        --host 127.0.0.1 --port "$PORT" \
        -ngl 99 -fa on --jinja \
        -ctk q8_0 -ctv turbo4 \
        -c 131072 \
        $MODEL_FLAGS \
        --log-disable &
    echo $! > "$SERVER_PID_FILE"

    echo -n "Waiting for model to load"
    for _ in $(seq 1 60); do
        if curl -sf "http://127.0.0.1:$PORT/health" &>/dev/null; then
            echo " ready"
            break
        fi
        sleep 1
        echo -n "."
    done
else
    echo "llama-server already running on :$PORT"
fi

command opencode "$@"
