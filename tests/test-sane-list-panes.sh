#!/usr/bin/env bash
# Test sane-list-panes command

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LIST_PANES_SCRIPT="$PROJECT_DIR/sane-list-panes"
SESSION="tues"

TESTS_PASSED=0
TESTS_TOTAL=0

echo "Testing sane-list-panes command..."
echo ""

# Test 1: List panes in session (success case)
echo "Test 1: List panes in valid session"
((TESTS_TOTAL++))
OUTPUT=$("$LIST_PANES_SCRIPT" "$SESSION" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.panes' > /dev/null 2>&1; then
    echo "✓ List panes in session"
    ((TESTS_PASSED++))
else
    echo "✗ List panes in session (exit code: $RESULT)"
fi
echo ""

# Test 2: List panes in non-existent session (failure case)
echo "Test 2: List panes in invalid session"
((TESTS_TOTAL++))
OUTPUT=$("$LIST_PANES_SCRIPT" "nonexistent-session-xyz" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -ne 0 ]]; then
    echo "✓ List panes with invalid session (correctly failed)"
    ((TESTS_PASSED++))
else
    echo "✗ List panes with invalid session (should have failed)"
fi
echo ""

# Test 3: Verify JSON structure
echo "Test 3: Verify JSON structure"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$LIST_PANES_SCRIPT" "$SESSION" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.session and .panes' > /dev/null 2>&1; then
    echo "✓ JSON has session and panes fields"
    ((TESTS_PASSED++))
else
    echo "✗ JSON structure is invalid"
fi
echo ""

# Test 4: Verify pane object structure
echo "Test 4: Verify pane object fields"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$LIST_PANES_SCRIPT" "$SESSION" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.panes[0].id and .panes[0].window and .panes[0].index' > /dev/null 2>&1; then
    echo "✓ Pane objects have required fields (id, window, index)"
    ((TESTS_PASSED++))
else
    echo "✗ Pane objects missing required fields"
fi
echo ""

echo "Results: $TESTS_PASSED/$TESTS_TOTAL tests passed"

if [[ $TESTS_PASSED -eq $TESTS_TOTAL ]]; then
    exit 0
else
    exit 1
fi
