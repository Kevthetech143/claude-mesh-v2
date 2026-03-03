#!/bin/bash
# Claude Mesh — Auto-installer
# Assumes Claude Code CLI is already installed

MESH_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  CLAUDE MESH — INSTALLER"
echo "  ========================"
echo ""

# Detect package manager
if [[ "$(uname)" == "Darwin" ]]; then
    PKG="brew"
    if ! command -v brew &>/dev/null; then
        echo "  [WARN] Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
else
    PKG="apt"
fi

# Auto-install missing deps
install_if_missing() {
    local cmd=$1
    local brew_pkg=$2
    local apt_pkg=$3
    if command -v "$cmd" &>/dev/null; then
        echo "  [OK] $cmd"
    else
        echo "  [..] Installing $cmd..."
        if [[ "$PKG" == "brew" ]]; then
            brew install "$brew_pkg" 2>/dev/null && echo "  [OK] $cmd installed" || echo "  [FAIL] $cmd"
        else
            sudo apt-get install -y "$apt_pkg" 2>/dev/null && echo "  [OK] $cmd installed" || echo "  [FAIL] $cmd"
        fi
    fi
}

# Python + Flask
if python3 -c "import flask" 2>/dev/null; then
    echo "  [OK] Flask"
else
    echo "  [..] Installing Flask..."
    pip3 install flask 2>/dev/null && echo "  [OK] Flask installed" || echo "  [FAIL] Flask — run: pip3 install flask"
fi

# Claude CLI (just check, don't install)
command -v claude &>/dev/null && echo "  [OK] claude CLI" || echo "  [!!] claude CLI not found — install from https://docs.anthropic.com/en/docs/claude-code/overview"

# System tools
install_if_missing tmux tmux tmux
install_if_missing expect expect expect
install_if_missing curl curl curl

echo ""

# Create runtime dir
mkdir -p "$MESH_DIR/runtime"
echo "  [OK] runtime/ directory ready"

# Make scripts executable
chmod +x "$MESH_DIR/launch.sh" "$MESH_DIR/cleanup.sh" "$MESH_DIR/control.sh" "$MESH_DIR/watcher.expect" 2>/dev/null
echo "  [OK] Scripts marked executable"

# Copy mesh-sync skill to user's Claude skills dir
SKILL_SRC="$MESH_DIR/skills/mesh-sync/SKILL.md"
SKILL_DST="$HOME/.claude/skills/mesh-sync/SKILL.md"
if [ -f "$SKILL_SRC" ]; then
    mkdir -p "$(dirname "$SKILL_DST")"
    cp "$SKILL_SRC" "$SKILL_DST"
    echo "  [OK] mesh-sync skill installed to ~/.claude/skills/"
fi

echo ""
echo "  INSTALL COMPLETE. Run: ./launch.sh"
echo ""
