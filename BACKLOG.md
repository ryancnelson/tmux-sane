# tmux-sane Backlog

Prioritized improvements for the tmux-sane project.

## Priority 1: Ready to Implement (30-60 min each)

### Core Infrastructure
- [x] **Fix sane-detect-platform to support pane targeting** (Iteration 1)
  - Scope: 45 min
  - Update to accept SESSION:WINDOW.PANE format
  - Add tests for pane targeting
  - Value: Foundation for all other pane-aware commands

- [ ] **Create sane-list-panes command**
  - Scope: 45 min
  - List all panes in a session with basic info (pane ID, current command, path)
  - Returns JSON format
  - Add tests
  - Value: Visibility into session structure

- [ ] **Create context database (~/.tmux-sane/contexts.json)**
  - Scope: 60 min
  - Basic CRUD operations for pane contexts
  - Store: platform, mode, current_dir, label, last_check
  - Add tests
  - Value: Enables pane context tracking

### Validation System
- [ ] **Create sane-validate-bash command**
  - Scope: 30 min
  - Use `bash -n` to validate syntax
  - Returns JSON: {valid: true/false, error: "..."}
  - Add tests
  - Value: Prevent syntax errors before sending to tmux

- [ ] **Create sane-validate-json command**
  - Scope: 30 min
  - Use `jq empty` to validate JSON
  - Returns JSON format
  - Add tests
  - Value: Catch JSON errors early

### Prompt Management
- [ ] **Create sane-setup-prompt command**
  - Scope: 45 min
  - Sets structured PS1 in target pane: `user@host - timestamp seq:N rslt:N bash $`
  - Detects current shell (bash/zsh)
  - Add tests
  - Value: Enables reliable state detection

## Priority 2: Important but Need Breakdown

- [ ] **Implement sane-run-command**
  - Full implementation with timeout, validation, output capture
  - Depends on: prompt setup, validation
  - Break into sub-tasks

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
