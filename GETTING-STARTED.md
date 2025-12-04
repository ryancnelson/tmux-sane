# Getting Started with tmux-sane

Welcome to **tmux-sane**! This guide will help you get started with the Structured Agent Navigation Environment for tmux.

## What is tmux-sane?

**tmux-sane** is a protocol that helps AI agents reliably control tmux sessions without getting confused. Instead of letting agents improvise at the keystroke level, tmux-sane provides:

- **High-level primitives** - Commands like `sane-run-command` and `sane-create-file` instead of raw keystrokes
- **Structured state** - Machine-readable prompts that include sequence numbers, exit codes, and timestamps
- **Pane awareness** - Know which pane is which (local development, remote database, app server, etc.)
- **Platform detection** - Automatically handles macOS, Linux, and FreeBSD differences
- **Validation** - Pre-flight checks catch syntax errors before they cause problems

If you've ever watched an AI agent get stuck trying to type commands in tmux, or confused about whether a command finished running, tmux-sane is the solution.

## Prerequisites

Before you start, make sure you have:

- **tmux** installed (`tmux --version` should show a version)
- **bash** 4.0 or later (`bash --version`)
- A Unix-like system (macOS, Linux, or FreeBSD)
- An active tmux session to work with
- Basic familiarity with the command line

## Installation & Setup

### 1. Clone or Copy the Project

```bash
# Navigate to where you want to work
cd /path/to/your/projects

# Clone the repository (or copy the scripts)
git clone <repo-url> tmux-sane
cd tmux-sane
```

### 2. Create a Test Session

```bash
# Create a tmux session for testing
tmux new-session -d -s dev -x 200 -y 50

# Verify it was created
tmux list-sessions
```

### 3. Test Your Installation

```bash
# Run the basic commands to verify setup
./sane-detect-platform dev          # Detect platform in 'dev' session
./sane-list-panes dev               # List all panes
./sane-validate-bash 'echo hello'   # Validate a bash command
```

If these commands work without errors, you're ready to go!

## Understanding the Basics

### Pane Targeting

tmux-sane uses a **pane targeting syntax** to know exactly where to run commands:

```
SESSION:WINDOW.PANE
```

Examples:
- `dev` - Uses default window and pane (0:0)
- `dev:1` - Window 1, default pane (0)
- `dev:0.1` - Window 0, Pane 1
- `dev:2.3` - Window 2, Pane 3

### Structured Prompts

When you set up a pane with tmux-sane, it changes the shell prompt to include structured information:

```
ryan@macbook - dec042025:102530am seq:42 rslt:0 bash $
```

This includes:
- `ryan@macbook` - Who you are and where you are
- `dec042025:102530am` - Current timestamp (detect frozen screens)
- `seq:42` - Command sequence number (detect if commands ran)
- `rslt:0` - Exit code of last command (0 = success, non-zero = error)
- `bash $` - Clear prompt delimiter

## Example 1: Running Your First Command

Let's start simple - run a basic command in a tmux pane:

```bash
# In your tmux session, the command would run as:
./sane-run-command dev "pwd"

# This returns JSON like:
# {
#   "output": "/Users/ryan/projects",
#   "exit_code": 0,
#   "duration_ms": 145
# }
```

**What just happened:**
1. The pane ran `pwd` 
2. Captured the output
3. Extracted the exit code (0 = success)
4. Returned structured JSON with results

**Why this is better than keystrokes:**
- No guessing if the command finished
- Automatic error detection via exit codes
- Consistent output format for parsing
- Works across local and remote panes

## Example 2: Creating Files with Complex Content

Creating files with special characters (quotes, newlines, JSON) can be tricky. tmux-sane handles this automatically:

```bash
# Create a JSON config file
./sane-create-file dev "/tmp/config.json" '{
  "name": "my-app",
  "version": "1.0",
  "features": ["auth", "api", "dashboard"]
}'

# Returns JSON:
# {
#   "status": "created",
#   "path": "/tmp/config.json",
#   "checksum": "abc123...",
#   "size_bytes": 87
# }
```

**How it works:**
1. Validates the content (checks for quotes, special chars, etc.)
2. Uses base64 encoding for complex content
3. Creates the file safely
4. Auto-backs up existing files to `/var/tmp/`
5. Returns a checksum you can verify

**Real-world scenario:**
Imagine an agent needs to deploy a config file to 5 different servers. This command ensures the file content is exactly right every time, across all platforms.

## Example 3: Multi-Step Workflows - Deploy an Application

Here's how a real agent might use tmux-sane to deploy an app:

```bash
# Step 1: Setup the pane with a structured prompt
./sane-setup-prompt dev:0.0

# Step 2: Validate bash syntax before running
./sane-validate-bash 'cd /app && npm install && npm run build'

# Step 3: Run the commands
./sane-run-command dev:0.0 "cd /app && npm install && npm run build"

# Step 4: Create a deployment marker file
./sane-create-file dev:0.0 "/tmp/deployment-$(date +%s).txt" "Deployed successfully at $(date)"

# Step 5: Verify context is tracked
./sane-context-database read dev:0.0
# Returns metadata about the pane
```

**Why this workflow is reliable:**
- Pre-validation catches syntax errors immediately
- Structured prompts let you know exact status
- Each step returns structured JSON for decisions
- Context database tracks what was done where

## Key Commands Reference

### Running Commands

```bash
# Run a command and get output + exit code
./sane-run-command SESSION:WINDOW.PANE "ls -la /tmp"

# With retry logic (for transient failures)
./sane-run-command SESSION:WINDOW.PANE "apt-get update" --retries 3
```

### Creating Files

```bash
# Create a file with content
./sane-create-file SESSION:WINDOW.PANE "/path/to/file" "content here"

# Works with complex content (JSON, multi-line, special chars)
./sane-create-file dev /etc/app.json '{"key": "value"}'
```

### Platform Detection

```bash
# Detect platform in a pane (macOS, Linux, FreeBSD, etc.)
./sane-detect-platform SESSION:WINDOW.PANE

# Returns JSON:
# {
#   "platform": "darwin",
#   "is_remote": false
# }
```

### Pane Management

```bash
# List all panes in a session
./sane-list-panes SESSION

# Label a pane (e.g., mark it as "database")
./sane-label-pane SESSION:WINDOW.PANE "database"

# Get context info about a pane
./sane-context-database read SESSION:WINDOW.PANE
```

### Validation

```bash
# Validate bash syntax
./sane-validate-bash "for i in {1..10}; do echo $i; done"

# Validate JSON
./sane-validate-json '{"name": "test"}'
```

## Troubleshooting

### "Command not found: sane-run-command"

**Problem:** The sane-* scripts aren't in your PATH.

**Solution:**
```bash
# Add the project directory to your PATH
export PATH="$PATH:/path/to/tmux-sane"

# Or run with full path
/path/to/tmux-sane/sane-run-command dev "echo hello"
```

### "Session 'dev' not found"

**Problem:** The tmux session doesn't exist.

**Solution:**
```bash
# Create the session
tmux new-session -d -s dev

# Verify it exists
tmux list-sessions
```

### "Command timed out"

**Problem:** The command took too long to execute.

**Solution:**
```bash
# Check if the command is actually running
tmux capture-pane -t SESSION:WINDOW.PANE -p

# Kill it if needed
tmux send-keys -t SESSION:WINDOW.PANE C-c

# Try with longer timeout (if supported)
./sane-run-command SESSION:WINDOW.PANE "your-command" --timeout 30000
```

### "Exit code is non-zero"

**Problem:** The command failed (exit code != 0).

**Solution:**
```bash
# First, check what happened
./sane-run-command SESSION:WINDOW.PANE "your-command"

# Look at the output JSON - it shows:
# {
#   "exit_code": 1,
#   "output": "Error message here..."
# }

# Fix the command based on the error, then retry
```

### "JSON validation failed"

**Problem:** Your JSON syntax is invalid.

**Solution:**
```bash
# Use the validator first
./sane-validate-json '{"key": "value'  # Missing closing quote

# Fix the JSON
./sane-validate-json '{"key": "value"}'  # Valid!
```

### "Base64 encoding issues"

**Problem:** Special characters in file content caused problems.

**Solution:**
```bash
# tmux-sane handles base64 automatically, but you can verify:
echo '{"test": "content"}' | base64
# Should show: eyJ0ZXN0IjogImNvbnRlbnQifQo=

# When in doubt, just use sane-create-file - it handles all edge cases
```

### "Platform detection says 'unknown'"

**Problem:** The system wasn't detected correctly.

**Solution:**
```bash
# Check your actual platform
uname -s  # Shows: Darwin (macOS), Linux, FreeBSD, etc.

# Check if you're in a remote SSH pane
echo $SSH_CLIENT  # Should be empty for local, have IP for remote
```

## Next Steps

Now that you understand the basics, here are some advanced topics to explore:

### Learn More About

1. **[DESIGN.md](DESIGN.md)** - Deep dive into the architecture and design decisions
2. **[SAMPLE-WORKFLOW-MULTIFILE.md](SAMPLE-WORKFLOW-MULTIFILE.md)** - Real agent workflow examples
3. **[MULTI-SERVER-DEPLOY.md](MULTI-SERVER-DEPLOY.md)** - Multi-server orchestration patterns
4. **[AGENTS.md](AGENTS.md)** - Guidelines for integrating tmux-sane with AI agents

### Common Use Cases

- **Local Development** - Run commands across multiple local panes (app, database, tests)
- **Remote Deployment** - SSH into servers and orchestrate multi-host deployments
- **CI/CD Integration** - Reliable pane control for complex build/test/deploy workflows
- **Pair Programming** - AI agent and human collaborate in same tmux session

### Tips for Success

1. **Always set up structured prompts first** - Makes state detection reliable
2. **Validate before execution** - Use bash/JSON validators to catch errors early
3. **Use pane labels** - Label panes so you remember which is which
4. **Check context** - Use `sane-context-database read` to verify pane metadata
5. **Watch for exit codes** - Non-zero exit codes tell you when something failed

## Getting Help

If something doesn't work:

1. **Check the error output** - Most commands return JSON with error details
2. **Verify pane exists** - Use `tmux list-panes -t SESSION`
3. **Check tmux capture** - Run `tmux capture-pane -t SESSION:WINDOW.PANE -p`
4. **Try with local pane first** - Rule out SSH/remote issues
5. **Check DESIGN.md** - Look up the specific feature in the architecture docs

## Summary

You've now learned:

✅ What tmux-sane is and why it matters
✅ How to install and set up the project
✅ How to run commands reliably with `sane-run-command`
✅ How to create files safely with `sane-create-file`
✅ How to build multi-step workflows
✅ How to troubleshoot common issues

You're ready to start using tmux-sane! Start with simple commands, then gradually build more complex workflows. Remember: structured commands and validation prevent 90% of agent confusion in tmux sessions.

Happy hacking! 🚀
