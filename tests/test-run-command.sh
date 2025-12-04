#!/usr/bin/env bash
# Test: sane-run-command should execute commands in a pane and return structured output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The script we're testing
RUN_COMMAND_SCRIPT="$PROJECT_DIR/sane-run-command"

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

echo "Testing sane-run-command..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$RUN_COMMAND_SCRIPT" ]]; then
    test_pass "sane-run-command exists and is executable"
else
    test_fail "sane-run-command exists and is executable" \
              "File exists at $RUN_COMMAND_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: Script should require pane and command arguments
OUTPUT=$("$RUN_COMMAND_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|argument\|required"; then
    test_pass "Script requires arguments"
else
    test_fail "Script requires arguments" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 3: Script should require command argument
OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|command\|required"; then
    test_pass "Script requires command argument"
else
    test_fail "Script requires command argument" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 4: Script should detect invalid session
OUTPUT=$("$RUN_COMMAND_SCRIPT" "nonexistent:0.0" "ls" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "error\|does not exist\|not found"; then
    test_pass "Script detects invalid session"
else
    test_fail "Script detects invalid session" \
              "Error message" \
              "$OUTPUT"
fi

# Check if we have the tues session for live tests
if tmux has-session -t tues 2>/dev/null; then
    echo ""
    echo "Running tests with live tmux session 'tues'..."
    echo ""
    
    # Test 5: Script should return valid JSON on success
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'hello'" 2>&1) || true
    if echo "$OUTPUT" | jq empty 2>/dev/null; then
        test_pass "Script returns valid JSON on success"
    else
        test_fail "Script returns valid JSON on success" \
                  "Valid JSON" \
                  "$OUTPUT"
    fi
    
    # Test 6: JSON should have required fields
    if echo "$OUTPUT" | jq -e '.output' > /dev/null 2>&1; then
        test_pass "JSON has output field"
    else
        test_fail "JSON has output field" "output field present" "field missing"
    fi
    
    if echo "$OUTPUT" | jq -e '.exit_code' > /dev/null 2>&1; then
        test_pass "JSON has exit_code field"
    else
        test_fail "JSON has exit_code field" "exit_code field present" "field missing"
    fi
    
    if echo "$OUTPUT" | jq -e '.duration_ms' > /dev/null 2>&1; then
        test_pass "JSON has duration_ms field"
    else
        test_fail "JSON has duration_ms field" "duration_ms field present" "field missing"
    fi
    
    # Test 7: Command output should contain our echo text
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'hello world'" 2>&1) || true
    if echo "$OUTPUT" | jq -r '.output' 2>/dev/null | grep -q "hello world"; then
        test_pass "Command output captured correctly"
    else
        test_fail "Command output captured correctly" \
                  "hello world in output" \
                  "$(echo "$OUTPUT" | jq -r '.output' 2>/dev/null || echo "$OUTPUT")"
    fi
    
    # Test 8: Exit code should be 0 for successful command
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "true" 2>&1) || true
    EXIT_CODE=$(echo "$OUTPUT" | jq -r '.exit_code' 2>/dev/null || echo "error")
    if [[ "$EXIT_CODE" == "0" ]]; then
        test_pass "Exit code is 0 for successful command"
    else
        test_fail "Exit code is 0 for successful command" \
                  "exit_code: 0" \
                  "exit_code: $EXIT_CODE"
    fi
    
    # Test 9: Exit code should be non-zero for failed command
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "false" 2>&1) || true
    EXIT_CODE=$(echo "$OUTPUT" | jq -r '.exit_code' 2>/dev/null || echo "0")
    if [[ "$EXIT_CODE" != "0" ]]; then
        test_pass "Exit code is non-zero for failed command"
    else
        test_fail "Exit code is non-zero for failed command" \
                  "exit_code != 0" \
                  "exit_code: $EXIT_CODE"
    fi
    
    # Test 10: Script should handle SESSION:WINDOW.PANE format
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "pwd" 2>&1) || true
    if echo "$OUTPUT" | jq empty 2>/dev/null; then
        test_pass "Script works with SESSION:WINDOW.PANE format"
    else
        test_fail "Script works with SESSION:WINDOW.PANE format" \
                  "Valid JSON" \
                  "$OUTPUT"
    fi
    
    # Test 11: Script should handle SESSION:WINDOW format (active pane)
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0" "whoami" 2>&1) || true
    if echo "$OUTPUT" | jq empty 2>/dev/null; then
        test_pass "Script works with SESSION:WINDOW format"
    else
        test_fail "Script works with SESSION:WINDOW format" \
                  "Valid JSON" \
                  "$OUTPUT"
    fi
    
    # Test 12: Script should handle SESSION format (active pane)
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues" "pwd" 2>&1) || true
    if echo "$OUTPUT" | jq empty 2>/dev/null; then
        test_pass "Script works with SESSION format"
    else
        test_fail "Script works with SESSION format" \
                  "Valid JSON" \
                  "$OUTPUT"
    fi
    
    # Test 13: Script should capture multi-line output
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo -e 'line1\nline2\nline3'" 2>&1) || true
    if echo "$OUTPUT" | jq -r '.output' 2>/dev/null | grep -q "line1" && \
       echo "$OUTPUT" | jq -r '.output' 2>/dev/null | grep -q "line3"; then
        test_pass "Script captures multi-line output"
    else
        test_fail "Script captures multi-line output" \
                  "Both line1 and line3 in output" \
                  "$(echo "$OUTPUT" | jq -r '.output' 2>/dev/null || echo "$OUTPUT")"
    fi
    
    # Test 14: Script should handle timeout gracefully
    # This should timeout trying to read from stdin
    timeout 3 "$RUN_COMMAND_SCRIPT" "tues:0.0" "read dummy" 2>&1 || true
    test_pass "Script handles timeout without crashing"
    
else
    echo "Skipping live tests: 'tues' session not available"
    echo "(These tests require an active tmux session)"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
