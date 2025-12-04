# Next Iteration Prompt for tmux-sane

Welcome! You're working on **tmux-sane** - a structured protocol for AI agents to reliably control tmux sessions.

## Quick Orient (READ THIS FIRST!)

**What is tmux-sane?**
- Protocol for AI agents to control tmux panes without getting confused
- Provides high-level primitives (run_command, create_file) instead of raw keystrokes
- Tracks multiple panes/windows with context (which pane is the database, which is the app server)
- Uses cheap AI models for validation and expensive models for decisions

**Key Design Principles:**
1. **Pane-aware** - Every command targets specific panes (SESSION:WINDOW.PANE)
2. **Validated** - Pre-flight checks prevent syntax errors
3. **Structured** - Machine-parseable prompts with state info
4. **Platform-aware** - Knows macOS vs Linux vs FreeBSD
5. **Test-driven** - Write tests first, then implement

## Your Mission This Iteration

1. **Check the backlog**: `cat BACKLOG.md`
2. **Pick ONE Priority 1 item** (30-60 min scope)
3. **Start iteration**: `./scripts/next-iteration.sh <feature-name>`
   - ⚠️ **Known issue**: The script can't actually switch your git branch (subprocess limitation)
   - **What to do**: After running the script, manually switch to the branch it created:
     ```bash
     git checkout -b iteration-N-<feature-name>
     ```
   - Or check `git branch` and switch to the new branch
4. **Write tests first** (in `tests/`)
5. **Implement** (in `lib/` or root for commands)
6. **Run tests**: `./tests/test-*.sh`
7. **Commit**: Tests must pass!

## Key Files

- **DESIGN.md** - Complete architecture and design decisions
- **AGENTS.md** - Coding style, testing, conventions
- **BACKLOG.md** - Prioritized work items
- **README.md** - Project overview
- **lib/** - Reusable library functions
- **tests/** - Test scripts (bash-based)
- **sane-*** - Main command scripts

## Testing Pattern

We use bash-based TDD:

```bash
# 1. Write test first
tests/test-new-feature.sh

# 2. Run test (should fail)
./tests/test-new-feature.sh

# 3. Implement feature
sane-new-feature

# 4. Run test (should pass)
./tests/test-new-feature.sh

# 5. Commit
git add .
git commit -m "feat: add new feature"
```

## Available Tools

**For cheap validation:**
- `ask-nova-lite "question"` - AWS Nova Lite (~$0.00006/call)
- `ask-claude-haiku "question"` - Claude Haiku 4.5

**For code generation:**
- `ask-deepseek-v3 "prompt"` - DeepSeek V3
- `ask-gpt5-codex "prompt"` - GPT-5.1 Codex

**Testing helpers:**
- Active tmux session: `tues` (use for testing)
- `tmux list-panes -t tues` - See pane structure
- `tmux capture-pane -t tues -p` - Read pane contents

## Constraints (IMPORTANT!)

✅ **Time limit:** 30-60 minutes per iteration
✅ **Tests must pass:** No exceptions
✅ **One task only:** No scope creep
✅ **Document as you go:** Update relevant docs

## Common Issues & Solutions

### "The script said it created a branch but I'm still on main"
This is normal! Bash scripts run in subprocesses and can't change the parent shell's branch.

**Solution:** After running `./scripts/next-iteration.sh`, check `git branch` to see the new branch name, then:
```bash
git checkout iteration-N-<feature-name>
```

### When You're Stuck

1. **Too complex?** → Break into smaller pieces, update BACKLOG.md
2. **Not sure what to work on?** → Pick easiest Priority 1 item
3. **Tests failing?** → Fix or revert, never commit broken tests
4. **Lost context?** → Re-read DESIGN.md section relevant to your task

## Strategic Review

Every 8 iterations, we pause and review:
- Are we building the right thing?
- Is the backlog healthy?
- Is code quality maintained?
- Is the process sustainable?

(See STRATEGIC-REVIEW-CHECKLIST.md when you get there)

## Success Looks Like

At the end of this iteration, you should have:
- ✅ One small improvement committed
- ✅ All tests passing
- ✅ Updated documentation (if needed)
- ✅ BACKLOG.md item moved to Completed
- ✅ Clear sense of what's next

## Remember

> "Small, focused, tested improvements done consistently beat big rewrites every time."

You're not trying to build the whole system today. Just make one small thing better.

**Now go check BACKLOG.md and pick something fun!** 🚀
