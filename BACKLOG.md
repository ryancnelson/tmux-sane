# tmux-sane Backlog

Prioritized improvements for the tmux-sane project.

## Priority 1: Ready to Implement (30-60 min each)

### Edge Case Testing Phase
- [x] **Test 1: Multi-Host SSH Session** (Iteration 13)
  - Scope: 45 min
  - Setup: tues session, SSH from macOS to Linux host (hp2)
  - Verify: sane-detect-platform correctly detects remote platform ✓
  - Verify: Context database tracks both local and remote panes ✓
  - Value: Proves cross-platform awareness works in real scenario
  - Result: All 9 tests passed. Created tests/test-multi-host-ssh.sh

- [x] **Test 2: Non-Bash REPL (Python/Node/Perl)** (Iteration 14)
   - Scope: 45 min
   - Setup: Launch Python, Node.js, or Perl REPL in a pane
   - Expected: sane-detect-platform handles gracefully ✓
   - Expected: System identifies non-bash environment ✓
   - Value: Identifies edge case handling needs
   - Result: All 15 tests passed. Created tests/test-repl.sh

- [x] **Test 3: Nested tmux Sessions** (Iteration 15)
   - Scope: 45 min
   - Setup: Attach to remote tmux from within local tmux
   - Expected: Commands target correct tmux server ✓
   - Value: Common DevOps workflow ✓
   - Result: All 14 tests passed. Created tests/test-nested-tmux.sh

- [ ] **Test 4: Network Device CLI** (Iteration 16)
   - Scope: 45 min
   - Setup: SSH to router or network device (or mock)
   - Expected: Detection works, bash commands fail gracefully
   - Expected: System knows it's in "raw mode"
   - Value: Real-world network automation scenario

### Sample Agent Workflows
- [ ] **Simple Automation: Multi-file Project Creation** (Iteration 17)
  - Scope: 45 min
  - Create 5 files with different content types (bash, JSON, markdown)
  - Use sane-* primitives to build a small project structure
  - Document the workflow
  - Value: Shows practical agent usage

- [ ] **Complex Workflow: Deploy to Multiple Servers** (Iteration 18)
  - Scope: 60 min
  - Use 3 panes (local, server1, server2)
  - Deploy app, verify health checks
  - Document coordination across panes
  - Value: Multi-pane agent coordination example

## Priority 2: Performance & Reliability (Next)

- [ ] **Performance Profiling** (Iteration 19)
  - Scope: 45 min
  - Profile sane-run-command and sane-create-file on large outputs
  - Identify any bottlenecks >1s
  - Document performance characteristics
  - Value: Production readiness

- [ ] **Error Recovery Mechanisms** (Iteration 20)
  - Scope: 45 min
  - Add timeout handling for hung commands
  - Add graceful degradation for missing tools
  - Add retry logic for transient failures
  - Value: Reliability in real-world scenarios

## Priority 3: Documentation & Release

- [ ] **Getting Started Guide** (Iteration 21+)
  - Write beginner-friendly walkthrough
  - Include 3 practical examples
  - Add troubleshooting section

- [ ] **Agent Best Practices Document** (Iteration 22+)
  - Document patterns from sample workflows
  - Show do's and don'ts
  - Include performance tips

- [ ] **Version 0.1 Release** (Iteration 23+)
  - Create git tag v0.1
  - Write release notes
  - Create simple README for distribution

## Priority 4: Research / Future

- [ ] **Integration with ask-* scripts**
   - Use ask-nova-lite for cheap validation
   - Use ask-claude-haiku for screen reading
   - Value: Cheaper, faster validation layer

- [ ] **SSH detection and tracking**
   - Detect when pane SSH's to remote host
   - Auto-refresh context database
   - Value: Automatic context updates

- [ ] **Raw mode for non-bash environments**
   - Support Juniper routers, SQL REPLs, network CLIs
   - Graceful degradation for non-bash shells
   - Value: Expanded use cases

- [ ] **Health check system**
   - Periodic pane health monitoring
   - Detect dead/frozen panes
   - Auto-notify agents of issues
   - Value: Production reliability

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

- [x] **Implement sane-create-file** (Iteration 8)
       - Creates files with arbitrary content via tmux panes
       - Uses base64 encoding for complex content with special shell characters
       - Auto-backups existing files to /var/tmp/ with timestamp
       - Returns JSON: {status, path, checksum, backup_path, size_bytes}
        - Handles special characters (quotes, newlines, JSON content)
        - Full test coverage (16/16 tests passing)
        - Works across different platforms and panes

- [x] **Implement sane-get-tool** (Iteration 10)
      - Platform-specific tool mapping (grep/ggrep, sed/gsed, awk/gawk)
      - Returns JSON with tool, path, found status
      - Supports explicit platform override for testing
      - Full test coverage (15/15 tests passing)
      - Enables reliable tool path resolution across macOS/Linux/FreeBSD

- [x] **Implement friction logging system** (Iteration 11)
       - sane-log-operation: Logs operations to ~/.tmux-sane/friction.jsonl
       - sane-friction-analysis: Analyzes logs for patterns and statistics
       - Tracks: timestamp, event type, command, platform, validation status, exit code, duration
       - Analysis output: validation stats, event distribution, failure patterns, platform stats, performance metrics
       - Full test coverage (16/16 tests passing)
       - Enables data-driven improvements based on friction patterns

 - [x] **Implement wormhole file transfer integration** (Iteration 12)
        - sane-transfer-to-workstation: Transfer files from remote panes to local workstation using wormhole
        - sane-transfer-from-workstation: Transfer files from local workstation to remote panes using wormhole
        - Validates file existence, calculates checksums, handles error conditions gracefully
        - Full test coverage (15/15 tests passing)
        - Enables reliable file transfers across panes and hosts using wormhole protocol

 - [x] **Strategic Review #2** (Iteration 12, Checkpoint)
         - All Priority 1-3 items completed (12 complete iterations)
         - 142/142 tests passing across 14 test suites
         - 15 production-grade sane-* commands implemented
         - Clean git history with 25 commits
         - Ready to enter "Proving Phase" with edge case testing
         - Planning next 8 iterations (13-20) with clear theme
         - See STRATEGIC-REVIEW-CHECKLIST.md for full review

  - [x] **Edge Case Test 1: Multi-Host SSH Session** (Iteration 13)
          - Created comprehensive test suite (tests/test-multi-host-ssh.sh)
          - Verified sane-detect-platform works with remote panes
          - Verified sane-run-command executes on remote hosts
          - Verified context database tracks remote pane metadata
          - Full test coverage (9/9 tests passing)
          - Proved cross-platform awareness works in real SSH scenario
          - Foundation ready for remaining edge case tests (iterations 14-16)

   - [x] **Edge Case Test 2: Non-Bash REPL (Python/Node/Perl)** (Iteration 14)
           - Created comprehensive test suite (tests/test-repl.sh)
           - Verified Python REPL (>>>) is detected as non-bash
           - Verified Node.js REPL (>) is detected as non-bash
           - Verified Perl REPL (DB<) is detected as non-bash
           - Verified sane-detect-platform gracefully handles non-bash environments
           - Full test coverage (15/15 tests passing)
           - Identified that sane-* commands require bash shells for proper operation
           - Foundation ready for remaining edge case tests (iterations 15-16)

   - [x] **Edge Case Test 3: Nested tmux Sessions** (Iteration 15)
           - Created comprehensive test suite (tests/test-nested-tmux.sh)
           - Verified nested tmux server creation via alternate socket (/tmp/nested-tmux.sock)
           - Verified parent session detection and operations
           - Verified context isolation between parent and nested environments
           - Verified sane-* commands target correct tmux server by default
           - Full test coverage (14/14 tests passing)
           - Demonstrated common DevOps workflow with nested tmux
           - Foundation ready for remaining edge case test (iteration 16)