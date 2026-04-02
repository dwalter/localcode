#!/bin/bash
# oc.sh — opencode with auto-managed llama-server
#
# - Starts llama-server (26B MoE Q8) if not already running
# - Shares the server across concurrent sessions
# - Shuts it down when the last session exits

SERVER_BIN="$HOME/gemma4/llama-cpp-turboquant/build/bin/llama-server"
MODEL="$HOME/gemma4/gemma-4-26B-A4B-it-Q8_0.gguf"
PORT=8080
SESSION_DIR="/tmp/gemma4-sessions"
SERVER_PID_FILE="/tmp/gemma4-server.pid"

mkdir -p "$SESSION_DIR"

# Register this session
SESSION_FILE="$SESSION_DIR/$$"
touch "$SESSION_FILE"

cleanup() {
    rm -f "$SESSION_FILE"

    # Count remaining sessions (excluding any stale PIDs)
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
    echo "Starting llama-server on :$PORT (26B MoE Q8)..."
    "$SERVER_BIN" \
        -m "$MODEL" \
        --host 127.0.0.1 --port "$PORT" \
        -ngl 99 -fa on --jinja \
        -ctk q8_0 -ctv turbo4 \
        -c 131072 \
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

/opt/homebrew/bin/opencode "$@"
