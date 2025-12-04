#!/usr/bin/env bash
# Test: Error recovery mechanisms for sane-* commands
# Tests:
# 1. Timeout handling for hung commands
# 2. Graceful degradation for missing tools
# 3. Retry logic for transient failures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The scripts we're testing
RUN_COMMAND_SCRIPT="$PROJECT_DIR/sane-run-command"
CREATE_FILE_SCRIPT="$PROJECT_DIR/sane-create-file"

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

echo "Testing error recovery mechanisms..."
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

if [[ -x "$CREATE_FILE_SCRIPT" ]]; then
    test_pass "sane-create-file exists and is executable"
else
    test_fail "sane-create-file exists and is executable" \
              "File exists at $CREATE_FILE_SCRIPT" \
              "File not found or not executable"
fi

# Check if we have the tues session for live tests
if tmux has-session -t tues 2>/dev/null; then
    echo ""
    echo "Running tests with live tmux session 'tues'..."
    echo ""
    
    # Test 3: Timeout handling - default timeout should complete quickly
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'quick'" 2>&1) || true
    DURATION=$(echo "$OUTPUT" | jq -r '.duration_ms' 2>/dev/null || echo "error")
    if [[ "$DURATION" != "error" ]] && [[ $DURATION -lt 5000 ]]; then
        test_pass "Quick command completes with reasonable duration"
    else
        test_fail "Quick command completes with reasonable duration" \
                  "duration_ms < 5000" \
                  "duration_ms: $DURATION"
    fi
    
    # Test 4: Timeout parameter validation - invalid timeout should be rejected
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'test'" "invalid_timeout" 2>&1) || true
    if echo "$OUTPUT" | grep -q "Error\|timeout must be"; then
        test_pass "Invalid timeout parameter is rejected"
    else
        test_fail "Invalid timeout parameter is rejected" \
                  "Error message about invalid timeout" \
                  "$OUTPUT"
    fi
    
    # Test 5: Timeout parameter validation - negative timeout should be rejected
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'test'" "-5" 2>&1) || true
    if echo "$OUTPUT" | grep -q "Error\|timeout\|number"; then
        test_pass "Negative timeout is rejected"
    else
        test_fail "Negative timeout is rejected" \
                  "Error message" \
                  "$OUTPUT"
    fi
    
    # Test 6: Command with short timeout should complete
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'test'" "2" 2>&1) || true
    if echo "$OUTPUT" | jq -e '.output' > /dev/null 2>&1; then
        test_pass "Command completes with 2-second timeout"
    else
        test_fail "Command completes with 2-second timeout" \
                  "Valid JSON with output" \
                  "$OUTPUT"
    fi
    
    # Test 7: Timeout detection - request should handle timeout gracefully
    # Using a 1-second timeout for a quick command should work
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "sleep 0.1 && echo 'done'" "1" 2>&1) || true
    if echo "$OUTPUT" | jq empty 2>/dev/null; then
        test_pass "Timeout mechanism returns valid JSON"
    else
        test_fail "Timeout mechanism returns valid JSON" \
                  "Valid JSON output" \
                  "$OUTPUT"
    fi
    
    # Test 8: Missing tool detection - non-existent command should fail gracefully
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "nonexistent_command_xyz" 2>&1) || true
    if echo "$OUTPUT" | jq -e '.exit_code' > /dev/null 2>&1; then
        EXIT_CODE=$(echo "$OUTPUT" | jq -r '.exit_code' 2>/dev/null)
        if [[ "$EXIT_CODE" != "0" ]]; then
            test_pass "Non-existent command returns non-zero exit code"
        else
            test_fail "Non-existent command returns non-zero exit code" \
                      "exit_code != 0" \
                      "exit_code: $EXIT_CODE"
        fi
    else
        test_fail "Non-existent command returns valid JSON" \
                  "Valid JSON output" \
                  "$OUTPUT"
    fi
    
    # Test 9: Bash syntax validation - invalid syntax should be caught
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'unclosed quote" 2>&1) || true
    if echo "$OUTPUT" | grep -q "error\|Error\|validation failed\|Syntax error"; then
        test_pass "Invalid bash syntax is caught"
    else
        test_fail "Invalid bash syntax is caught" \
                  "Error message about syntax" \
                  "$OUTPUT"
    fi
    
    # Test 10: Graceful degradation - failed command should include error info
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "test -f /nonexistent/path" 2>&1) || true
    if echo "$OUTPUT" | jq -e '.exit_code' > /dev/null 2>&1; then
        test_pass "Failed command returns valid JSON with exit code"
    else
        test_fail "Failed command returns valid JSON with exit code" \
                  "Valid JSON with exit_code" \
                  "$OUTPUT"
    fi
    
    # Test 11: Create file validation - invalid file path format should be detected
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "" "content" 2>&1) || true
    if echo "$OUTPUT" | grep -q -i "usage\|error\|path\|required"; then
        test_pass "Empty file path is rejected"
    else
        test_fail "Empty file path is rejected" \
                  "Error or usage message" \
                  "$OUTPUT"
    fi
    
    # Test 12: Create file with backup parameter validation
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "/tmp/test.txt" "content" "invalid_bool" 2>&1) || true
    if echo "$OUTPUT" | grep -q -i "error\|backup\|true\|false"; then
        test_pass "Invalid backup parameter is rejected"
    else
        test_fail "Invalid backup parameter is rejected" \
                  "Error message about backup parameter" \
                  "$OUTPUT"
    fi
    
    # Test 13: Create file without backup should still work
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "/tmp/test_no_backup.txt" "test content" "false" 2>&1) || true
    if echo "$OUTPUT" | jq -e '.status' > /dev/null 2>&1; then
        test_pass "Create file with backup=false returns valid JSON"
    else
        test_fail "Create file with backup=false returns valid JSON" \
                  "Valid JSON output" \
                  "$OUTPUT"
    fi
    
    # Test 14: Retry on transient failures - connection issue simulation
    # This tests that the command mechanism itself is robust
    for attempt in {1..3}; do
        OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'attempt $attempt'" 2>&1) || true
        if echo "$OUTPUT" | jq empty 2>/dev/null; then
            if [[ $attempt -eq 1 ]]; then
                test_pass "Multi-attempt execution succeeds"
                break
            fi
        fi
    done
    
    # Test 15: Error recovery - session validation should detect missing sessions
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "nonexistent_session" "echo 'test'" 2>&1) || true
    if echo "$OUTPUT" | grep -q -i "error\|does not exist\|not found"; then
        test_pass "Missing session is detected with clear error"
    else
        test_fail "Missing session is detected with clear error" \
                  "Error message about session" \
                  "$OUTPUT"
    fi
    
    # Test 16: Pane validation - invalid pane should be detected
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:9.9" "echo 'test'" 2>&1) || true
    if echo "$OUTPUT" | grep -q -i "error\|does not exist\|not found\|invalid"; then
        test_pass "Invalid pane is detected"
    else
        test_fail "Invalid pane is detected" \
                  "Error message about invalid pane" \
                  "$OUTPUT"
    fi
    
    # Test 17: Retry parameter validation - invalid retry count should be rejected
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'test'" "30" "invalid_retries" 2>&1) || true
    if echo "$OUTPUT" | grep -q "Error\|retries must be"; then
        test_pass "Invalid max_retries parameter is rejected"
    else
        test_fail "Invalid max_retries parameter is rejected" \
                  "Error message about invalid retry count" \
                  "$OUTPUT"
    fi
    
    # Test 18: Retry parameter - negative retries should be rejected
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'test'" "30" "-1" 2>&1) || true
    if echo "$OUTPUT" | grep -q "Error\|retries\|number"; then
        test_pass "Negative max_retries is rejected"
    else
        test_fail "Negative max_retries is rejected" \
                  "Error message" \
                  "$OUTPUT"
    fi
    
    # Test 19: With retry enabled - successful command should not retry
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'success'" "30" "2" 2>/dev/null) || true
    ATTEMPTS=$(echo "$OUTPUT" | jq -r '.attempts' 2>/dev/null || echo "error")
    if [[ "$ATTEMPTS" == "1" ]]; then
        test_pass "Successful command doesn't retry"
    else
        test_fail "Successful command doesn't retry" \
                  "attempts: 1" \
                  "attempts: $ATTEMPTS"
    fi
    
    # Test 20: Retry information included in response - retried flag should be present
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'test'" "30" "1" 2>/dev/null) || true
    if echo "$OUTPUT" | jq -e 'has("retried")' > /dev/null 2>&1; then
        test_pass "Response includes retried flag"
    else
        test_fail "Response includes retried flag" \
                  "retried field present in JSON" \
                  "$OUTPUT"
    fi
    
    # Test 21: Retry information - attempts count should be present
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'test'" "30" "2" 2>/dev/null) || true
    if echo "$OUTPUT" | jq -e '.attempts' > /dev/null 2>&1; then
        test_pass "Response includes attempts count"
    else
        test_fail "Response includes attempts count" \
                  "attempts field present in JSON" \
                  "$OUTPUT"
    fi
    
    # Test 22: No retry with zero retries - should return quickly
    OUTPUT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "echo 'no-retry'" "30" "0" 2>&1) || true
    if echo "$OUTPUT" | jq -e '.attempts' > /dev/null 2>&1; then
        ATTEMPTS=$(echo "$OUTPUT" | jq -r '.attempts' 2>/dev/null)
        if [[ "$ATTEMPTS" == "1" ]]; then
            test_pass "Zero retries means single execution"
        else
            test_fail "Zero retries means single execution" \
                      "attempts: 1" \
                      "attempts: $ATTEMPTS"
        fi
    else
        test_fail "Zero retries - invalid JSON" \
                  "Valid JSON with attempts" \
                  "$OUTPUT"
    fi
    
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
