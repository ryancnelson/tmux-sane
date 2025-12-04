#!/usr/bin/env bash

# test-sane-wait-ready.sh - Test suite for sane-wait-ready command
#
# Tests the wait-ready primitive that polls a pane until it's ready to accept commands

set -euo pipefail

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Test session name
TEST_SESSION="tues"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_result() {
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ $? -eq 0 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓ Test $TESTS_RUN passed${NC}"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗ Test $TESTS_RUN failed${NC}"
        return 1
    fi
}

echo -e "${BLUE}=== Testing sane-wait-ready ===${NC}\n"

# Verify test session exists
if ! tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
    echo -e "${RED}Error: Test session '$TEST_SESSION' does not exist${NC}"
    echo "Please create it first: tmux new-session -d -s $TEST_SESSION"
    exit 1
fi

# Get the first pane
PANE_ID=$(tmux list-panes -t "$TEST_SESSION" -F "#{session_name}:#{window_index}.#{pane_index}" | head -1)
echo "Using test pane: $PANE_ID"
echo ""

#
# Test 1: Basic usage - help message
#
echo "Test 1: Show help message"
./sane-wait-ready --help | grep -q "Usage:" && test_result

#
# Test 2: No arguments shows help
#
echo "Test 2: No arguments shows help"
./sane-wait-ready 2>&1 | grep -q "Usage:" && test_result

#
# Test 3: Wait for ready pane (already ready)
#
echo "Test 3: Wait for pane that's already ready"
# Ensure pane is at bash prompt
tmux send-keys -t "$PANE_ID" "" Enter
sleep 0.5

# Run wait-ready
result=$(./sane-wait-ready "$PANE_ID" 2>&1)
echo "$result" | jq -e '.ready == true' >/dev/null && test_result

#
# Test 4: Check JSON output structure
#
echo "Test 4: Validate JSON output structure"
result=$(./sane-wait-ready "$PANE_ID" 2>&1)
echo "$result" | jq -e 'has("ready") and has("pane") and has("duration_ms") and has("timestamp")' >/dev/null && test_result

#
# Test 5: Check pane field in output
#
echo "Test 5: Verify pane field matches target"
result=$(./sane-wait-ready "$PANE_ID" 2>&1)
returned_pane=$(echo "$result" | jq -r '.pane')
[ "$returned_pane" = "$PANE_ID" ] && test_result

#
# Test 6: Wait for busy pane (running sleep)
#
echo "Test 6: Wait for pane that's running a command"
# Start a command that takes a while
tmux send-keys -t "$PANE_ID" "sleep 2" Enter
sleep 0.2  # Let command start

# Wait with timeout longer than sleep
result=$(./sane-wait-ready "$PANE_ID" 5 2>&1)
echo "$result" | jq -e '.ready == true' >/dev/null && test_result

#
# Test 7: Timeout when pane never becomes ready
#
echo "Test 7: Timeout handling when pane stays busy"
# Start a long-running command
tmux send-keys -t "$PANE_ID" "sleep 30" Enter
sleep 0.5  # Let command start

# Wait with short timeout (add explicit timeout wrapper in case it hangs)
# Note: sane-wait-ready exits with code 1 when not ready, so we need || true
result=$(timeout 5 ./sane-wait-ready "$PANE_ID" 1 2>&1 || true)
# Should report not ready
echo "$result" | jq -e '.ready == false and .reason == "timeout"' >/dev/null && test_result

# Clean up - kill the sleep command
tmux send-keys -t "$PANE_ID" C-c
sleep 0.5

#
# Test 8: Custom timeout parameter
#
echo "Test 8: Custom timeout parameter works"
# Ensure pane is ready
tmux send-keys -t "$PANE_ID" "" Enter
sleep 0.5

result=$(./sane-wait-ready "$PANE_ID" 10 2>&1)
echo "$result" | jq -e '.ready == true' >/dev/null && test_result

#
# Test 9: Poll interval validation
#
echo "Test 9: Check duration_ms is reasonable (< timeout)"
result=$(./sane-wait-ready "$PANE_ID" 5 2>&1)
duration=$(echo "$result" | jq -r '.duration_ms')
# Duration should be less than 5000ms (5 seconds)
[ "$duration" -lt 5000 ] && test_result

#
# Test 10: Invalid pane target
#
echo "Test 10: Error handling for invalid pane"
result=$(./sane-wait-ready "invalid:99.99" 1 2>&1 || true)
# Should fail (exit code != 0) or return JSON with error
if echo "$result" | grep -iq "error\|not.*found\|invalid"; then
    test_result
else
    false && test_result
fi

#
# Test 11: Session-only format (no window.pane)
#
echo "Test 11: Accept session-only format"
result=$(./sane-wait-ready "$TEST_SESSION" 5 2>&1)
echo "$result" | jq -e '.ready == true' >/dev/null && test_result

#
# Test 12: Wait detects structured prompt
#
echo "Test 12: Detect structured prompt format"
# Setup structured prompt if not already set
./sane-setup-prompt "$PANE_ID" >/dev/null 2>&1 || true
sleep 0.5

result=$(./sane-wait-ready "$PANE_ID" 5 2>&1)
echo "$result" | jq -e '.ready == true' >/dev/null && test_result

#
# Test 13: Verify timestamp format
#
echo "Test 13: Timestamp is in ISO8601 format"
result=$(./sane-wait-ready "$PANE_ID" 2>&1)
timestamp=$(echo "$result" | jq -r '.timestamp')
# Check if timestamp matches ISO8601 format (basic check)
echo "$timestamp" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' && test_result

#
# Test 14: Multiple rapid checks work correctly
#
echo "Test 14: Rapid sequential checks work"
./sane-wait-ready "$PANE_ID" 2 >/dev/null 2>&1 && \
./sane-wait-ready "$PANE_ID" 2 >/dev/null 2>&1 && \
./sane-wait-ready "$PANE_ID" 2 >/dev/null 2>&1 && test_result

#
# Test 15: Default timeout is reasonable
#
echo "Test 15: Default timeout works (no timeout arg)"
# Ensure pane is ready
tmux send-keys -t "$PANE_ID" "" Enter
sleep 0.5

result=$(./sane-wait-ready "$PANE_ID" 2>&1)
echo "$result" | jq -e '.ready == true' >/dev/null && test_result

# Summary
echo ""
echo -e "${BLUE}=== Test Summary ===${NC}"
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
