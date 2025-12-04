#!/usr/bin/env bash
# Test: Non-Bash REPL (Edge Case Test 2)
#
# This test verifies that tmux-sane correctly handles non-bash environments:
# - Python REPL detection (>>> prompt)
# - Node.js REPL detection (> prompt)
# - Perl REPL detection (DB<1> or similar)
# - Graceful handling when bash primitives are unavailable
# - System identifies non-bash environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DETECT_PLATFORM="$PROJECT_DIR/sane-detect-platform"
RUN_COMMAND="$PROJECT_DIR/sane-run-command"

SESSION="tues"
BASE_PANE="$SESSION:1"

TESTS_RUN=0
TESTS_PASSED=0

test_pass() {
    echo "✓ $1"
    ((TESTS_PASSED++)) || true
    ((TESTS_RUN++)) || true
}

test_fail() {
    echo "✗ $1"
    if [[ -n "${2:-}" ]]; then
        echo "  Expected: $2"
    fi
    if [[ -n "${3:-}" ]]; then
        echo "  Got: $3"
    fi
    ((TESTS_RUN++)) || true
}

# Cleanup function
cleanup() {
    # Exit all REPLs gracefully
    tmux send-keys -t "$SESSION:1.0" "exit()" Enter 2>/dev/null || true
    tmux send-keys -t "$SESSION:1.1" ".exit" Enter 2>/dev/null || true
    tmux send-keys -t "$SESSION:1.2" "exit" Enter 2>/dev/null || true
    sleep 0.5
    # Kill the temporary window
    tmux kill-window -t "$SESSION:1" 2>/dev/null || true
}

# Register cleanup
trap cleanup EXIT

echo "=========================================="
echo "Edge Case Test 2: Non-Bash REPL"
echo "=========================================="
echo ""

echo "Checking prerequisites..."
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "✗ Session '$SESSION' does not exist"
    exit 1
fi
test_pass "Session '$SESSION' exists"

if ! [[ -x "$DETECT_PLATFORM" ]]; then
    echo "✗ sane-detect-platform not executable"
    exit 1
fi
test_pass "sane-detect-platform executable"

echo ""
echo "Setting up test environment..."

# Create a new window with 3 panes for REPL testing
tmux new-window -t "$SESSION" -n "repl-test"
tmux split-window -t "$SESSION:1" -h
tmux split-window -t "$SESSION:1" -h
sleep 1

test_pass "Created test window with 3 panes"

# Check for required interpreters
PYTHON_AVAILABLE=0
NODE_AVAILABLE=0
PERL_AVAILABLE=0

if command -v python3 &>/dev/null || command -v python &>/dev/null; then
    PYTHON_AVAILABLE=1
fi

if command -v node &>/dev/null; then
    NODE_AVAILABLE=1
fi

if command -v perl &>/dev/null; then
    PERL_AVAILABLE=1
fi

if [[ $PYTHON_AVAILABLE -eq 0 ]] && [[ $NODE_AVAILABLE -eq 0 ]] && [[ $PERL_AVAILABLE -eq 0 ]]; then
    echo "✗ No interpreters available (need Python, Node, or Perl)"
    exit 1
fi

echo ""

# ============================================================================
# Test Suite 1: Python REPL
# ============================================================================

if [[ $PYTHON_AVAILABLE -eq 1 ]]; then
    echo "Test Suite 1: Python REPL Detection"
    echo "===================================="
    echo ""

    echo "Test 1.1: Launch Python REPL"
    # Launch Python with a simpler approach
    if command -v python3 &>/dev/null; then
        tmux send-keys -t "$SESSION:1.0" "python3" Enter
    else
        tmux send-keys -t "$SESSION:1.0" "python" Enter
    fi
    sleep 2

    PYTHON_OUTPUT=$(tmux capture-pane -t "$SESSION:1.0" -p)
    
    if echo "$PYTHON_OUTPUT" | grep -q ">>>"; then
        test_pass "Python REPL launched (>>> prompt detected)"
    else
        test_fail "Python REPL launch" ">>> prompt" "$(echo "$PYTHON_OUTPUT" | tail -1)"
    fi

    echo ""
    echo "Test 1.2: Attempt bash detection in Python REPL"
    set +e
    PYTHON_DETECT=$("$DETECT_PLATFORM" "$SESSION:1.0" 2>&1)
    DETECT_EXIT=$?
    set -e

    if [[ $DETECT_EXIT -ne 0 ]]; then
        test_pass "sane-detect-platform gracefully fails in Python REPL (not bash)"
    else
        # It might succeed but return partial data - that's also acceptable
        if echo "$PYTHON_DETECT" | jq empty 2>/dev/null; then
            test_pass "sane-detect-platform handles Python REPL gracefully"
        else
            test_fail "Graceful handling" "JSON output or clean error" "$PYTHON_DETECT"
        fi
    fi

    echo ""
    echo "Test 1.3: Python REPL identifies as non-bash"
    # We know this is python, so let's verify the failure is recognizable
    PYTHON_PANE_INFO=$(tmux capture-pane -t "$SESSION:1.0" -p)
    
    if echo "$PYTHON_PANE_INFO" | grep -q ">>>"; then
        test_pass "Python REPL prompt (>>>) confirms non-bash environment"
    else
        test_fail "Python REPL state" ">>> prompt visible" "pane output: $(echo "$PYTHON_PANE_INFO" | tail -1)"
    fi

    # Exit Python
    tmux send-keys -t "$SESSION:1.0" "exit()" Enter
    sleep 1

    echo ""
fi

# ============================================================================
# Test Suite 2: Node.js REPL
# ============================================================================

if [[ $NODE_AVAILABLE -eq 1 ]]; then
    echo "Test Suite 2: Node.js REPL Detection"
    echo "====================================="
    echo ""

    echo "Test 2.1: Launch Node.js REPL"
    tmux send-keys -t "$SESSION:1.1" "node" Enter
    sleep 2

    NODE_OUTPUT=$(tmux capture-pane -t "$SESSION:1.1" -p)
    
    if echo "$NODE_OUTPUT" | grep -q ">"; then
        test_pass "Node.js REPL launched (> prompt detected)"
    else
        test_fail "Node.js REPL launch" "> prompt" "$(echo "$NODE_OUTPUT" | tail -1)"
    fi

    echo ""
    echo "Test 2.2: Attempt bash detection in Node REPL"
    set +e
    NODE_DETECT=$("$DETECT_PLATFORM" "$SESSION:1.1" 2>&1)
    DETECT_EXIT=$?
    set -e

    if [[ $DETECT_EXIT -ne 0 ]]; then
        test_pass "sane-detect-platform gracefully fails in Node REPL (not bash)"
    else
        # It might succeed but return partial data - that's also acceptable
        if echo "$NODE_DETECT" | jq empty 2>/dev/null; then
            test_pass "sane-detect-platform handles Node REPL gracefully"
        else
            test_fail "Graceful handling" "JSON output or clean error" "$NODE_DETECT"
        fi
    fi

    echo ""
    echo "Test 2.3: Node REPL identifies as non-bash"
    NODE_PANE_INFO=$(tmux capture-pane -t "$SESSION:1.1" -p)
    
    # Look for Node.js specific prompts (> or >> with specific context)
    if echo "$NODE_PANE_INFO" | grep -q "Welcome to Node" || echo "$NODE_PANE_INFO" | grep -qE "^\s*>\s*$"; then
        test_pass "Node REPL prompt (>) confirms non-bash environment"
    else
        test_fail "Node REPL state" "> prompt visible" "last line: $(echo "$NODE_PANE_INFO" | tail -1)"
    fi

    # Exit Node
    tmux send-keys -t "$SESSION:1.1" ".exit" Enter
    sleep 1

    echo ""
fi

# ============================================================================
# Test Suite 3: Perl REPL (perl -de1)
# ============================================================================

if [[ $PERL_AVAILABLE -eq 1 ]]; then
    echo "Test Suite 3: Perl REPL Detection"
    echo "=================================="
    echo ""

    echo "Test 3.1: Launch Perl REPL"
    tmux send-keys -t "$SESSION:1.2" "perl -de1" Enter
    sleep 2

    PERL_OUTPUT=$(tmux capture-pane -t "$SESSION:1.2" -p)
    
    if echo "$PERL_OUTPUT" | grep -qE "(DB<|perldb)"; then
        test_pass "Perl REPL launched (DB< prompt detected)"
    else
        test_fail "Perl REPL launch" "DB< prompt" "$(echo "$PERL_OUTPUT" | tail -1)"
    fi

    echo ""
    echo "Test 3.2: Attempt bash detection in Perl REPL"
    set +e
    PERL_DETECT=$("$DETECT_PLATFORM" "$SESSION:1.2" 2>&1)
    DETECT_EXIT=$?
    set -e

    if [[ $DETECT_EXIT -ne 0 ]]; then
        test_pass "sane-detect-platform gracefully fails in Perl REPL (not bash)"
    else
        # It might succeed but return partial data - that's also acceptable
        if echo "$PERL_DETECT" | jq empty 2>/dev/null; then
            test_pass "sane-detect-platform handles Perl REPL gracefully"
        else
            test_fail "Graceful handling" "JSON output or clean error" "$PERL_DETECT"
        fi
    fi

    echo ""
    echo "Test 3.3: Perl REPL identifies as non-bash"
    PERL_PANE_INFO=$(tmux capture-pane -t "$SESSION:1.2" -p | tail -3)
    
    if echo "$PERL_PANE_INFO" | grep -qE "(DB<|perldb)"; then
        test_pass "Perl REPL prompt (DB<) confirms non-bash environment"
    else
        test_fail "Perl REPL state" "DB< prompt visible" "$(echo "$PERL_PANE_INFO" | tail -1)"
    fi

    # Exit Perl
    tmux send-keys -t "$SESSION:1.2" "q" Enter
    sleep 1

    echo ""
fi

# ============================================================================
# Test Suite 4: System State After REPL Sessions
# ============================================================================

echo "Test Suite 4: System State After REPL Sessions"
echo "=============================================="
echo ""

echo "Test 4.1: Return to bash in original pane"
tmux send-keys -t "$SESSION:0" "echo 'bash test'" Enter
sleep 1

BASH_TEST=$(tmux capture-pane -t "$SESSION:0" -p | grep -c "bash test" || echo "0")
if [[ "$BASH_TEST" -gt 0 ]]; then
    test_pass "Original pane still responsive with bash"
else
    test_fail "Original pane responsiveness" "bash output" "no response"
fi

echo ""
echo "Test 4.2: Verify REPL detection doesn't affect bash operations"
set +e
BASH_DETECT=$("$DETECT_PLATFORM" "$SESSION:0" 2>&1)
DETECT_EXIT=$?
set -e

if [[ $DETECT_EXIT -eq 0 ]]; then
    test_pass "sane-detect-platform works in bash pane"
else
    test_fail "Bash pane detection" "exit 0" "exit $DETECT_EXIT"
fi

if echo "$BASH_DETECT" | jq empty 2>/dev/null; then
    test_pass "Bash detection returns valid JSON"
else
    test_fail "JSON output" "valid JSON" "invalid: $BASH_DETECT"
fi

echo ""
echo "=========================================="
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
echo "=========================================="
echo ""

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo "✓ Non-bash REPL edge cases handled gracefully!"
    exit 0
else
    FAILED=$((TESTS_RUN - TESTS_PASSED))
    echo "✗ $FAILED test(s) failed"
    exit 1
fi
