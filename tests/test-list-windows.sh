#!/usr/bin/env bash
# Test sane-list-windows command
# Lists all windows in a tmux session with metadata

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LIST_WINDOWS_SCRIPT="$PROJECT_DIR/sane-list-windows"
SESSION="tues"

TESTS_PASSED=0
TESTS_TOTAL=0

echo "Testing sane-list-windows command..."
echo ""

# Test 1: Verify script exists and is executable
echo "Test 1: Script exists and is executable"
((TESTS_TOTAL++))
if [[ -x "$LIST_WINDOWS_SCRIPT" ]]; then
    echo "✓ Script exists and is executable"
    ((TESTS_PASSED++))
else
    echo "✗ Script missing or not executable"
fi
echo ""

# Test 2: List windows in valid session
echo "Test 2: List windows in valid session"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$LIST_WINDOWS_SCRIPT" "$SESSION" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.windows' > /dev/null 2>&1; then
    echo "✓ List windows in session successful"
    ((TESTS_PASSED++))
else
    echo "✗ List windows in session failed (exit code: $RESULT)"
    echo "Output: $OUTPUT"
fi
echo ""

# Test 3: Verify JSON structure contains required fields
echo "Test 3: JSON has required fields"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$LIST_WINDOWS_SCRIPT" "$SESSION" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.windows[0] | has("id") and has("index") and has("name")' > /dev/null 2>&1; then
    echo "✓ JSON structure is correct"
    ((TESTS_PASSED++))
else
    echo "✗ JSON structure incomplete (exit code: $RESULT)"
    echo "Output: $OUTPUT"
fi
echo ""

# Test 4: Verify windows have pane_count
echo "Test 4: Windows include pane_count"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$LIST_WINDOWS_SCRIPT" "$SESSION" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.windows[0] | has("pane_count")' > /dev/null 2>&1; then
    echo "✓ Windows include pane_count"
    ((TESTS_PASSED++))
else
    echo "✗ Windows missing pane_count (exit code: $RESULT)"
fi
echo ""

# Test 5: Error handling - missing session argument
echo "Test 5: Error handling - missing arguments"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$LIST_WINDOWS_SCRIPT" 2>&1) || RESULT=$?

if [[ $RESULT -ne 0 ]]; then
    echo "✓ Missing arguments error caught"
    ((TESTS_PASSED++))
else
    echo "✗ Missing arguments should fail"
fi
echo ""

# Test 6: Error handling - non-existent session
echo "Test 6: Error handling - non-existent session"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$LIST_WINDOWS_SCRIPT" "nonexistent-session-xyz" 2>&1) || RESULT=$?

if [[ $RESULT -ne 0 ]]; then
    echo "✓ Non-existent session error caught"
    ((TESTS_PASSED++))
else
    echo "✗ Non-existent session should fail"
fi
echo ""

# Test 7: Session field in output
echo "Test 7: Output includes session name"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$LIST_WINDOWS_SCRIPT" "$SESSION" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e ".session == \"$SESSION\"" > /dev/null 2>&1; then
    echo "✓ Output includes session name"
    ((TESTS_PASSED++))
else
    echo "✗ Session name missing from output (exit code: $RESULT)"
fi
echo ""

# Test 8: Return valid JSON
echo "Test 8: Output is valid JSON"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$LIST_WINDOWS_SCRIPT" "$SESSION" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq empty > /dev/null 2>&1; then
    echo "✓ Output is valid JSON"
    ((TESTS_PASSED++))
else
    echo "✗ Output is not valid JSON (exit code: $RESULT)"
fi
echo ""

echo "Results: $TESTS_PASSED/$TESTS_TOTAL tests passed"

if [[ $TESTS_PASSED -ne $TESTS_TOTAL ]]; then
    exit 1
fi
