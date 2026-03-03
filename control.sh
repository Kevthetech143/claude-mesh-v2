#!/bin/bash
# Claude Mesh — Interactive control panel

MESH_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNTIME="$MESH_DIR/runtime"

ALPHA_PORT="${ALPHA_PORT:-9997}"
BETA_PORT="${BETA_PORT:-9998}"

clear
echo ""
echo "  CLAUDE MESH — CONTROL PANEL"
echo "  ============================"
echo ""
echo "  1) Send message AS ALPHA -> BETA"
echo "  2) Send message AS BETA -> ALPHA"
echo "  3) View ALPHA inbox"
echo "  4) View BETA inbox"
echo "  5) Status check"
echo "  6) Cleanup & quit"
echo ""
echo "  ----------------------------"
echo ""

send_message() {
    local port=$1
    local author=$2
    local target=$3
    echo -n "  Type message: "
    read -r msg
    if [ -n "$msg" ]; then
        RESULT=$(curl -s -X POST "http://localhost:$port/api/submit" \
            -H "Content-Type: application/json" \
            -d "{\"author\": \"$author\", \"content\": \"$msg\"}" 2>&1)
        TIMESTAMP=$(date '+%H:%M:%S')
        echo "  [$TIMESTAMP] SENT as $author -> $target: $msg"
        echo "  Server response: $RESULT"
        echo "  [$TIMESTAMP] $author -> $target: $msg" >> "$RUNTIME/mesh-history.log"
    fi
    echo ""
}

view_inbox() {
    local port=$1
    local name=$2
    echo ""
    echo "  -- $name Inbox --"
    MESSAGES=$(curl -s "http://localhost:$port/api/all" 2>/dev/null)
    if [ -z "$MESSAGES" ] || [ "$MESSAGES" = "[]" ]; then
        echo "  (empty)"
    else
        echo "$MESSAGES" | python3 -c "
import sys, json
msgs = json.load(sys.stdin)
for i, m in enumerate(msgs, 1):
    print(f\"  {i}. [{m.get('received_at','?')[:19]}] {m.get('author','?')}: {m.get('content','?')}\")
" 2>/dev/null
    fi
    echo ""
}

status_check() {
    echo ""
    echo "  -- Status --"
    if curl -s "http://localhost:$ALPHA_PORT/api/latest" > /dev/null 2>&1; then
        echo "  ALPHA server ($ALPHA_PORT): ONLINE"
    else
        echo "  ALPHA server ($ALPHA_PORT): OFFLINE"
    fi
    if curl -s "http://localhost:$BETA_PORT/api/latest" > /dev/null 2>&1; then
        echo "  BETA server ($BETA_PORT): ONLINE"
    else
        echo "  BETA server ($BETA_PORT): OFFLINE"
    fi

    # Tmux sessions
    tmux has-session -t alpha 2>/dev/null && echo "  ALPHA tmux: ATTACHED" || echo "  ALPHA tmux: NOT FOUND"
    tmux has-session -t beta 2>/dev/null && echo "  BETA tmux: ATTACHED" || echo "  BETA tmux: NOT FOUND"

    echo ""
    if [ -f "$RUNTIME/mesh-history.log" ]; then
        LINES=$(wc -l < "$RUNTIME/mesh-history.log")
        echo "  Messages sent via control panel: $LINES"
    else
        echo "  Messages sent via control panel: 0"
    fi
    echo ""
}

while true; do
    echo -n "  [mesh] > "
    read -r choice
    case $choice in
        1) send_message "$BETA_PORT" "ALPHA" "BETA" ;;
        2) send_message "$ALPHA_PORT" "BETA" "ALPHA" ;;
        3) view_inbox "$ALPHA_PORT" "ALPHA" ;;
        4) view_inbox "$BETA_PORT" "BETA" ;;
        5) status_check ;;
        6|q|quit|exit) bash "$MESH_DIR/cleanup.sh"; exit 0 ;;
        *) echo "  Pick 1-6 or 'quit'" ; echo "" ;;
    esac
done
