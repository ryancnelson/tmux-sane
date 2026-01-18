# tmux-sane

**Structured Agent Navigation Environment for tmux**

A reliable, guardrailed protocol for AI agents to interact with tmux sessions for pair programming.

---

## 🚨 Current Status: Published for Reference

This repository represents my personal tmux automation toolkit developed over months of LLM-driven infrastructure work. It's being published **as a reference** while I contribute battle-tested features to **[claude-code-tools](https://github.com/pchalasani/claude-code-tools)**, which is better packaged and has wider reach.

Rather than maintain a competing project, I'm contributing key features from tmux-sane to claude-code-tools and documenting the feature gap analysis below.

### Why Publish This?

1. **Transparency** - Show the source of contributed features (friction analysis, marker-based execution, etc.)
2. **Context** - Demonstrate battle-tested patterns from production infrastructure work
3. **Reference** - Document the evolution and lessons learned from months of LLM-tmux automation

### Feature Gap Analysis: tmux-sane vs claude-code-tools

Below is what tmux-sane provides that claude-code-tools doesn't (yet). These represent potential future contributions:

#### ✅ Already Contributing to claude-code-tools
- **Exit code extraction** - Marker-based command execution with reliable exit codes ([in progress](https://github.com/ryancnelson/claude-code-tools/tree/feature/exit-code-extraction))

#### 📋 Potential Future Contributions

**High-value gaps:**
- **Pre-flight validation** - Bash/JSON syntax checking before execution (prevents wasted LLM cycles)
- **Platform detection** - OS/arch/hostname detection even over SSH (enables cross-platform workflows)
- **Friction logging** - Operation logging and analysis to identify LLM failure patterns
- **Structured prompts** - Embedded state (sequence numbers, exit codes) for pane identification
- **REPL detection** - Identify and handle REPL environments (Python, MySQL, etc.)
- **File transfer** - Cross-machine file sync via magic-wormhole integration

**Medium-value gaps:**
- **Multi-pane orchestration** - Context management across multiple panes/hosts
- **Health checks** - Pane responsiveness validation before command execution
- **Retry logic** - Exponential backoff for transient failures
- **Performance metrics** - Command timing for optimization analysis

**Lower-priority gaps:**
- **Label system** - Human-readable pane labels for tracking
- **Mode detection** - Distinguish bash vs raw terminal mode
- **Context database** - Persistent pane metadata storage

Each potential contribution would be proposed separately with design discussion before implementation.

---

## What is tmux-sane?

tmux-sane provides high-level primitives that prevent AI agents from getting lost, confused, or making unreliable keystroke-level decisions when controlling tmux sessions. Instead of letting agents improvise at the keystroke level (trying vim commands, guessing escape sequences, etc.), tmux-sane offers a clean API with validation, error recovery, and friction logging.

**SANE** = **S**tructured **A**gent **N**avigation **E**nvironment

## Key Features

- **Structured prompts** with embedded state (sequence numbers, exit codes, timestamps)
- **High-level bash primitives** (create_file, run_command, read_file) - no more keystroke guessing
- **Pre-flight validation** using cheap AI models (AWS Nova Lite) and local tools
- **Platform awareness** (macOS vs Linux vs FreeBSD, tool path mapping)
- **Escape handling** via base64 encoding for complex content
- **Friction logging** to identify and fix common failure patterns
- **Cost-effective** tiered approach (expensive agents for decisions, cheap agents for polling)

## Problem Statement

Current issues with AI-controlled tmux sessions:
- Agents don't reliably detect command completion vs hung commands
- No consistent way to know if output appeared or command is waiting for input
- Escape handling across multiple layers is error-prone
- Common syntax errors (jq, JSON, bash) waste tokens and create friction
- Agents improvise at keystroke level leading to inconsistent behavior

## 22 Available Commands

| Command | Purpose |
|---------|---------|
| `sane-detect-platform` | Detect OS, architecture, hostname, user |
| `sane-detect-mode` | Detect bash vs raw mode in panes |
| `sane-detect-ssh` | Detect SSH connections and remote hosts |
| `sane-list-panes` | List all panes with metadata |
| `sane-list-windows` | List all windows in a session with metadata |
| `sane-check-pane-health` | Check pane responsiveness and health status |
| `sane-run-command` | Execute commands with reliable output capture |
| `sane-send-keys` | Send keystrokes and special keys to panes |
| `sane-create-file` | Create files with automatic escaping |
| `sane-setup-prompt` | Configure structured prompts |
| `sane-context-database` | Manage pane context metadata |
| `sane-label-pane` | Label and track panes |
| `sane-get-label` | Retrieve pane labels |
| `sane-validate-bash` | Validate bash script syntax |
| `sane-validate-json` | Validate JSON payloads |
| `sane-validate-with-ai` | Validate code using AI models |
| `sane-get-tool` | Resolve tool paths across platforms |
| `sane-log-operation` | Log operations for analysis |
| `sane-friction-analysis` | Analyze operational friction patterns |
| `sane-transfer-to-workstation` | Transfer files via wormhole |
| `sane-transfer-from-workstation` | Transfer files via wormhole |
| `sane-wait-ready` | Wait for pane to be ready to accept commands |

## Quick Examples

### Run a command and capture output
```bash
$ ./sane-run-command tues:0.0 "ls -la /tmp" | jq .
{
  "output": "total 123\ndrwxrwxrwt  15 root  wheel  480 Dec  4 10:45 .\n...",
  "exit_code": 0,
  "duration_ms": 245
}
```

### Create a file with automatic escaping
```bash
$ ./sane-create-file tues:0.0 "/tmp/config.json" '{"key": "value", "nested": {"x": 123}}'
{
  "status": "created",
  "path": "/tmp/config.json",
  "checksum": "abc123...",
  "size_bytes": 42
}
```

### Detect platform in any pane
```bash
$ ./sane-detect-platform tues:0.1  # Even over SSH!
{
  "os": "Linux",
  "arch": "x86_64",
  "hostname": "prod-server-01",
  "user": "ubuntu",
  "shell": "bash"
}
```

### Detect mode (bash vs raw) in panes
```bash
$ ./sane-detect-mode tues:0.0
{
  "mode": "bash",
  "shell": "bash",
  "capabilities": ["run_command", "create_file", "read_file", "validate_bash", "validate_json"],
  "supports_structured_prompt": true,
  "bash_specific": {"command_name": "-bash"}
}
```

### Send keystrokes to a pane
```bash
$ ./sane-send-keys tues:0.0 "pwd" "Enter" | jq .
{
  "status": "sent",
  "output": "/Users/ryan/projects/myapp\n$ ",
  "duration_ms": 152,
  "timestamp": "2025-12-04T13:55:22Z"
}
```

### List all panes in a session
```bash
$ ./sane-list-panes tues | jq .
[
  {"pane": "tues:0.0", "label": "local dev", "platform": "Darwin/arm64"},
  {"pane": "tues:0.1", "label": "prod db", "platform": "Linux/x86_64"}
]
```

### List all windows in a session
```bash
$ ./sane-list-windows tues | jq .
{
  "session": "tues",
  "windows": [
    {"id": "@0", "index": 0, "name": "editor", "pane_count": 2},
    {"id": "@1", "index": 1, "name": "deploy", "pane_count": 3}
  ]
}
```

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd tmux-sane
   ```

2. **Create or attach to a tmux session**
   ```bash
   tmux new-session -d -s mywork
   ```

3. **Try the first command**
   ```bash
   ./sane-detect-platform mywork
   ```

4. **Read the guides**
   - Start with [GETTING-STARTED.md](GETTING-STARTED.md) for a walkthrough
   - Check [AGENT-BEST-PRACTICES.md](AGENT-BEST-PRACTICES.md) for patterns
   - Review [DESIGN.md](DESIGN.md) for complete architecture

## Documentation

### For Users
- **[GETTING-STARTED.md](GETTING-STARTED.md)** - Beginner-friendly walkthrough with examples
- **[SAMPLE-WORKFLOW-MULTIFILE.md](SAMPLE-WORKFLOW-MULTIFILE.md)** - Multi-file coordination patterns
- **[MULTI-SERVER-DEPLOY.md](MULTI-SERVER-DEPLOY.md)** - Multi-server orchestration examples
- **[AGENT-BEST-PRACTICES.md](AGENT-BEST-PRACTICES.md)** - Comprehensive patterns and anti-patterns

### For Developers
- **[DESIGN.md](DESIGN.md)** - Complete architecture and API specification
- **[AGENTS.md](AGENTS.md)** - Coding guidelines and error handling patterns
- **[PERFORMANCE-REPORT.md](PERFORMANCE-REPORT.md)** - Performance characteristics and benchmarks

### Release Information
- **[RELEASE-NOTES.md](RELEASE-NOTES.md)** - What's new in v0.1

## Test Coverage

- **31 test suites** covering 391+ scenarios
- **Edge cases**: SSH, REPLs, nested tmux, network devices
- **Workflows**: Multi-file, multi-server, agent patterns
- **Performance**: Command execution, file creation benchmarks
- **Reliability**: Error recovery, timeouts, retries
- **Keystroke handling**: Send keys, special characters, control sequences

All tests pass with consistent, reproducible results.

## Platform Support

- ✅ macOS (Darwin) - arm64 and x86_64
- ✅ Linux - x86_64 and aarch64
- ✅ FreeBSD - compatible
- ✅ Remote hosts via SSH - full support

## Status

✅ **v0.1 - Production Ready** - All features complete, tested, and documented.

- 21 production-grade commands
- 28 development iterations
- 379+ passing tests (15 new tests in iteration 28)
- Comprehensive documentation
- Ready for integration

## Key Achievements

- **Reliability**: 100% test pass rate across all scenarios
- **Performance**: Most operations complete in <1 second
- **Flexibility**: Works with local, SSH, and multi-pane environments
- **Developer Experience**: Clear APIs and extensive documentation

## Common Use Cases

### Multi-pane Automation
Coordinate work across multiple panes/hosts simultaneously with context awareness.

### SSH-based Workflows
Run commands on remote servers with reliable output capture and platform detection.

### File Synchronization
Transfer files between local and remote machines with automatic backups.

### Command Validation
Pre-flight validation of bash/JSON before execution to catch errors early.

### Operational Analysis
Log and analyze operational patterns to identify and fix friction points.

## License

TBD

## Contributing

See [AGENTS.md](AGENTS.md) for development guidelines and code style.

## Support & Feedback

- **Questions?** Check [GETTING-STARTED.md](GETTING-STARTED.md)
- **Issues?** See DESIGN.md and AGENTS.md for troubleshooting
- **Want to contribute?** See [AGENTS.md](AGENTS.md) for development guidelines
- **Found a bug?** Check [BACKLOG.md](BACKLOG.md) for known issues

---

**Start with [GETTING-STARTED.md](GETTING-STARTED.md) for your first 5-minute walkthrough!**
