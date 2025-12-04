# tmux-sane: Structured Agent Navigation Environment

**SANE** = **S**tructured **A**gent **N**avigation **E**nvironment

## Overview

A reliable, guardrailed protocol for AI agents to interact with tmux sessions for pair programming. tmux-sane provides high-level primitives that prevent agents from getting lost, confused, or making unreliable keystroke-level decisions.

## Core Problem Statement

**Current Issues:**
- AI agents with full context windows easily get lost/confused when controlling tmux sessions
- Agents don't reliably detect command completion vs hung commands
- No consistent way to know if output appeared or command is waiting for input
- Escape handling across multiple layers (bash, tmux, special chars) is error-prone
- Agents improvise at keystroke level (trying vim commands, etc.) leading to inconsistent behavior
- Common syntax errors (jq, JSON, bash) waste tokens and create friction
- No awareness of multiple panes/windows - agents lose track of "which shell is the database, which is the app server"

**Solution:**
Create a protocol that:
1. Provides structured state information that's machine-parseable
2. Offers high-level primitives for common operations (bash mode)
3. Validates commands before execution
4. Handles escaping/encoding reliably
5. Logs friction points for continuous improvement
6. Knows platform differences (macOS vs Linux vs FreeBSD)
7. Tracks multiple panes/windows with context (what's running where, which pane is which host)

---

## Architecture

### Agent Tiers

**Expensive Agent (Sonnet 4.5 / Opus)**
- Makes high-level decisions: "I need to create this file, then run that command"
- Calls protocol primitives
- Never thinks about keystrokes in bash mode
- Reviews results and decides next steps

**Cheap Agent (via ask-claude-haiku / ask-nova-lite)**
- Screen reading: "Is this output complete or still running?"
- State checking: "Is there a prompt ready?"
- Syntax validation: "Is this valid jq?"
- Frequent polling without burning expensive tokens
- Implementation: Uses `~/bin/ask-claude-haiku` and `~/bin/ask-nova-lite` scripts

**Validation Layer (ask-nova-lite / Local Tools)**
- Pre-flight syntax checks via `ask-nova-lite`
- Command existence verification via local `command -v`
- Flag validation via `ask-nova-lite` or `ask-claude-haiku`
- Fast, cheap, local when possible
- Model costs: ~$0.00006 per Nova Lite call (negligible)

---

## Structured Prompt Format

### Design Goal
Make bash prompts machine-parseable with embedded state information.

### Format
```
ryan@hostX - dec032025:035722pm seq:3201 rslt:0 bash $
```

**Fields:**
- `ryan@hostX` - User and hostname (know where we are)
- `dec032025:035722pm` - Timestamp (detect frozen screens)
- `seq:3201` - Command sequence counter (detect progress)
- `rslt:0` - Exit code of last command (success/failure)
- `bash $` - Clear delimiter (we're at a prompt)

**Benefits:**
- Agent can parse: "I see seq:3201 rslt:0, ready for next command"
- Detect hung state: "Still showing seq:3200, command hasn't finished"
- Detect frozen screen: "Timestamp is 5 minutes old"
- No guessing about command completion

### Implementation
Set via `PS1` environment variable when entering bash mode:
```bash
export PS1='\u@\h - \D{%b%d%Y}:\t seq:$HISTCMD rslt:$? bash \$ '
```

---

## Pane Management & Context Tracking

### The Problem
tmux sessions can have multiple windows, each with multiple panes:
- Window 0, Pane 0: Local mac shell in project directory
- Window 0, Pane 1: SSH to production database server
- Window 1, Pane 0: SSH to app server
- Window 1, Pane 1: Local shell running docker container

Agents need to know "which pane is which" and maintain context about what's running where.

### Pane Targeting

**All commands accept pane target:**
```
SESSION:WINDOW.PANE
```

**Examples:**
- `tues:0.0` - Session "tues", window 0, pane 0
- `tues:0.1` - Session "tues", window 0, pane 1
- `tues` - Session "tues", active pane (shorthand)

**Implementation:**
```bash
sane-detect-platform tues:0.1  # Detect platform in specific pane
sane-run-command tues:0.0 "ls -la"  # Run in pane 0
```

### Pane Context Database

Track state for each pane in a local database (JSON file):

```json
{
  "tues:0.0": {
    "platform": {"os": "Darwin", "arch": "arm64", "hostname": "minnie-2", "user": "ryan"},
    "mode": "bash",
    "current_dir": "/Volumes/T9/ryan-homedir/devel/tmux-sane",
    "label": "local dev shell",
    "last_command": "ls",
    "last_check": "2025-12-03T16:45:22Z"
  },
  "tues:0.1": {
    "platform": {"os": "Linux", "arch": "x86_64", "hostname": "prod-db-01", "user": "dbadmin"},
    "mode": "bash",
    "current_dir": "/var/log",
    "label": "production database",
    "last_command": "tail -f postgres.log",
    "last_check": "2025-12-03T16:45:18Z"
  }
}
```

### Pane Operations

#### `sane-list-panes SESSION`
Lists all panes with their context:
```bash
$ sane-list-panes tues
tues:0.0 [local dev shell] - Darwin/arm64 minnie-2 - /Volumes/T9/ryan-homedir/devel/tmux-sane
tues:0.1 [production database] - Linux/x86_64 prod-db-01 - /var/log
```

#### `sane-label-pane SESSION:WINDOW.PANE "label"`
Give a human-readable label to a pane:
```bash
$ sane-label-pane tues:0.1 "production database"
```

#### `sane-split-pane SESSION [vertical|horizontal]`
Split current pane and track the new one:
```bash
$ sane-split-pane tues vertical
Created new pane: tues:0.1
```

#### `sane-refresh-context SESSION:WINDOW.PANE`
Re-detect platform, directory, mode for a pane:
```bash
$ sane-refresh-context tues:0.1
Updated context for tues:0.1: Linux/x86_64 prod-db-01
```

### Agent Workflow with Multiple Panes

**Human says:** "Split the window left/right, and in the right pane, SSH to the database server"

**Agent does:**
1. `sane-split-pane tues horizontal` → creates `tues:0.1`
2. `sane-run-command tues:0.1 "ssh dbadmin@prod-db-01.example.com"`
3. Wait for SSH to connect (detect new prompt)
4. `sane-detect-platform tues:0.1` → detects Linux on remote host
5. `sane-label-pane tues:0.1 "production database"`
6. Updates context database

**Human says:** "In the database pane, check the postgres logs"

**Agent does:**
1. `sane-list-panes tues` → sees "production database" label on `tues:0.1`
2. `sane-run-command tues:0.1 "tail -n 50 /var/log/postgresql.log"`
3. Returns output to user

### Context Storage Location

Store in `~/.tmux-sane/contexts.json` (local to workstation, not in session)

Persist across:
- Session detach/attach
- tmux server restarts (contexts can be restored by re-detecting)

Auto-cleanup:
- Remove contexts for panes that no longer exist
- Refresh stale contexts (> 1 hour old)

---

## Operating Modes

### Bash Mode (Primary, High-Level)

**When Active:**
- Detected bash prompt with structured format
- On Linux/macOS/FreeBSD hosts with bash shell
- Default mode whenever possible

**Primitives:**

#### `run_command(cmd, timeout=30)`
- Executes command, waits for completion
- Returns: `{output, exit_code, duration, platform_info}`
- Handles escaping automatically
- Validates syntax before sending
- Times out if command hangs
- Cheap agent polls for completion

#### `create_file(path, content, backup=true)`
- Creates file with arbitrary content
- Uses base64 encoding if special chars detected
- Auto-backups existing file to `/var/tmp/` with timestamp
- Returns: `{status, backup_path, checksum}`
- Validates: path is writable, content is valid

#### `read_file(path)`
- Cats file contents
- Returns: `{content, checksum, size, modified_time}`
- Handles binary detection (don't try to read binaries)

#### `edit_file(path, operation, backup=true)`
- Modifies file using sed/awk (not vim!)
- Operations: replace, insert, delete, append
- Auto-backups to `/var/tmp/`
- Returns: `{status, backup_path, diff}`

#### `checksum_file(path)`
- Returns: `{md5, sha256, size}`
- For verification after transfers

#### `transfer_to_workstation(remote_path, wormhole_code=None)`
- Uses `wormhole send` to transfer file from remote to local
- Returns: `{wormhole_code, size, checksum}`

#### `transfer_from_workstation(local_path, wormhole_code)`
- Uses `wormhole receive` to pull file to remote
- Returns: `{remote_path, size, checksum}`

**Validation (Pre-flight):**
- Bash syntax: `bash -n -c "$cmd"` locally
- Check command exists: `command -v tool_name`
- JSON: validate with local parser
- jq: validate query syntax
- YAML: validate with local parser
- Detect common errors: unclosed quotes, missing semicolons

**Error Recovery:**
- Detect hung commands (no new seq number after timeout)
- Send Ctrl-C: `tmux send-keys -t $pane C-c`
- Wait for prompt return
- Report failure to agent with diagnostic info

### Raw Mode (Special Cases)

**When Active:**
- Explicitly requested by agent or user
- Non-bash environments (Juniper routers, SQL REPLs, Python REPL, etc.)
- Agent must be aware it's in raw mode

**Primitives:**

#### `send_keys(keys, special_chars=true)`
- Sends individual keystrokes
- Handles special chars: Ctrl-C, Ctrl-D, Enter, Escape
- Returns: screen contents after keys sent

#### `read_screen(lines=50)`
- Returns last N lines of pane
- Returns: `{content, timestamp}`

**Escape Handling:**
- Protocol understands tmux's escape requirements
- Special chars documented and tested
- Use base64 + tee if needed for visibility

---

## Platform Awareness

### Detection Strategy

**On Session Start:**
1. Parse hostname from prompt: `ryan@hostX`
2. Detect platform: `uname -s` → Darwin/Linux/FreeBSD
3. Detect architecture: `uname -m` → arm64/x86_64
4. Detect distro (Linux): check `/etc/os-release`
5. Store in session context

**On SSH:**
- Track transition: "was on macOS local, now on ubuntu22 remote"
- Re-detect platform on remote host
- Update context: pane X = local mac, pane Y = remote linux

### Tool Path Mapping

**macOS (Darwin arm64):**
- bash: `/opt/homebrew/bin/bash` (modern) or `/bin/bash` (old 3.2)
- grep: `/usr/bin/grep` (BSD, no `-P`), `/opt/homebrew/bin/ggrep` (GNU)
- awk: `/usr/bin/awk` (BSD), `/opt/homebrew/bin/gawk` (GNU)
- sed: `/usr/bin/sed` (BSD), `/opt/homebrew/bin/gsed` (GNU)

**Linux (Ubuntu/Debian/RHEL):**
- bash: `/bin/bash` or `/usr/bin/bash`
- grep: `/bin/grep` or `/usr/bin/grep` (GNU, has `-P`)
- awk: `/usr/bin/awk` (GNU)
- sed: `/bin/sed` or `/usr/bin/sed` (GNU)

**FreeBSD:**
- bash: `/usr/local/bin/bash` (if installed)
- grep: `/usr/bin/grep` (BSD)
- awk: `/usr/bin/awk` (BSD)
- Tools often require GNU versions from ports

**Docker Containers:**
- Usually Linux (check with `uname`)
- May have minimal toolset
- Check if tools exist before using

### Command Translation

Agent says: "grep with PCRE for pattern XYZ"

Protocol translates:
- **macOS**: Check if `ggrep` exists, use `ggrep -P`, else use `grep -E` or `rg`
- **Linux**: Use `grep -P`
- **FreeBSD**: Use `perl -ne` or install GNU grep

Agent never needs to think about platform differences.

---

## Timeout Hierarchy

Different operations have different expected durations:

**Quick Commands (2-5 seconds):**
- `ls`, `pwd`, `echo`, `cat small_file`

**Medium Commands (10-30 seconds):**
- `grep` over moderate files
- `find` in small directories
- File transfers (small files)

**Long Commands (1-5 minutes):**
- Package installation (`apt install`, `brew install`)
- Compilation (`make`, `cargo build`)
- Large file transfers
- Database operations

**Agent-Specified:**
- Agent can override: `run_command(cmd, timeout=300)`

**Timeout Behavior:**
- Cheap agent polls every 2 seconds
- After timeout: check if still running
- If hung: send Ctrl-C, wait for prompt, report failure

---

## Escape Handling & Encoding

### Problem
Multiple layers of escaping:
1. Bash shell interpretation
2. Tmux send-keys escaping
3. Special characters in content (quotes, newlines, etc.)

### Solution: Base64 for Complex Content

**When to Use Base64:**
- Files with quotes, backticks, dollar signs
- Heredoc content
- JSON payloads for curl
- Any content with potential escape issues

**Pattern:**
```bash
echo "BASE64_CONTENT_HERE" | base64 -d | tee /path/to/file | base64 -d
```

**Benefits:**
- No escape hell
- User can watch decoded output in tmux (via tee)
- 100% reliable for arbitrary content

**When NOT to Use Base64:**
- Simple commands with no special chars
- User wants to see readable commands in tmux history

### Tmux Special Characters

**Control Characters (via send-keys):**
- Ctrl-C: `C-c`
- Ctrl-D: `C-d`
- Enter: `Enter` or `C-m`
- Escape: `Escape`
- Tab: `Tab`

**Tested and Documented:**
- Protocol includes tests for all special char combinations
- Known working patterns for heredocs, quotes, etc.

---

## State Snapshots

### Format
Every interaction returns structured JSON (not raw text):

```json
{
  "timestamp": "2025-12-03T15:57:22",
  "session": "main",
  "pane": "main:0.1",
  "mode": "bash",
  "platform": {
    "os": "Darwin",
    "arch": "arm64",
    "hostname": "macbook",
    "user": "ryan"
  },
  "prompt": {
    "user": "ryan",
    "host": "macbook",
    "timestamp": "dec032025:035722pm",
    "seq": 3201,
    "exit_code": 0,
    "ready": true
  },
  "screen": {
    "lines": ["line1", "line2", "..."],
    "last_command": "ls -la",
    "output_lines": 15
  }
}
```

**Benefits:**
- Agent can programmatically check fields
- No parsing raw text
- Easy to detect state changes

---

## Validation System

### Local Validation (Fast, Free)

**Bash Syntax:**
```bash
bash -n -c "command here"
# Exit code 0 = valid, non-zero = syntax error
```

**JSON:**
```bash
echo "$json" | jq empty
# Exit code 0 = valid JSON
```

**jq Query:**
```bash
echo '{"test": "data"}' | jq "$query" > /dev/null
# Exit code 0 = valid query
```

**Python:**
```bash
python -m py_compile script.py
```

**YAML:**
```bash
python -c "import yaml; yaml.safe_load(open('file.yml'))"
```

### Cheap Model Validation (AWS Nova Lite)

**Implementation:**
Use existing `ask-*` scripts from `~/bin/`:
- `ask-nova-lite` - AWS Nova Lite (super cheap, ~$0.00006 per call)
- `ask-claude-haiku` - Claude Haiku 4.5 (cheap, fast)
- `ask-deepseek-v3` - DeepSeek V3 (coding specialist)

**Use Cases:**
- "Is this a valid curl command with proper escaping?"
- "Does this sed expression make sense for the task?"
- "Is this a real flag for grep on Linux?"

**Pattern:**
```bash
# Syntax validation example
ask-nova-lite "You are a syntax validator. Answer only YES or NO. Is this valid bash syntax: echo \"hello'"

# Command flag validation
ask-nova-lite "Does grep on Linux have a -P flag for PCRE? Answer YES or NO."

# Complex validation
ask-claude-haiku "Is this jq query valid: .data[] | select(.status == \"active\") | .name"
```

**Cost:** ~$0.00006 per validation (negligible)

**Caching:**
- Build validation cache: "we've validated `grep -P` on Linux 50 times, skip"
- Cache by (platform, tool, flags)

**Model Selection:**
- **ask-nova-lite**: First choice for simple validation (cheapest)
- **ask-claude-haiku**: Fallback for complex syntax questions
- **ask-deepseek-v3**: Code generation/complex command construction

### Command Existence Check

Before running:
```bash
command -v tool_name || which tool_name
```

If missing, fail fast: "Tool 'nonexistent_cmd' not found on this system"

---

## Friction Logging

### What to Log

**Every Operation:**
- Timestamp
- Mode (bash/raw)
- Platform info
- Command sent
- Validation result (pass/fail)
- Execution time
- Output size
- Exit code
- Retry count (if any)

**Friction Events:**
- Validation failure
- Command timeout
- Hung command detected
- Retry after failure
- Platform-specific fallback used

**Success Patterns:**
- Command worked first try
- Used base64 encoding (reliable)
- Used validated path (e.g., ggrep on macOS)

### Log Format

JSON Lines format (one event per line):

```json
{"ts": "2025-12-03T15:57:22Z", "event": "run_command", "cmd": "grep -P foo", "platform": "darwin_arm64", "validation": "failed", "reason": "BSD grep has no -P flag"}
{"ts": "2025-12-03T15:57:23Z", "event": "run_command", "cmd": "ggrep -P foo", "platform": "darwin_arm64", "validation": "passed", "exit_code": 0, "duration_ms": 45}
```

### Analysis

**Periodic Review:**
- "What commands fail validation most often?"
- "What platform has most friction?"
- "Which patterns have 100% success rate?"

**Feedback Loop:**
- High friction → improve validation rules
- Successful patterns → document and prefer
- Platform-specific issues → add to translation layer

**Example Insights:**
- "Creating files with single quotes: 23 failures with heredoc, 0 failures with base64"
- "jq queries: 15 syntax errors caught by pre-flight validation, saved expensive retries"

---

## Safety Mechanisms

### Auto-Backup

**Before Any Edit:**
```bash
cp /path/to/file /var/tmp/file.backup.$(date +%s)
```

**Tracked in State:**
- Operation ID links to backup path
- Can rollback if needed

**Cleanup:**
- Keep backups for session duration
- Optional: cleanup old backups after success

### Idempotency Checks

**Before Creating File:**
- Check if exists: `test -f /path/to/file`
- Check if content matches: `echo "$content" | md5sum` vs existing
- Return: `{status: "already_correct"}` vs `{status: "created"}`

**Before Package Install:**
- Check if already installed
- Return: `{status: "already_installed"}` vs `{status: "installed"}`

### Session Health Checks

**Periodic (via cheap agent):**
- Is tmux session alive? `tmux has-session -t $session`
- Can we read the pane? `tmux capture-pane -t $pane -p`
- Is SSH connection still alive? (check hostname in prompt)

**On Failure:**
- Report to expensive agent: "Session lost, need to reconnect"

---

## Implementation Roadmap

### Phase 1: Core Infrastructure
1. Structured prompt format (PS1 configuration)
2. State snapshot JSON format
3. Platform detection logic
4. Basic bash mode: `run_command`, `read_file`, `create_file`

### Phase 2: Validation
1. Local syntax validation (bash, JSON, jq)
2. Command existence checks
3. Nova Lite integration for complex validation
4. Validation caching

### Phase 3: Safety & Reliability
1. Auto-backup before edits
2. Timeout hierarchy
3. Hung command detection & recovery
4. Escape handling & base64 encoding

### Phase 4: Advanced Features
1. File transfer (wormhole integration)
2. Edit operations (sed/awk-based)
3. Raw mode for special cases
4. Session health checks

### Phase 5: Learning & Optimization
1. Comprehensive friction logging
2. Log analysis tools
3. Feedback loop for validation rules
4. Success pattern documentation

---

## Success Metrics

**Reliability:**
- First-try success rate > 95%
- Hung command detection: 100% (no infinite waits)
- Escape-related failures: < 1%

**Efficiency:**
- Expensive agent token usage: 50% reduction (via cheap polling)
- Validation catches errors before execution: > 90%
- Time to recovery from errors: < 5 seconds

**User Experience:**
- User can watch operations in tmux (readable, not base64 spam when avoidable)
- Clear state visibility (prompt shows what's happening)
- Predictable behavior (same operation works same way every time)

---

## Open Questions

1. **Prompt format details:** Should we include pwd in prompt? Exit code formatting?
2. **Timeout defaults:** What are good defaults for each tier?
3. **Validation cache persistence:** Save across sessions or just in-memory?
4. **Raw mode escaping:** Document every special case or discover dynamically?
5. **Error recovery strategies:** When to give up vs keep retrying?
6. **Multi-pane coordination:** How to track state across multiple panes?

---

## References

- Existing scripts in `~/bin/tmux-*` (friction logging patterns)
- tmux documentation: `man tmux`, `tmux list-keys`
- Platform detection: `uname`, `/etc/os-release`
- Wormhole: `python -m wormhole send/receive`
