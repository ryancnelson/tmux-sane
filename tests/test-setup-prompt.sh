#!/usr/bin/env bash
# Test: sane-setup-prompt should set up a structured PS1 prompt in a pane

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The script we're testing
SETUP_PROMPT_SCRIPT="$PROJECT_DIR/sane-setup-prompt"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

test_pass() {
    echo "✓ $1"
    ((TESTS_PASSED=TESTS_PASSED+1))
    ((TESTS_RUN=TESTS_RUN+1))
}

test_fail() {
    echo "✗ $1"
    echo "  Expected: $2"
    echo "  Got: $3"
    ((TESTS_RUN=TESTS_RUN+1))
}

echo "Testing setup-prompt..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$SETUP_PROMPT_SCRIPT" ]]; then
    test_pass "sane-setup-prompt exists and is executable"
else
    test_fail "sane-setup-prompt exists and is executable" \
              "File exists at $SETUP_PROMPT_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: Script should require a pane argument
OUTPUT=$("$SETUP_PROMPT_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|argument\|required"; then
    test_pass "Script requires pane argument"
else
    test_fail "Script requires pane argument" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 3: Script should detect invalid session
OUTPUT=$("$SETUP_PROMPT_SCRIPT" "nonexistent:0.0" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "error\|does not exist\|not found"; then
    test_pass "Script detects invalid session"
else
    test_fail "Script detects invalid session" \
              "Error message" \
              "$OUTPUT"
fi

# Test 4: Script should return valid JSON when successful
# First, let's make sure we have the tues session
if tmux has-session -t tues 2>/dev/null; then
    OUTPUT=$("$SETUP_PROMPT_SCRIPT" "tues:0.0" 2>&1) || true
    if echo "$OUTPUT" | jq empty 2>/dev/null; then
        test_pass "Script returns valid JSON on success"
    else
        test_fail "Script returns valid JSON on success" \
                  "Valid JSON" \
                  "$OUTPUT"
    fi
    
    # Test 5: JSON should have status field
    STATUS=$(echo "$OUTPUT" | jq -r '.status' 2>/dev/null || echo "missing") || true
    if [[ "$STATUS" == "success" || "$STATUS" == "completed" ]]; then
        test_pass "JSON has status field with success value"
    else
        test_fail "JSON has status field with success value" \
                  "status: success" \
                  "status: $STATUS"
    fi
    
    # Test 6: JSON should have pane field
    if echo "$OUTPUT" | jq -e '.pane' > /dev/null 2>&1; then
        test_pass "JSON has pane field"
        PANE=$(echo "$OUTPUT" | jq -r '.pane') || true
        if [[ "$PANE" == "tues:0.0" ]]; then
            test_pass "Pane field matches input"
        else
            test_fail "Pane field matches input" "tues:0.0" "$PANE"
        fi
    else
        test_fail "JSON has pane field" "pane field present" "field missing"
    fi
    
    # Test 7: Script should handle SESSION:WINDOW format (active pane)
    OUTPUT=$("$SETUP_PROMPT_SCRIPT" "tues:0" 2>&1) || true
    if echo "$OUTPUT" | jq empty 2>/dev/null; then
        test_pass "Script works with SESSION:WINDOW format"
    else
        test_fail "Script works with SESSION:WINDOW format" \
                  "Valid JSON" \
                  "$OUTPUT"
    fi
    
    # Test 8: Script should handle SESSION format (active pane)
    OUTPUT=$("$SETUP_PROMPT_SCRIPT" "tues" 2>&1) || true
    if echo "$OUTPUT" | jq empty 2>/dev/null; then
        test_pass "Script works with SESSION format"
    else
        test_fail "Script works with SESSION format" \
                  "Valid JSON" \
                  "$OUTPUT"
    fi
    
    # Test 9: Verify PS1 is actually set in the pane (capture-pane check)
    # Send a command to output PS1 variable
    tmux send-keys -t "tues:0.0" "echo 'PS1_SET'" Enter
    sleep 0.5
    PANE_CONTENT=$(tmux capture-pane -t "tues:0.0" -p)
    if echo "$PANE_CONTENT" | grep -q "seq:"; then
        test_pass "PS1 contains sequence counter (seq:)"
    else
        # This is informational - the PS1 may not show immediately
        echo "ℹ PS1 sequence counter not yet visible in pane (may be normal on first check)"
        ((TESTS_RUN=TESTS_RUN+1))
    fi
    
else
    echo "Skipping session tests: 'tues' session not available"
    echo "(These tests require an active tmux session)"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
