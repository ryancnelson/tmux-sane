#!/usr/bin/env bash
# launch-agent.sh - Launch a fresh AI agent to work on tmux-sane

set -euo pipefail

MODEL="${1:-amazon-bedrock/anthropic.claude-haiku-4-5-20251001-v1:0}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Launching agent with model: $MODEL"
echo "Project: $PROJECT_DIR"
echo ""

open -na WezTerm --args start \
  --cwd "$PROJECT_DIR" \
  -- bash -l -c "opencode run -m $MODEL 'Hey, you are a new AI assistant. Go to $PROJECT_DIR and read BOOTSTRAP.md. Then start working.'; exec bash -l"

echo "Agent launched in new WezTerm window!"
echo ""
echo "To monitor progress:"
echo "  wezterm cli list  # Find the pane ID"
echo "  wezterm cli get-text --pane-id N --start-line -100"
echo "  ask-nova-lite \"What's the status? \$(wezterm cli get-text --pane-id N --start-line -50)\""
