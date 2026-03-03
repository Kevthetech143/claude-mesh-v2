# Claude Mesh

Dual-agent communication system for Claude Code. Two autonomous Claude instances (ALPHA + BETA) talk to each other via HTTP message servers, with automatic prompt injection via tmux.

## Architecture

```
  USER ─── talks to ──── ALPHA (team lead, port 9997)
                            │
                        HTTP messages
                            │
                          BETA (worker, port 9998)
```

Each agent has:
- A Flask inbox server (receives messages)
- An expect watcher (detects new messages, injects prompts into the Claude session)
- A tmux session running `claude --dangerously-skip-permissions`

## Quick Start

```bash
./install.sh    # Check dependencies
./launch.sh     # Start everything
```

## Usage

Once launched, talk to ALPHA in its terminal window. ALPHA delegates to BETA automatically.

```bash
./control.sh    # Interactive control panel (send messages, view inboxes, status)
./cleanup.sh    # Shut everything down
```

## Custom Ports

```bash
ALPHA_PORT=8001 BETA_PORT=8002 ./launch.sh
```

## Requirements

- Python 3 + Flask (`pip3 install flask`)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code/overview)
- tmux
- expect
- curl
- macOS (auto-opens Terminal windows) or Linux (manual tmux attach)

## File Structure

```
server.py         # Single Flask server (--port, --name args)
watcher.expect    # Single inbox watcher (port + tmux target args)
launch.sh         # Starts everything
cleanup.sh        # Stops everything
control.sh        # Interactive control panel
install.sh        # Dependency checker
prompts/
  alpha.txt       # ALPHA agent system prompt
  beta.txt        # BETA agent system prompt
runtime/          # Created at launch, gitignored
  *.pid, *.log, *.json
```
