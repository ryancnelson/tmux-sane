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

## Documentation

- **[DESIGN.md](DESIGN.md)** - Complete design document with architecture, API specifications, and implementation roadmap
- **[AGENTS.md](AGENTS.md)** - Guidelines for AI coding agents working on this codebase

## Quick Example

```bash
# Traditional approach (error-prone):
# Agent tries to type commands character-by-character, gets confused by prompts

# tmux-sane approach (reliable):
tmux-sane run-command "ls -la /tmp"
# Returns structured JSON: {output, exit_code, duration, platform_info}

tmux-sane create-file "/tmp/config.json" '{"key": "value"}'
# Handles escaping automatically, returns: {status, backup_path, checksum}
```

## Status

🚧 **In Design Phase** - Currently defining the protocol and API. See DESIGN.md for details.

## License

TBD

## Contributing

TBD
