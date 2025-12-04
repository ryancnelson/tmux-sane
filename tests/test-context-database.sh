#!/usr/bin/env bash
# Test sane-context-database command
# Tests CRUD operations for pane contexts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONTEXT_DB_SCRIPT="$PROJECT_DIR/sane-context-database"
TEST_CONTEXT_DIR=$(mktemp -d)
trap "rm -rf $TEST_CONTEXT_DIR" EXIT

TESTS_PASSED=0
TESTS_TOTAL=0

export TMUX_SANE_CONTEXT_HOME="$TEST_CONTEXT_DIR"

echo "Testing sane-context-database command..."
echo ""

# Test 1: Create a context
echo "Test 1: Create a context"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$CONTEXT_DB_SCRIPT" create "test-session:0.0" \
  --platform "darwin" \
  --mode "bash" \
  --current_dir "/tmp" \
  --label "test-pane" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.status == "created"' > /dev/null 2>&1; then
    echo "✓ Create context"
    ((TESTS_PASSED++))
else
    echo "✗ Create context (exit code: $RESULT)"
    echo "Output: $OUTPUT"
fi
echo ""

# Test 2: Read a context
echo "Test 2: Read a context"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$CONTEXT_DB_SCRIPT" read "test-session:0.0" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.platform == "darwin"' > /dev/null 2>&1; then
    echo "✓ Read context"
    ((TESTS_PASSED++))
else
    echo "✗ Read context (exit code: $RESULT)"
    echo "Output: $OUTPUT"
fi
echo ""

# Test 3: Update a context
echo "Test 3: Update a context"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$CONTEXT_DB_SCRIPT" update "test-session:0.0" \
  --current_dir "/home" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.status == "updated"' > /dev/null 2>&1; then
    echo "✓ Update context"
    ((TESTS_PASSED++))
else
    echo "✗ Update context (exit code: $RESULT)"
    echo "Output: $OUTPUT"
fi
echo ""

# Test 4: Verify update persisted
echo "Test 4: Verify update persisted"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$CONTEXT_DB_SCRIPT" read "test-session:0.0" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.current_dir == "/home"' > /dev/null 2>&1; then
    echo "✓ Update persisted"
    ((TESTS_PASSED++))
else
    echo "✗ Update did not persist"
    echo "Output: $OUTPUT"
fi
echo ""

# Test 5: Delete a context
echo "Test 5: Delete a context"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$CONTEXT_DB_SCRIPT" delete "test-session:0.0" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.status == "deleted"' > /dev/null 2>&1; then
    echo "✓ Delete context"
    ((TESTS_PASSED++))
else
    echo "✗ Delete context (exit code: $RESULT)"
    echo "Output: $OUTPUT"
fi
echo ""

# Test 6: Verify deletion
echo "Test 6: Verify deletion (read should fail)"
((TESTS_TOTAL++))
RESULT=0
OUTPUT=$("$CONTEXT_DB_SCRIPT" read "test-session:0.0" 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -ne 0 ]]; then
    echo "✓ Deletion verified (read failed as expected)"
    ((TESTS_PASSED++))
else
    echo "✗ Deletion failed (read should not work)"
fi
echo ""

# Test 7: List all contexts
echo "Test 7: List all contexts"
((TESTS_TOTAL++))
# First create a few contexts
$CONTEXT_DB_SCRIPT create "session1:0.0" --platform "darwin" --mode "bash" --current_dir "/tmp" --label "pane1" > /dev/null 2>&1
$CONTEXT_DB_SCRIPT create "session1:0.1" --platform "linux" --mode "bash" --current_dir "/home" --label "pane2" > /dev/null 2>&1

RESULT=0
OUTPUT=$("$CONTEXT_DB_SCRIPT" list 2>&1) || RESULT=$?
RESULT=${RESULT:-0}

if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.contexts | length >= 2' > /dev/null 2>&1; then
    echo "✓ List contexts"
    ((TESTS_PASSED++))
else
    echo "✗ List contexts (exit code: $RESULT)"
    echo "Output: $OUTPUT"
fi
echo ""

echo "Results: $TESTS_PASSED/$TESTS_TOTAL tests passed"

if [[ $TESTS_PASSED -eq $TESTS_TOTAL ]]; then
    exit 0
else
    exit 1
fi
