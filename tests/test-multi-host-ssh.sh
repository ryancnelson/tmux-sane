#!/usr/bin/env bash
# Test: Multi-Host SSH Session (Edge Case Test 1)
#
# This test verifies that tmux-sane correctly handles multi-host scenarios:
# - Remote pane (Linux via SSH) can be detected and controlled
# - Context database tracks remote pane metadata correctly
# - Commands execute successfully on remote panes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DETECT_PLATFORM="$PROJECT_DIR/sane-detect-platform"
CONTEXT_DB="$PROJECT_DIR/sane-context-database"
RUN_COMMAND="$PROJECT_DIR/sane-run-command"

SESSION="tues"
REMOTE_PANE="$SESSION:0.0"

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
    if [[ -n "${TEST_CONTEXT_DIR:-}" ]] && [[ -d "$TEST_CONTEXT_DIR" ]]; then
        rm -rf "$TEST_CONTEXT_DIR"
    fi
}

# Register cleanup
trap cleanup EXIT

# Create temp directory for test context
TEST_CONTEXT_DIR=$(mktemp -d)
export TMUX_SANE_CONTEXT_HOME="$TEST_CONTEXT_DIR"

echo "=========================================="
echo "Edge Case Test 1: Multi-Host SSH Session"
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
echo "Test Suite 1: Remote Platform Detection"
echo "======================================"
echo ""

echo "Test 1.1: Remote platform detection"
set +e
REMOTE_DETECT=$("$DETECT_PLATFORM" "$REMOTE_PANE" 2>&1)
DETECT_EXIT=$?
set -e

if [[ $DETECT_EXIT -eq 0 ]]; then
    test_pass "sane-detect-platform runs on remote pane"
else
    test_fail "sane-detect-platform runs" "exit 0" "exit $DETECT_EXIT"
fi

if echo "$REMOTE_DETECT" | jq empty 2>/dev/null; then
    test_pass "Remote detection returns valid JSON"
else
    test_fail "Returns valid JSON" "valid JSON" "invalid: $REMOTE_DETECT"
fi

echo ""
echo "Test Suite 2: Remote Command Execution"
echo "======================================"
echo ""

echo "Test 2.1: Execute command on remote"
set +e
HOSTNAME_OUTPUT=$("$RUN_COMMAND" "$REMOTE_PANE" "hostname" 2>&1)
CMD_EXIT=$?
set -e

if [[ $CMD_EXIT -eq 0 ]]; then
    test_pass "sane-run-command executes on remote"
else
    test_fail "Remote command execution" "exit 0" "exit $CMD_EXIT"
fi

HOSTNAME_CODE=$(echo "$HOSTNAME_OUTPUT" | jq -r '.exit_code' 2>/dev/null || echo "")
if [[ "$HOSTNAME_CODE" == "0" ]]; then
    test_pass "Remote hostname command succeeded"
else
    test_fail "Remote command exit code" "0" "$HOSTNAME_CODE"
fi

echo ""
echo "Test Suite 3: Context Database"
echo "============================="
echo ""

echo "Test 3.1: Store remote context"
set +e
CONTEXT_CREATE=$("$CONTEXT_DB" create "$REMOTE_PANE" \
    --platform "linux" \
    --mode "bash" \
    --label "remote-hp2" 2>&1)
CREATE_EXIT=$?
set -e

if [[ $CREATE_EXIT -eq 0 ]]; then
    test_pass "Context creation succeeds"
else
    test_fail "Context creation" "exit 0" "exit $CREATE_EXIT: $CONTEXT_CREATE"
fi

echo ""
echo "Test 3.2: Retrieve remote context"
set +e
CONTEXT_READ=$("$CONTEXT_DB" read "$REMOTE_PANE" 2>&1)
READ_EXIT=$?
set -e

if [[ $READ_EXIT -eq 0 ]]; then
    test_pass "Context retrieval succeeds"
else
    test_fail "Context retrieval" "exit 0" "exit $READ_EXIT"
fi

LABEL=$(echo "$CONTEXT_READ" | jq -r '.label' 2>/dev/null || echo "")
if [[ "$LABEL" == "remote-hp2" ]]; then
    test_pass "Context label stored and retrieved"
else
    test_fail "Label retrieval" "remote-hp2" "$LABEL"
fi

echo ""
echo "=========================================="
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
echo "=========================================="
echo ""

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo "✓ Multi-host SSH support verified!"
    exit 0
else
    FAILED=$((TESTS_RUN - TESTS_PASSED))
    echo "✗ $FAILED test(s) failed"
    exit 1
fi
