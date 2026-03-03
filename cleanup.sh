#!/bin/bash
# Claude Mesh — Clean shutdown

MESH_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME="$MESH_DIR/runtime"

echo ""
echo "  CLAUDE MESH — SHUTTING DOWN"
echo "  ==========================="
echo ""

# Kill tmux sessions
tmux kill-session -t alpha 2>/dev/null && echo "  Killed tmux: alpha"
tmux kill-session -t beta 2>/dev/null && echo "  Killed tmux: beta"

# Kill by PID files
for pidfile in "$RUNTIME"/*.pid; do
    [ -f "$pidfile" ] || continue
    PID=$(cat "$pidfile")
    kill "$PID" 2>/dev/null && echo "  Killed PID $PID ($(basename "$pidfile" .pid))"
    rm -f "$pidfile"
done

# Fallback: kill by process name
pkill -f "server.py.*--name alpha" 2>/dev/null
pkill -f "server.py.*--name beta" 2>/dev/null
pkill -f "watcher.expect" 2>/dev/null

# Clean runtime files
rm -f "$RUNTIME"/*.json "$RUNTIME"/*.log "$RUNTIME"/last-check-*

echo ""
echo "  Mesh is offline. All clean."
echo "  ==========================="
echo ""
