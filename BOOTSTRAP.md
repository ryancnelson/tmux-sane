# Welcome to tmux-sane! 👋

Hello! You're a fresh AI assistant who just got assigned to work on **tmux-sane**.

## Step 1: Orient Yourself (5 minutes)

Run these commands to understand what you're working on:

```bash
cd /Volumes/T9/ryan-homedir/devel/tmux-sane

# Read the project overview
cat README.md

# Understand the architecture
cat DESIGN.md | head -100

# Check coding guidelines
cat AGENTS.md

# See what work is available
cat BACKLOG.md
```

## Step 2: Understand the Current State (2 minutes)

```bash
# What iteration are we on?
cat .iteration-count

# What's been completed so far?
git log --oneline

# What tests exist?
ls -la tests/

# What commands are implemented?
ls -la sane-*
```

## Step 3: Start Your First Iteration (30-60 minutes)

```bash
# Pick a Priority 1 item from BACKLOG.md that sounds interesting

# Start the iteration
./scripts/next-iteration.sh <feature-name>

# This will:
# - Create a git branch
# - Increment iteration count
# - Show you Priority 1 items
# - Set you up to work
```

## Step 4: Follow the TDD Pattern

1. **Write a test first** (in `tests/`)
2. **Run the test** (it should fail - that's good!)
3. **Implement the feature**
4. **Run the test again** (it should pass)
5. **Commit** (tests must pass!)

## Step 5: When You're Done

```bash
# Make sure tests pass
./tests/test-*.sh

# Commit your work
git add .
git commit -m "feat: what you built"

# Merge to main
git checkout main
git merge <your-branch>

# Update BACKLOG.md
# Move your completed item to the "Completed" section
```

## Key Principles to Remember

1. **Time-boxed**: 30-60 minutes per iteration (if it's taking longer, break it down)
2. **Test-driven**: Always write tests first
3. **One thing at a time**: No scope creep
4. **Pane-aware**: Commands should target specific panes (SESSION:WINDOW.PANE)
5. **Platform-aware**: Know if you're on macOS vs Linux vs FreeBSD

## The Big Picture

**tmux-sane** solves a real problem: AI agents get confused controlling tmux sessions.

Instead of letting agents improvise keystrokes, we provide:
- High-level primitives (run_command, create_file)
- Validation (catch syntax errors before sending)
- Context tracking (which pane is which)
- Platform detection (macOS vs Linux)
- Structured prompts (machine-parseable state)

## Available Resources

**Testing environment:**
- Active tmux session: `tues` (use this for testing)
- Commands: `tmux list-panes -t tues`, `tmux capture-pane -t tues -p`

**AI helpers for validation:**
- `ask-nova-lite "question"` - Super cheap (~$0.00006/call)
- `ask-claude-haiku "question"` - Cheap, smart
- `ask-deepseek-v3 "prompt"` - For code generation

**Documentation:**
- DESIGN.md - Complete architecture
- AGENTS.md - Coding style
- BACKLOG.md - What to work on
- NEXT-ITERATION-PROMPT.md - Detailed workflow

## Your Mission

You're not here to build the whole system. You're here to make **one small improvement** that moves the project forward.

Pick something from Priority 1 in BACKLOG.md that:
- Sounds interesting to you
- Is scoped to 30-60 minutes
- Has clear value

Then follow the TDD pattern and ship it! 🚀

## Questions?

- **"What should I work on?"** → Check BACKLOG.md Priority 1
- **"How do I test this?"** → Look at existing tests in `tests/` for patterns
- **"Is this the right approach?"** → Check DESIGN.md for architectural decisions
- **"My iteration is taking too long"** → Break it into smaller pieces, update backlog
- **"Tests are failing"** → Fix them or revert, never commit broken tests

## Remember

> "Small, focused, tested improvements done consistently beat big rewrites every time."

**Now go build something cool!**

---

*After 8 iterations, you'll do a Strategic Review. But for now, just focus on your first iteration. You've got this!*
