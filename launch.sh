#!/bin/bash
# Claude Mesh — Main orchestrator
# Starts servers, Claude sessions, injects prompts, starts watchers

MESH_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME="$MESH_DIR/runtime"
PROMPTS="$MESH_DIR/prompts"

ALPHA_PORT="${ALPHA_PORT:-9997}"
BETA_PORT="${BETA_PORT:-9998}"

echo ""
echo "  CLAUDE MESH — PRE-FLIGHT"
echo "  ========================"
echo ""

FAIL=0

# Resolve claude's full path (tmux shells often miss PATH additions)
CLAUDE_BIN="$(command -v claude 2>/dev/null)"

# Dependency checks
python3 -c "import flask" 2>/dev/null && echo "  [OK] Flask" || { echo "  [FAIL] Flask"; FAIL=1; }
if [ -n "$CLAUDE_BIN" ]; then
    echo "  [OK] claude CLI ($CLAUDE_BIN)"
else
    echo "  [FAIL] claude CLI not found in PATH"
    FAIL=1
fi
command -v expect &>/dev/null && echo "  [OK] expect" || { echo "  [FAIL] expect"; FAIL=1; }
command -v tmux &>/dev/null && echo "  [OK] tmux" || { echo "  [FAIL] tmux"; FAIL=1; }

# Free ports if occupied
for PORT in $ALPHA_PORT $BETA_PORT; do
    if lsof -i ":$PORT" -sTCP:LISTEN &>/dev/null; then
        PID=$(lsof -ti ":$PORT" -sTCP:LISTEN)
        echo "  [WARN] Port $PORT in use (PID $PID) — killing..."
        kill "$PID" 2>/dev/null; sleep 1
        if lsof -i ":$PORT" -sTCP:LISTEN &>/dev/null; then
            echo "  [FAIL] Could not free port $PORT"; FAIL=1
        else
            echo "  [OK] Port $PORT freed"
        fi
    else
        echo "  [OK] Port $PORT available"
    fi
done

# Kill stale mesh processes
tmux kill-session -t alpha 2>/dev/null
tmux kill-session -t beta 2>/dev/null
pkill -f "server.py.*--name alpha" 2>/dev/null
pkill -f "server.py.*--name beta" 2>/dev/null
pkill -f "watcher.expect" 2>/dev/null
rm -f "$RUNTIME"/*
mkdir -p "$RUNTIME"
echo "  [OK] Stale processes cleaned"

if [ $FAIL -eq 1 ]; then
    echo ""; echo "  PRE-FLIGHT FAILED."; exit 1
fi

echo ""; echo "  ALL CHECKS PASSED"; echo ""

# ── Flask servers ──
echo "  Starting message servers..."
nohup python3 "$MESH_DIR/server.py" --port "$ALPHA_PORT" --name alpha --runtime-dir "$RUNTIME" \
    > "$RUNTIME/server-alpha.log" 2>&1 &
echo $! > "$RUNTIME/server-alpha.pid"

nohup python3 "$MESH_DIR/server.py" --port "$BETA_PORT" --name beta --runtime-dir "$RUNTIME" \
    > "$RUNTIME/server-beta.log" 2>&1 &
echo $! > "$RUNTIME/server-beta.pid"

sleep 2

curl -s "http://localhost:$ALPHA_PORT/api/latest" > /dev/null 2>&1 \
    && echo "  [OK] ALPHA inbox on $ALPHA_PORT" \
    || { echo "  [FAIL] ALPHA server"; exit 1; }
curl -s "http://localhost:$BETA_PORT/api/latest" > /dev/null 2>&1 \
    && echo "  [OK] BETA inbox on $BETA_PORT" \
    || { echo "  [FAIL] BETA server"; exit 1; }

# ── Claude sessions in tmux with prompt as CLI argument ──
echo ""
echo "  Launching Claude sessions with prompts..."

# Pass the initial prompt directly as a CLI argument — no send-keys timing issues
ALPHA_PROMPT="Read and follow the instructions in $PROMPTS/alpha.txt"
BETA_PROMPT="Read and follow the instructions in $PROMPTS/beta.txt"

tmux new-session -d -s alpha -x 200 -y 50
tmux send-keys -t alpha "unset CLAUDECODE && $CLAUDE_BIN --dangerously-skip-permissions \"$ALPHA_PROMPT\"" Enter

tmux new-session -d -s beta -x 200 -y 50
tmux send-keys -t beta "unset CLAUDECODE && $CLAUDE_BIN --dangerously-skip-permissions \"$BETA_PROMPT\"" Enter

echo "  [OK] ALPHA launching with prompt..."
echo "  [OK] BETA launching with prompt..."
echo "  Claude will boot and immediately process the prompt — no injection needed."

# ── Watchers ──
echo ""
echo "  Starting message watchers..."
nohup "$MESH_DIR/watcher.expect" "$ALPHA_PORT" alpha BETA "$RUNTIME" \
    > "$RUNTIME/watcher-alpha.log" 2>&1 &
echo $! > "$RUNTIME/watcher-alpha.pid"

nohup "$MESH_DIR/watcher.expect" "$BETA_PORT" beta ALPHA "$RUNTIME" \
    > "$RUNTIME/watcher-beta.log" 2>&1 &
echo $! > "$RUNTIME/watcher-beta.pid"

echo "  [OK] Watchers monitoring inboxes"

# ── Open terminal windows (macOS) or print instructions ──
echo ""
if [[ "$(uname)" == "Darwin" ]]; then
    echo "  Opening Terminal windows..."
    osascript -e 'tell application "Terminal"
      activate
      do script "tmux attach -t alpha"
    end tell' 2>/dev/null
    echo "  [1/2] ALPHA window opened"
    sleep 1
    osascript -e 'tell application "Terminal"
      activate
      do script "tmux attach -t beta"
    end tell' 2>/dev/null
    echo "  [2/2] BETA window opened"
else
    echo "  Attach to sessions manually:"
    echo "    tmux attach -t alpha"
    echo "    tmux attach -t beta"
fi

echo ""
echo "  ========================"
echo "  CLAUDE MESH IS LIVE"
echo "  ========================"
echo ""
echo "  ALPHA (port $ALPHA_PORT): Takes initiative, receives your instructions"
echo "  BETA  (port $BETA_PORT): Responds to ALPHA"
echo ""
echo "  Control panel: $MESH_DIR/control.sh"
echo "  Shutdown:      $MESH_DIR/cleanup.sh"
echo ""
