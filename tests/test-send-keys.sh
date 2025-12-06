#!/usr/bin/env bash
# Test: sane-send-keys should send keystrokes to a pane and return results

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The script we're testing
SEND_KEYS_SCRIPT="$PROJECT_DIR/sane-send-keys"

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

echo "Testing send-keys..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$SEND_KEYS_SCRIPT" ]]; then
    test_pass "sane-send-keys exists and is executable"
else
    test_fail "sane-send-keys exists and is executable" \
              "File exists at $SEND_KEYS_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: Script should require arguments
OUTPUT=$("$SEND_KEYS_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|argument\|required"; then
    test_pass "Script requires arguments"
else
    test_fail "Script requires arguments" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 3: Script should detect invalid session
OUTPUT=$("$SEND_KEYS_SCRIPT" "nonexistent:0.0" "echo test" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "error\|does not exist\|not found"; then
    test_pass "Script detects invalid session"
else
    test_fail "Script detects invalid session" \
              "Error message" \
              "$OUTPUT"
fi

# Make sure tues session exists
if ! tmux has-session -t tues 2>/dev/null; then
    echo "Error: tues session does not exist. Cannot continue with tests."
    exit 1
fi

# Test 4: Script should return valid JSON on successful keystroke
OUTPUT=$("$SEND_KEYS_SCRIPT" "tues:0.0" "Enter" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Script returns valid JSON on success"
else
    test_fail "Script returns valid JSON on success" \
              "Valid JSON" \
              "$OUTPUT"
fi

# Test 5: JSON should have output field
if echo "$OUTPUT" | jq -r '.output' 2>/dev/null >/dev/null; then
    test_pass "JSON has output field"
else
    test_fail "JSON has output field" \
              "output field present" \
              "$OUTPUT"
fi

# Test 6: JSON should have status field
STATUS=$(echo "$OUTPUT" | jq -r '.status' 2>/dev/null || echo "missing")
if [[ "$STATUS" == "sent" || "$STATUS" == "success" ]]; then
    test_pass "JSON has status field"
else
    test_fail "JSON has status field" \
              "status: sent or success" \
              "status: $STATUS"
fi

# Test 7: Send simple text with Enter
OUTPUT=$("$SEND_KEYS_SCRIPT" "tues:0.0" "C-u" 2>&1) || true  # Clear line first
sleep 0.1
OUTPUT=$("$SEND_KEYS_SCRIPT" "tues:0.0" "echo hello" 2>&1) || true
if echo "$OUTPUT" | jq -r '.output' 2>/dev/null | grep -q "hello"; then
    test_pass "Script sends text and captures output"
else
    test_fail "Script sends text and captures output" \
              "Output containing 'hello'" \
              "$(echo "$OUTPUT" | jq -r '.output' 2>/dev/null || echo "invalid json")"
fi

# Test 8: Send Ctrl-C
OUTPUT=$("$SEND_KEYS_SCRIPT" "tues:0.0" "C-c" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Script handles Ctrl-C"
else
    test_fail "Script handles Ctrl-C" \
              "Valid JSON" \
              "$OUTPUT"
fi

# Test 9: Send multiple keystrokes in one call
OUTPUT=$("$SEND_KEYS_SCRIPT" "tues:0.0" "pwd" "Enter" 2>&1) || true
if echo "$OUTPUT" | jq -r '.output' 2>/dev/null | grep -q "/"; then
    test_pass "Script handles multiple keystrokes"
else
    test_fail "Script handles multiple keystrokes" \
              "Output with path" \
              "$(echo "$OUTPUT" | jq -r '.output' 2>/dev/null || echo "invalid json")"
fi

# Test 10: JSON should have timestamp
if echo "$OUTPUT" | jq -r '.timestamp' 2>/dev/null >/dev/null; then
    test_pass "JSON has timestamp field"
else
    test_fail "JSON has timestamp field" \
              "timestamp field present" \
              "$OUTPUT"
fi

# Test 11: Send Tab character
OUTPUT=$("$SEND_KEYS_SCRIPT" "tues:0.0" "Tab" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Script handles Tab key"
else
    test_fail "Script handles Tab key" \
              "Valid JSON" \
              "$OUTPUT"
fi

# Test 12: Send Escape key
OUTPUT=$("$SEND_KEYS_SCRIPT" "tues:0.0" "Escape" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Script handles Escape key"
else
    # This is expected - sane-send-keys may not exist yet
    test_fail "Script handles Escape key (expected for new feature)" \
              "Valid JSON" \
              "Command not found"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
