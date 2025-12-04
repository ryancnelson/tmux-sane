#!/usr/bin/env bash
# Test: sane-log-operation should log operations and sane-friction-analysis should analyze them

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The scripts we're testing
LOG_SCRIPT="$PROJECT_DIR/sane-log-operation"
ANALYSIS_SCRIPT="$PROJECT_DIR/sane-friction-analysis"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Temporary log file for testing
TEST_LOG_DIR=$(mktemp -d)
TEST_LOG="$TEST_LOG_DIR/friction.jsonl"

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

cleanup() {
    rm -rf "$TEST_LOG_DIR"
}

trap cleanup EXIT

echo "Testing friction logging system..."
echo ""

# Test 1: sane-log-operation script should exist and be executable
if [[ -x "$LOG_SCRIPT" ]]; then
    test_pass "sane-log-operation exists and is executable"
else
    test_fail "sane-log-operation exists and is executable" \
              "File exists at $LOG_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: sane-friction-analysis script should exist and be executable
if [[ -x "$ANALYSIS_SCRIPT" ]]; then
    test_pass "sane-friction-analysis exists and is executable"
else
    test_fail "sane-friction-analysis exists and is executable" \
              "File exists at $ANALYSIS_SCRIPT" \
              "File not found or not executable"
fi

# Test 3: Logging a run_command operation should create valid JSON line
echo "Test 3: Logging run_command operation..."
OUTPUT=$("$LOG_SCRIPT" \
    --log-file "$TEST_LOG" \
    --event "run_command" \
    --command "ls -la" \
    --platform "darwin_arm64" \
    --validation "passed" \
    --exit-code "0" \
    --duration-ms "125" \
    2>&1) || true

if [[ -f "$TEST_LOG" ]]; then
    test_pass "Log file created"
    
    # Read the log line
    LOG_LINE=$(cat "$TEST_LOG")
    if echo "$LOG_LINE" | jq empty 2>/dev/null; then
        test_pass "Log entry is valid JSON"
        
        # Check required fields
        TIMESTAMP=$(echo "$LOG_LINE" | jq -r '.timestamp' 2>/dev/null) || true
        if [[ -n "$TIMESTAMP" && "$TIMESTAMP" != "null" ]]; then
            test_pass "Log entry has timestamp field"
        else
            test_fail "Log entry has timestamp field" "non-null timestamp" "$TIMESTAMP"
        fi
        
        EVENT=$(echo "$LOG_LINE" | jq -r '.event' 2>/dev/null) || true
        if [[ "$EVENT" == "run_command" ]]; then
            test_pass "Log entry has correct event type"
        else
            test_fail "Log entry has correct event type" "run_command" "$EVENT"
        fi
        
        COMMAND=$(echo "$LOG_LINE" | jq -r '.command' 2>/dev/null) || true
        if [[ "$COMMAND" == "ls -la" ]]; then
            test_pass "Log entry has correct command"
        else
            test_fail "Log entry has correct command" "ls -la" "$COMMAND"
        fi
    else
        test_fail "Log entry is valid JSON" "Valid JSON" "$LOG_LINE"
    fi
else
    test_fail "Log file created" "File exists at $TEST_LOG" "File not created"
fi

# Test 4: Logging multiple operations should append to file
echo "Test 4: Logging multiple operations..."
"$LOG_SCRIPT" \
    --log-file "$TEST_LOG" \
    --event "run_command" \
    --command "grep pattern file.txt" \
    --platform "linux_x86_64" \
    --validation "passed" \
    --exit-code "0" \
    --duration-ms "42" \
    > /dev/null 2>&1 || true

LINE_COUNT=$(wc -l < "$TEST_LOG")
if [[ "$LINE_COUNT" -ge 2 ]]; then
    test_pass "Multiple operations append to log file"
else
    test_fail "Multiple operations append to log file" "2+ lines" "$LINE_COUNT lines"
fi

# Test 5: Each log line should be valid JSON individually
echo "Test 5: Validating all log lines as JSON..."
ALL_VALID=true
while IFS= read -r line; do
    if ! echo "$line" | jq empty 2>/dev/null; then
        ALL_VALID=false
        break
    fi
done < "$TEST_LOG"

if [[ "$ALL_VALID" == "true" ]]; then
    test_pass "All log lines are valid JSON"
else
    test_fail "All log lines are valid JSON" "all lines valid" "some lines invalid"
fi

# Test 6: sane-friction-analysis should work on the log file
echo "Test 6: Analyzing friction log..."
ANALYSIS_OUTPUT=$("$ANALYSIS_SCRIPT" --log-file "$TEST_LOG" 2>&1) || true

if echo "$ANALYSIS_OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Analysis output is valid JSON"
    
    # Check for summary statistics
    TOTAL=$(echo "$ANALYSIS_OUTPUT" | jq -r '.total_operations' 2>/dev/null) || true
    if [[ -n "$TOTAL" && "$TOTAL" != "null" ]]; then
        test_pass "Analysis has total_operations field"
    else
        test_fail "Analysis has total_operations field" "non-null total" "$TOTAL"
    fi
else
    test_fail "Analysis output is valid JSON" "Valid JSON" "$ANALYSIS_OUTPUT"
fi

# Test 7: Logging with validation failure
echo "Test 7: Logging validation failure..."
"$LOG_SCRIPT" \
    --log-file "$TEST_LOG" \
    --event "run_command" \
    --command "grep -P pattern file.txt" \
    --platform "darwin_arm64" \
    --validation "failed" \
    --reason "BSD grep has no -P flag" \
    --exit-code "1" \
    --duration-ms "5" \
    > /dev/null 2>&1 || true

# Check that the failure was recorded
LAST_LINE=$(tail -n 1 "$TEST_LOG")
VALIDATION=$(echo "$LAST_LINE" | jq -r '.validation' 2>/dev/null) || true
if [[ "$VALIDATION" == "failed" ]]; then
    test_pass "Validation failure is logged correctly"
    
    REASON=$(echo "$LAST_LINE" | jq -r '.reason' 2>/dev/null) || true
    if [[ "$REASON" == "BSD grep has no -P flag" ]]; then
        test_pass "Failure reason is captured"
    else
        test_fail "Failure reason is captured" "BSD grep has no -P flag" "$REASON"
    fi
else
    test_fail "Validation failure is logged correctly" "failed" "$VALIDATION"
fi

# Test 8: Analysis should report validation pass/fail rates
echo "Test 8: Analysis validation statistics..."
# Create a fresh log with known mix
rm "$TEST_LOG"
"$LOG_SCRIPT" --log-file "$TEST_LOG" --event "cmd1" --validation "passed" > /dev/null 2>&1 || true
"$LOG_SCRIPT" --log-file "$TEST_LOG" --event "cmd2" --validation "passed" > /dev/null 2>&1 || true
"$LOG_SCRIPT" --log-file "$TEST_LOG" --event "cmd3" --validation "failed" > /dev/null 2>&1 || true

ANALYSIS_OUTPUT=$("$ANALYSIS_SCRIPT" --log-file "$TEST_LOG" 2>&1) || true
if echo "$ANALYSIS_OUTPUT" | jq -e '.validation_stats' > /dev/null 2>&1; then
    test_pass "Analysis includes validation statistics"
else
    test_fail "Analysis includes validation statistics" "validation_stats present" "field missing"
fi

# Test 9: Logging without log file should use default location
echo "Test 9: Default log file location..."
HOME_LOG="$HOME/.tmux-sane/friction.jsonl"
OUTPUT=$("$LOG_SCRIPT" --event "test" --command "echo test" 2>&1) || true

# Check if default location was used
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Logging without --log-file uses default location"
elif [[ -f "$HOME_LOG" ]]; then
    test_pass "Logging without --log-file uses default location"
else
    test_fail "Logging without --log-file uses default location" "file created at $HOME_LOG" "file not created"
fi

# Test 10: Analysis on empty/non-existent log should handle gracefully
echo "Test 10: Analysis on empty log..."
EMPTY_LOG="$TEST_LOG_DIR/empty.jsonl"
touch "$EMPTY_LOG"
ANALYSIS_OUTPUT=$("$ANALYSIS_SCRIPT" --log-file "$EMPTY_LOG" 2>&1) || true

if echo "$ANALYSIS_OUTPUT" | jq -e '.total_operations' > /dev/null 2>&1; then
    TOTAL=$(echo "$ANALYSIS_OUTPUT" | jq -r '.total_operations')
    if [[ "$TOTAL" == "0" ]]; then
        test_pass "Analysis handles empty log gracefully"
    else
        test_fail "Analysis handles empty log gracefully" "total_operations=0" "total_operations=$TOTAL"
    fi
else
    test_fail "Analysis handles empty log gracefully" "valid analysis output" "$ANALYSIS_OUTPUT"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
