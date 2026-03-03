#!/bin/bash
# Claude Mesh — Auto-installer
# Assumes Claude Code CLI is already installed

MESH_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  CLAUDE MESH — INSTALLER"
echo "  ========================"
echo ""

# Detect OS and package manager
OS="$(uname)"
if [[ "$OS" == "Darwin" ]]; then
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

# Python — try python3 first, fall back to python
PYTHON_BIN=""
if command -v python3 &>/dev/null; then
    PYTHON_BIN="python3"
elif command -v python &>/dev/null; then
    PYTHON_BIN="python"
else
    echo "  [FAIL] Python not found"
    install_if_missing python3 python3 python3
    PYTHON_BIN="python3"
fi
echo "  [OK] Python ($PYTHON_BIN)"

# Flask
if $PYTHON_BIN -c "import flask" 2>/dev/null; then
    echo "  [OK] Flask"
else
    echo "  [..] Installing Flask..."
    # Try pip3, pip, then python -m pip
    if command -v pip3 &>/dev/null; then
        pip3 install flask 2>/dev/null && echo "  [OK] Flask installed"
    elif command -v pip &>/dev/null; then
        pip install flask 2>/dev/null && echo "  [OK] Flask installed"
    else
        $PYTHON_BIN -m pip install flask 2>/dev/null && echo "  [OK] Flask installed" || echo "  [FAIL] Flask — run: pip install flask"
    fi
fi

# Claude CLI (just check, don't install)
command -v claude &>/dev/null && echo "  [OK] claude CLI" || echo "  [!!] claude CLI not found — install from https://docs.anthropic.com/en/docs/claude-code/overview"

# System tools
install_if_missing tmux tmux tmux
install_if_missing expect expect expect
install_if_missing curl curl curl
install_if_missing lsof lsof lsof

echo ""

# Create runtime dir
mkdir -p "$MESH_DIR/runtime"
echo "  [OK] runtime/ directory ready"

# Make scripts executable
chmod +x "$MESH_DIR/launch.sh" "$MESH_DIR/cleanup.sh" "$MESH_DIR/control.sh" "$MESH_DIR/watcher.expect" 2>/dev/null
echo "  [OK] Scripts marked executable"

# Fix expect shebang for portability (use env lookup)
if [[ "$OS" != "Darwin" ]]; then
    EXPECT_PATH="$(command -v expect 2>/dev/null)"
    if [ -n "$EXPECT_PATH" ] && [ "$EXPECT_PATH" != "/usr/bin/expect" ]; then
        sed -i "1s|.*|#!${EXPECT_PATH} -f|" "$MESH_DIR/watcher.expect" 2>/dev/null
        echo "  [OK] Fixed expect shebang to $EXPECT_PATH"
    fi
fi

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
