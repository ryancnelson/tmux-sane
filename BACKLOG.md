# tmux-sane Backlog

Prioritized improvements for the tmux-sane project.

## Priority 1: Ready to Implement (30-60 min each)

### Core Infrastructure
- [x] **Fix sane-detect-platform to support pane targeting** (Iteration 1)
  - Scope: 45 min
  - Update to accept SESSION:WINDOW.PANE format
  - Add tests for pane targeting
  - Value: Foundation for all other pane-aware commands

- [x] **Create sane-list-panes command** (Iteration 2)
   - Scope: 45 min
   - List all panes in a session with basic info (pane ID, current command, path)
   - Returns JSON format
   - Add tests
   - Value: Visibility into session structure

- [x] **Create context database (~/.tmux-sane/contexts.json)** (Iteration 3)
  - Scope: 60 min
  - Basic CRUD operations for pane contexts
  - Store: platform, mode, current_dir, label, created_at, updated_at
  - Add tests (7/7 passing)
  - Value: Enables pane context tracking

### Validation System
- [x] **Create sane-validate-bash command** (Iteration 4)
  - Scope: 30 min
  - Use `bash -n` to validate syntax
  - Returns JSON: {valid: true/false, error: "..."}
  - Add tests (11/11 tests passing)
  - Value: Prevent syntax errors before sending to tmux

- [x] **Create sane-validate-json command** (Iteration 5)
   - Scope: 30 min
   - Use `jq empty` to validate JSON
   - Returns JSON: {valid: true/false, error: "..."}
   - Add tests (15/15 tests passing)
   - Value: Catch JSON errors early

### Prompt Management
- [x] **Create sane-setup-prompt command** (Iteration 6)
  - Scope: 45 min
  - Sets structured PS1 in target pane: `user@host - timestamp seq:N rslt:N bash $`
  - Detects current shell (bash/zsh)
  - Add tests (10/10 tests passing)
  - Value: Enables reliable state detection

## Priority 2: Important but Need Breakdown

- [x] **Implement sane-run-command** (Iteration 7)
  - Full implementation with tmux capture-pane integration
  - Works with remote SSH panes, local panes
  - Returns JSON with output, exit_code, duration_ms
  - All 16 tests passing

- [ ] **Implement sane-create-file**  
  - With base64 encoding, backup mechanism
  - Depends on: run-command
  - Break into sub-tasks

- [ ] **Pane labeling system**
  - sane-label-pane, sane-get-label
  - Update list-panes to show labels
  - Storage in context database

## Priority 3: Nice to Have

- [ ] **Friction logging system**
  - Log all operations with timing, retries, failures
  - Analysis tools

- [ ] **Wormhole file transfer integration**
  - sane-transfer-to-workstation
  - sane-transfer-from-workstation

- [ ] **Platform-specific tool mapping**
  - Detect and use correct grep/awk/sed for platform
  - ggrep vs grep, etc.

## Priority 4: Research / Future

- [ ] **Integration with ask-* scripts**
  - Use ask-nova-lite for cheap validation
  - Use ask-claude-haiku for screen reading

- [ ] **SSH detection and tracking**
  - Detect when pane SSH's to remote host
  - Auto-refresh context

- [ ] **Raw mode for non-bash environments**
  - Juniper routers, SQL REPLs, etc.

## Testing Scenarios (Edge Cases & Stress Tests)

**Purpose:** Test the robustness of tmux-sane in real-world edge cases.

### When to Run These Tests
- **Strategic review time** (every 8 iterations)
- **Before releasing a major version**
- **When you want to find bugs proactively**
- **To demonstrate capability to stakeholders**

### Test 1: Multi-Host SSH Session
- [ ] **Test platform detection across SSH boundaries**
  - Setup: tues session, SSH from macOS to Linux host (hp2)
  - Expected: sane-detect-platform correctly detects remote platform
  - Expected: Context database tracks both local and remote panes
  - Value: Proves cross-platform awareness works

### Test 2: Non-Bash REPL (Perl/Python/Node)
- [ ] **Test behavior in interactive REPLs**
  - Setup: Launch `perl -de1` or `python` or `node` in a pane
  - Expected: sane-detect-platform handles gracefully (or fails gracefully)
  - Expected: Agent doesn't try to use bash primitives
  - Challenge: No structured prompt, different input handling
  - Value: Identifies need for "raw mode" or REPL detection

### Test 3: Network Device (Router/Switch)
- [ ] **Test with Juniper/Cisco/OPNsense CLI**
  - Setup: SSH to router, enter config mode
  - Expected: Detection works, but bash commands fail gracefully
  - Expected: System knows it's in "raw mode" 
  - Challenge: Different command syntax, no bash
  - Value: Real-world network automation use case

### Test 4: Nested tmux Sessions
- [ ] **Test tmux-inside-tmux**
  - Setup: Attach to remote tmux session from within local tmux
  - Expected: Commands target correct tmux server
  - Challenge: Key binding conflicts, which tmux to control
  - Value: Common DevOps workflow

### Test 5: Hung/Frozen Commands
- [ ] **Test recovery from unresponsive commands**
  - Setup: Run `cat` (waits for stdin), or `sleep 9999`
  - Expected: Timeout detection works
  - Expected: Ctrl-C recovery mechanism works
  - Value: Agents don't get stuck forever

### Test 6: Large Output (Scrollback Overflow)
- [ ] **Test with commands producing 10000+ lines**
  - Setup: Run `find / 2>/dev/null` or similar
  - Expected: Capture mechanism doesn't miss data
  - Expected: Performance remains acceptable
  - Value: Real-world log analysis scenarios

### Test 7: Special Characters & Escape Hell
- [ ] **Test file creation with nasty content**
  - Setup: Create file with quotes, backticks, $vars, newlines
  - Expected: Base64 encoding handles it correctly
  - Expected: User can see decoded output via tee
  - Value: Proves escape handling is solid

### Test 8: Rapid Context Switching
- [ ] **Test agent working across 5+ panes simultaneously**
  - Setup: 5 panes, different hosts/languages/tasks
  - Expected: Context database keeps them separate
  - Expected: No cross-contamination of commands
  - Value: Real pair-programming scenario

### Test 9: Permission Denied / Sudo Required
- [ ] **Test graceful handling of auth failures**
  - Setup: Try to write to /etc/ without sudo
  - Expected: Clear error message
  - Expected: Agent understands and adapts (adds sudo)
  - Value: Common friction point

### Test 10: Connection Loss / Pane Death
- [ ] **Test recovery when SSH disconnects**
  - Setup: Kill SSH connection mid-operation
  - Expected: Health check detects dead pane
  - Expected: Context marked as stale
  - Expected: User gets clear notification
  - Value: Production reliability

### Stress Test: Autonomous Multi-Day Run
- [ ] **Launch agent, let it work for 24+ hours**
  - Setup: Fresh agent, full backlog, no supervision
  - Track: How many iterations completed
  - Track: Friction log entries
  - Track: Number of test failures
  - Track: Git commit quality
  - Value: Ultimate test of self-sufficiency

### Recording Results
After running tests, update this section:

**Last Test Run:** [DATE]  
**Tests Passed:** X/10  
**Tests Failed:** Y/10  
**Issues Found:** [List new backlog items created from failures]  
**Insights:** [What did we learn?]

## Ideas Inbox (Unsorted)

- Mouse mode helpers
- Window management commands
- Session health monitoring
- Auto-cleanup of dead pane contexts
- Integration with existing tmux-* scripts

## Completed

- [x] **Initial project setup** (Iteration 0)
  - Created DESIGN.md, README.md, AGENTS.md
  - Established project structure
  - First git commit

- [x] **Platform detection** (Iteration 0)
  - Created lib/platform-detect.sh (local detection)
  - Created sane-detect-platform (in-session detection)
  - Added tests
  
- [x] **Add pane targeting to sane-detect-platform** (Iteration 1)
   - Updated sane-detect-platform to accept SESSION:WINDOW.PANE format
   - Maintains backward compatibility with session-only format
   - Added comprehensive test coverage
   - Foundation for pane-aware commands

- [x] **Create sane-list-panes command** (Iteration 2)
    - Lists all panes in a session with ID, window/pane index, command, and path
    - Returns structured JSON for machine-readable parsing
    - Full test coverage (4/4 tests passing)
    - Enables visibility into session structure for AI agents

- [x] **Create context database (~/.tmux-sane/contexts.json)** (Iteration 3)
     - Implemented sane-context-database command with full CRUD operations
     - Stores pane metadata: platform, mode, current_dir, label, timestamps
     - Uses ~/.tmux-sane/contexts.json for persistence
     - Full test coverage (7/7 tests passing)
     - Enables pane context tracking for future features

- [x] **Create sane-validate-bash command** (Iteration 4)
      - Implemented sane-validate-bash command for bash syntax validation
      - Uses `bash -n` to check script syntax
      - Returns structured JSON: {valid: true/false, error: "..."}
      - Full test coverage (11/11 tests passing)
      - Enables pre-flight validation before sending commands to tmux

- [x] **Create sane-validate-json command** (Iteration 5)
       - Implemented sane-validate-json command for JSON syntax validation
       - Uses `jq empty` to parse and validate JSON
       - Returns structured JSON: {valid: true/false, error: "..."}
       - Full test coverage (15/15 tests passing)
       - Enables pre-flight validation for JSON payloads

- [x] **Create sane-setup-prompt command** (Iteration 6)
       - Implemented sane-setup-prompt command for structured prompt setup
       - Sets PS1 in target pane: `user@host - timestamp seq:N rslt:N bash $`
       - Detects shell type (bash/zsh) and sets appropriate prompt syntax
       - Returns JSON: {status, pane, shell, ps1_set, message}
       - Full test coverage (10/10 tests passing)
       - Enables reliable state detection and command sequence tracking

- [x] **Implement sane-run-command** (Iteration 7)
       - Implemented using tmux capture-pane for reliable output capture
       - Works correctly with remote SSH panes (not just local)
       - Uses unique markers to detect command completion
       - Extracts exit code from shell variable expansion
       - Returns JSON: {output, exit_code, duration_ms}
       - Full test coverage (16/16 tests passing)
       - Supports SESSION, SESSION:WINDOW, SESSION:WINDOW.PANE formats
       - Pre-flight bash syntax validation before execution