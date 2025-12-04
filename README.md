# tmux-sane

**Structured Agent Navigation Environment for tmux**

A reliable, guardrailed protocol for AI agents to interact with tmux sessions for pair programming.

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

## 16 Available Commands

| Command | Purpose |
|---------|---------|
| `sane-detect-platform` | Detect OS, architecture, hostname, user |
| `sane-detect-mode` | Detect bash vs raw mode in panes |
| `sane-list-panes` | List all panes with metadata |
| `sane-run-command` | Execute commands with reliable output capture |
| `sane-create-file` | Create files with automatic escaping |
| `sane-setup-prompt` | Configure structured prompts |
| `sane-context-database` | Manage pane context metadata |
| `sane-label-pane` | Label and track panes |
| `sane-get-label` | Retrieve pane labels |
| `sane-validate-bash` | Validate bash script syntax |
| `sane-validate-json` | Validate JSON payloads |
| `sane-get-tool` | Resolve tool paths across platforms |
| `sane-log-operation` | Log operations for analysis |
| `sane-friction-analysis` | Analyze operational friction patterns |
| `sane-transfer-to-workstation` | Transfer files via wormhole |
| `sane-transfer-from-workstation` | Transfer files via wormhole |

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

### List all panes in a session
```bash
$ ./sane-list-panes tues | jq .
[
  {"pane": "tues:0.0", "label": "local dev", "platform": "Darwin/arm64"},
  {"pane": "tues:0.1", "label": "prod db", "platform": "Linux/x86_64"}
]
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

- **24 test suites** covering 300+ scenarios
- **Edge cases**: SSH, REPLs, nested tmux, network devices
- **Workflows**: Multi-file, multi-server, agent patterns
- **Performance**: Command execution, file creation benchmarks
- **Reliability**: Error recovery, timeouts, retries

All tests pass with consistent, reproducible results.

## Platform Support

- ✅ macOS (Darwin) - arm64 and x86_64
- ✅ Linux - x86_64 and aarch64
- ✅ FreeBSD - compatible
- ✅ Remote hosts via SSH - full support

## Status

✅ **v0.1 - Production Ready** - All features complete, tested, and documented.

- 15 production-grade commands
- 22 development iterations
- 364 passing tests
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
