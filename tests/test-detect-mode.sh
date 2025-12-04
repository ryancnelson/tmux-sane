#!/usr/bin/env bash
# Test: Detect mode (bash vs raw) in tmux panes
# Tests sane-detect-mode command for identifying bash vs non-bash environments

PROJECT_DIR="/Volumes/T9/ryan-homedir/devel/tmux-sane"
DETECT_MODE_SCRIPT="$PROJECT_DIR/sane-detect-mode"
SESSION="tues"

TESTS_RUN=0
TESTS_PASSED=0

test_pass() {
    echo "✓ $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_fail() {
    echo "✗ $1"
    echo "  Expected: $2"
    echo "  Got: $3"
    ((TESTS_RUN++))
}

echo "Testing mode detection in tmux session '$SESSION'..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$DETECT_MODE_SCRIPT" ]]; then
    test_pass "sane-detect-mode exists and is executable"
else
    test_fail "sane-detect-mode exists and is executable" \
              "File exists at $DETECT_MODE_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Ensure session exists
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Error: Session '$SESSION' does not exist"
    echo "Create it first: tmux new-session -d -s $SESSION"
    exit 1
fi

# Test 2: Should work with existing tmux session
OUTPUT=$("$DETECT_MODE_SCRIPT" "$SESSION" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    test_pass "Runs successfully with session '$SESSION'"
else
    test_fail "Runs successfully with session '$SESSION'" \
              "Exit code 0" \
              "Exit code $EXIT_CODE: $OUTPUT"
fi

# Test 3: Should return valid JSON
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Returns valid JSON"
else
    test_fail "Returns valid JSON" "Valid JSON output" "$OUTPUT"
fi

# Test 4: Should include 'mode' field
if echo "$OUTPUT" | jq -e '.mode' > /dev/null 2>&1; then
    test_pass "JSON contains 'mode' field"
    MODE=$(echo "$OUTPUT" | jq -r '.mode')
    echo "  Detected mode: $MODE"
else
    test_fail "JSON contains 'mode' field" "Field 'mode' present" "Field missing"
    MODE="unknown"
fi

# Test 5: Mode should be either 'bash' or 'raw'
if [[ "$MODE" == "bash" ]] || [[ "$MODE" == "raw" ]]; then
    test_pass "Mode is 'bash' or 'raw': $MODE"
else
    test_fail "Mode is 'bash' or 'raw'" "bash or raw" "$MODE"
fi

# Test 6: Should include 'shell' field
if echo "$OUTPUT" | jq -e '.shell' > /dev/null 2>&1; then
    test_pass "JSON contains 'shell' field"
    SHELL=$(echo "$OUTPUT" | jq -r '.shell')
    echo "  Detected shell: $SHELL"
else
    test_fail "JSON contains 'shell' field" "Field 'shell' present" "Field missing"
fi

# Test 7: Should include 'capabilities' field (array)
if echo "$OUTPUT" | jq -e '.capabilities | type' 2>/dev/null | grep -q array; then
    test_pass "JSON contains 'capabilities' array"
else
    test_fail "JSON contains 'capabilities' array" "Array of capabilities" "Field missing or not array"
fi

# Test 8: Should include 'supports_structured_prompt' field
if echo "$OUTPUT" | jq -e '.supports_structured_prompt' > /dev/null 2>&1; then
    test_pass "JSON contains 'supports_structured_prompt' field"
    SUPPORTS=$(echo "$OUTPUT" | jq -r '.supports_structured_prompt')
    echo "  Supports structured prompt: $SUPPORTS"
else
    test_fail "JSON contains 'supports_structured_prompt' field" "Field present" "Field missing"
fi

# Test 9: Test with specific pane (SESSION:WINDOW.PANE format)
PANE_INFO=$(tmux list-panes -t "$SESSION" -F '#{session_name}:#{window_index}.#{pane_index}' | head -1)
OUTPUT=$("$DETECT_MODE_SCRIPT" "$PANE_INFO" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | jq -e '.mode' > /dev/null 2>&1; then
    test_pass "Works with specific pane format ($PANE_INFO)"
else
    test_fail "Works with specific pane format ($PANE_INFO)" \
              "Exit code 0 and valid JSON" \
              "Exit code $EXIT_CODE"
fi

# Test 10: Bash mode should have bash-specific details
if [[ "$MODE" == "bash" ]]; then
    if echo "$OUTPUT" | jq -e '.bash_specific' > /dev/null 2>&1; then
        test_pass "JSON contains 'bash_specific' details for bash mode"
    else
        test_pass "Bash mode detected (bash_specific optional)"
    fi
fi

# Test 11: Should fail gracefully with non-existent session
INVALID_OUTPUT=$("$DETECT_MODE_SCRIPT" "nonexistent-session-$$" 2>&1 || true)
if [[ $? -ne 0 ]] || [[ "$INVALID_OUTPUT" == *"Error"* ]]; then
    test_pass "Fails gracefully with non-existent session"
else
    test_fail "Fails gracefully with non-existent session" \
              "Error or non-zero exit" \
              "Exit code 0"
fi

# Test 12: Should handle invalid pane format
INVALID_OUTPUT=$("$DETECT_MODE_SCRIPT" "$SESSION:invalid-format" 2>&1 || true)
if [[ $? -ne 0 ]] || [[ "$INVALID_OUTPUT" == *"Error"* ]]; then
    test_pass "Fails gracefully with invalid pane format"
else
    test_fail "Fails gracefully with invalid pane format" \
              "Error or non-zero exit" \
              "Exit code 0"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
