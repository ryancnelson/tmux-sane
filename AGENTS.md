# Agent Guidelines for tmux-sane-protocol

## Testing & Validation
- Test scripts manually: `./tmux-send-command SESSION "ls -la"` (requires active tmux session)
- Validate bash syntax: `bash -n script.sh` before running
- Check for shellcheck issues: `shellcheck tmux-*` (if available)
- Test base64 encoding: `echo "test" | base64 | base64 -d` to verify round-trip

## Code Style
- **Shebang**: Use `#!/usr/bin/env bash` for new scripts (portable), `#!/bin/bash` acceptable for existing
- **Error handling**: Always use `set -euo pipefail` at top of scripts
- **Quoting**: Always quote variables: `"$VAR"` not `$VAR`
- **Exit codes**: Return 0 for success, non-zero for errors; include clear error messages to stderr
- **AI agent warnings**: Include helpful error messages for AI agents (see existing scripts for pattern)
- **Comments**: Document complex escape handling, base64 encoding, timing quirks
- **Functions**: Prefer functions over inline code for reusability

## Naming Conventions
- Scripts: `tmux-verb-noun` format (e.g., `tmux-send-command`, `tmux-check-state`)
- Variables: `UPPER_CASE` for globals/constants, `lower_case` for locals
- Sessions: User provides session name as first argument

## Error Handling Pattern
- Check session exists: `tmux has-session -t "$SESSION" 2>/dev/null`
- Provide multi-line error messages with context (see tmux-driver:26-42)
- Exit with non-zero code and clear stderr output
- Never try to auto-fix issues silently; report failures clearly
