#!/usr/bin/env bash
# launch-agent.sh - Launch a fresh AI agent to work on tmux-sane

set -euo pipefail

MODEL="${1:-amazon-bedrock/anthropic.claude-haiku-4-5-20251001-v1:0}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HINTS_FILE="$PROJECT_DIR/HINTS.md"

echo "Launching agent with model: $MODEL"
echo "Project: $PROJECT_DIR"
echo ""

# Check for admin hints
HINTS_PROMPT=""
if [[ -f "$HINTS_FILE" ]] && [[ -s "$HINTS_FILE" ]]; then
  echo "📝 Found admin hints in HINTS.md"
  HINTS_CONTENT=$(cat "$HINTS_FILE")
  HINTS_PROMPT="

🚨 ADMIN HINTS (read these first!):

The admin left these notes for you to consider in this iteration:

$HINTS_CONTENT

⚠️  IMPORTANT: After you address a hint (incorporate it into your work, add it to backlog, or document it), you MUST remove it from HINTS.md so it doesn't appear in the next run. Use:
  sed -i.bak '/hint text/d' HINTS.md
or edit the file directly to remove addressed items.

"
  echo "Hints included in agent prompt"
else
  echo "ℹ️  No admin hints found (HINTS.md is empty or missing)"
fi

# Construct the full prompt
FULL_PROMPT="Hey, you are a new AI assistant. Go to $PROJECT_DIR and read BOOTSTRAP.md. Then start working.${HINTS_PROMPT}"

open -na WezTerm --args start \
  --cwd "$PROJECT_DIR" \
  -- bash -l -c "opencode run -m $MODEL '$FULL_PROMPT'; exec bash -l"

echo "Agent launched in new WezTerm window!"
echo ""
echo "To monitor progress:"
echo "  wezterm cli list  # Find the pane ID"
echo "  wezterm cli get-text --pane-id N --start-line -100"
echo "  ask-nova-lite \"What's the status? \$(wezterm cli get-text --pane-id N --start-line -50)\""
