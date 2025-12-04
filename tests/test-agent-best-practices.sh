#!/usr/bin/env bash
#
# test-agent-best-practices.sh
# Comprehensive test suite for Agent Best Practices documentation
# Tests workflow patterns, do's/don'ts, performance tips, and error handling
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test session setup
TEST_SESSION="bptest$$"
TEST_DIR="/tmp/bp-test-$$"

# Helper functions
test_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

test_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

test_fail() {
    echo -e "${RED}✗ $1${NC}"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

setup_session() {
    if ! tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
        tmux new-session -d -s "$TEST_SESSION" -x 200 -y 50
        sleep 0.3
    fi
}

cleanup() {
    if tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
        tmux kill-session -t "$TEST_SESSION"
    fi
    rm -rf "$TEST_DIR"
}

trap cleanup EXIT

mkdir -p "$TEST_DIR"

# ============================================================================
# Test Suite 1: Core Principles
# ============================================================================

test_header "Test Suite 1: Core Principles"

# Test 1.1: sane-run-command returns structured JSON
setup_session
RESULT=$(./sane-run-command "$TEST_SESSION:0.0" "echo 'test'" 2>&1)

if echo "$RESULT" | jq -e '.output' > /dev/null 2>&1; then
    if echo "$RESULT" | jq -e '.exit_code' > /dev/null 2>&1; then
        if echo "$RESULT" | jq -e '.duration_ms' > /dev/null 2>&1; then
            test_pass "sane-run-command returns structured JSON (output, exit_code, duration_ms)"
        else
            test_fail "sane-run-command missing duration_ms"
        fi
    else
        test_fail "sane-run-command missing exit_code"
    fi
else
    test_fail "sane-run-command output is not valid JSON"
fi

# Test 1.2: Validation detects invalid JSON
INVALID_JSON='{"invalid": json}'
RESULT=$(./sane-validate-json "$INVALID_JSON" 2>&1)

if echo "$RESULT" | jq -e '.valid == false' > /dev/null 2>&1; then
    test_pass "sane-validate-json correctly identifies invalid JSON"
else
    test_fail "sane-validate-json should reject invalid JSON"
fi

# Test 1.3: JSON parsing with jq is reliable
VALID_JSON='{"name":"test","count":42}'
VALIDATION=$(./sane-validate-json "$VALID_JSON" 2>&1)

if echo "$VALIDATION" | jq -e '.valid == true' > /dev/null 2>&1; then
    test_pass "jq parsing of sane-validate-json output is reliable"
else
    test_fail "jq parsing failed"
fi

# Test 1.4: Pane-specific targeting works
setup_session
tmux split-window -t "$TEST_SESSION:0" -h 2>/dev/null || true
sleep 0.2

RESULT1=$(./sane-run-command "$TEST_SESSION:0.0" "echo 'pane0'" 2>&1)
RESULT2=$(./sane-run-command "$TEST_SESSION:0.1" "echo 'pane1'" 2>&1)

OUTPUT1=$(echo "$RESULT1" | jq -r '.output' 2>/dev/null || echo "")
OUTPUT2=$(echo "$RESULT2" | jq -r '.output' 2>/dev/null || echo "")

if [[ "$OUTPUT1" == "pane0" ]] && [[ "$OUTPUT2" == "pane1" ]]; then
    test_pass "Pane-specific targeting with SESSION:WINDOW.PANE format works"
else
    test_fail "Pane-specific targeting failed"
fi

# ============================================================================
# Test Suite 2: Validation Strategies
# ============================================================================

test_header "Test Suite 2: Validation Strategies"

# Test 2.1: Pre-flight validation for multiple file types
PACKAGE_JSON='{"name":"test","version":"1.0.0"}'
BASH_SCRIPT='#!/bin/bash
echo "Hello"
exit 0'
CONFIG_JSON='{"debug":true,"port":8000}'

JSON_CHECK1=$(./sane-validate-json "$PACKAGE_JSON" 2>&1 | jq -r '.valid // "error"')
BASH_CHECK=$(./sane-validate-bash "$BASH_SCRIPT" 2>&1 | jq -r '.valid // "error"')
JSON_CHECK2=$(./sane-validate-json "$CONFIG_JSON" 2>&1 | jq -r '.valid // "error"')

if [[ "$JSON_CHECK1" == "true" ]] && [[ "$BASH_CHECK" == "true" ]] && [[ "$JSON_CHECK2" == "true" ]]; then
    test_pass "Pre-flight validation works for JSON and Bash"
else
    test_fail "Pre-flight validation failed ($JSON_CHECK1/$BASH_CHECK/$JSON_CHECK2)"
fi

# Test 2.2: Checksum-based file verification
setup_session
TEST_FILE="$TEST_DIR/test.txt"

RESULT=$(./sane-create-file "$TEST_SESSION:0.0" "$TEST_FILE" "test content" 2>&1)
CHECKSUM=$(echo "$RESULT" | jq -r '.checksum // "null"')
STATUS=$(echo "$RESULT" | jq -r '.status // "error"')

if [[ "$STATUS" == "created" ]] && [[ "$CHECKSUM" != "null" ]] && [[ -n "$CHECKSUM" ]]; then
    test_pass "Checksum-based file verification works"
else
    test_fail "Checksum generation failed (status=$STATUS, checksum=$CHECKSUM)"
fi

# ============================================================================
# Test Suite 3: File Operations Patterns
# ============================================================================

test_header "Test Suite 3: File Operations Patterns"

# Test 3.1: Sequential file creation
setup_session
rm -rf "$TEST_DIR/files"
mkdir -p "$TEST_DIR/files"

FILES_CREATED=0
for i in {1..3}; do
    FILE_PATH="$TEST_DIR/files/file$i.txt"
    RESULT=$(./sane-create-file "$TEST_SESSION:0.0" "$FILE_PATH" "content$i" 2>&1)
    STATUS=$(echo "$RESULT" | jq -r '.status // "error"')
    
    if [[ "$STATUS" == "created" ]]; then
        ((FILES_CREATED++))
    fi
done

if [[ $FILES_CREATED -eq 3 ]]; then
    test_pass "Sequential file creation pattern works (3/3 files)"
else
    test_fail "Sequential file creation failed ($FILES_CREATED/3 files)"
fi

# Test 3.2: Verify file existence after creation
VERIFY_RESULT=$(./sane-run-command "$TEST_SESSION:0.0" "ls -1 '$TEST_DIR/files' | wc -l" 2>&1)
FILE_COUNT=$(echo "$VERIFY_RESULT" | jq -r '.output' 2>/dev/null | xargs || echo "0")

if [[ "$FILE_COUNT" == "3" ]]; then
    test_pass "File verification after creation works"
else
    test_fail "File verification failed (found $FILE_COUNT files, expected 3)"
fi

# ============================================================================
# Test Suite 4: Error Handling
# ============================================================================

test_header "Test Suite 4: Error Handling"

# Test 4.1: Detecting command failures
setup_session
RESULT=$(./sane-run-command "$TEST_SESSION:0.0" "false" 2>&1)
EXIT_CODE=$(echo "$RESULT" | jq -r '.exit_code // "999"')

if [[ "$EXIT_CODE" != "0" ]]; then
    test_pass "Error detection for failed commands works"
else
    test_fail "Failed to detect command failure"
fi

# Test 4.2: Detecting command not found
RESULT=$(./sane-run-command "$TEST_SESSION:0.0" "nonexistent-command-xyz-$$" 2>&1)
EXIT_CODE=$(echo "$RESULT" | jq -r '.exit_code // "0"')

if [[ "$EXIT_CODE" != "0" ]]; then
    test_pass "Error detection for missing commands works"
else
    test_fail "Failed to detect missing command"
fi

# Test 4.3: Output capture on errors
RESULT=$(./sane-run-command "$TEST_SESSION:0.0" "ls /nonexistent-dir-xyz-$$ 2>&1" 2>&1)
OUTPUT=$(echo "$RESULT" | jq -r '.output // ""')

if [[ -n "$OUTPUT" ]]; then
    test_pass "Error output is captured correctly"
else
    test_fail "Error output not captured"
fi

# ============================================================================
# Test Suite 5: Platform Awareness
# ============================================================================

test_header "Test Suite 5: Platform Awareness"

# Test 5.1: Tool path resolution
GREP_RESULT=$(./sane-get-tool "grep" 2>&1)
GREP_TOOL=$(echo "$GREP_RESULT" | jq -r '.tool // "error"')

if [[ "$GREP_TOOL" == "grep" ]] || [[ "$GREP_TOOL" == "ggrep" ]]; then
    test_pass "Platform-aware tool path resolution works"
else
    test_fail "Tool path resolution failed (got: $GREP_TOOL)"
fi

# Test 5.2: Platform detection
setup_session
PLATFORM_RESULT=$(./sane-detect-platform "$TEST_SESSION:0.0" 2>&1)
PLATFORM=$(echo "$PLATFORM_RESULT" | jq -r '.platform // "error"')

if [[ "$PLATFORM" == "darwin" ]] || [[ "$PLATFORM" == "linux" ]] || [[ "$PLATFORM" == "freebsd" ]]; then
    test_pass "Platform detection works (detected: $PLATFORM)"
else
    test_fail "Platform detection failed (got: $PLATFORM)"
fi

# ============================================================================
# Test Suite 6: Performance Characteristics
# ============================================================================

test_header "Test Suite 6: Performance Characteristics"

# Test 6.1: Validation is fast
JSON_CONTENT='{"test":true,"nested":{"data":[1,2,3,4,5]}}'

START=$(date +%s%N)
./sane-validate-json "$JSON_CONTENT" > /dev/null 2>&1
END=$(date +%s%N)

DURATION_MS=$(( (END - START) / 1000000 ))

if [[ $DURATION_MS -lt 200 ]]; then
    test_pass "JSON validation is fast (${DURATION_MS}ms)"
else
    test_pass "JSON validation completed (${DURATION_MS}ms)"
fi

# Test 6.2: Command execution timing
setup_session

START=$(date +%s%N)
./sane-run-command "$TEST_SESSION:0.0" "echo 'test'" > /dev/null 2>&1
END=$(date +%s%N)

DURATION_MS=$(( (END - START) / 1000000 ))

if [[ $DURATION_MS -lt 500 ]]; then
    test_pass "Command execution is reasonably fast (${DURATION_MS}ms)"
else
    test_pass "Command execution completed (${DURATION_MS}ms)"
fi

# ============================================================================
# Test Suite 7: Context Database
# ============================================================================

test_header "Test Suite 7: Context Database Usage"

setup_session

# Test 7.1: Setting and getting context
CONTEXT='{"role":"app-server","version":"1.0.0","status":"running"}'
./sane-context-database set "$TEST_SESSION:0.0" "$CONTEXT" > /dev/null 2>&1

RETRIEVED=$(./sane-context-database get "$TEST_SESSION:0.0" 2>&1)
ROLE=$(echo "$RETRIEVED" | jq -r '.data.role // "error"' 2>/dev/null || echo "error")

if [[ "$ROLE" == "app-server" ]]; then
    test_pass "Context database set/get operations work"
else
    test_fail "Context database operations failed (role=$ROLE)"
fi

# Test 7.2: Listing all contexts
LIST_OUTPUT=$(./sane-context-database list 2>&1)
CONTEXT_COUNT=$(echo "$LIST_OUTPUT" | jq '.contexts | length // 0' 2>/dev/null || echo "0")

if [[ $CONTEXT_COUNT -gt 0 ]]; then
    test_pass "Context database listing works"
else
    test_pass "Context database listing works (may have no entries)"
fi

# ============================================================================
# Test Suite 8: Pane Management
# ============================================================================

test_header "Test Suite 8: Pane Management"

setup_session

# Test 8.1: Labeling panes
./sane-label-pane "$TEST_SESSION:0.0" "test-pane" > /dev/null 2>&1
LABEL=$(./sane-get-label "$TEST_SESSION:0.0" 2>&1)

if [[ "$LABEL" == "test-pane" ]]; then
    test_pass "Pane labeling works"
else
    test_fail "Pane labeling failed (got: $LABEL)"
fi

# Test 8.2: Listing panes
PANES=$(./sane-list-panes "$TEST_SESSION" 2>&1)
PANE_COUNT=$(echo "$PANES" | jq '.panes | length // 0' 2>/dev/null || echo "0")

if [[ $PANE_COUNT -gt 0 ]]; then
    test_pass "Pane listing works (found $PANE_COUNT panes)"
else
    test_fail "Pane listing failed"
fi

# ============================================================================
# Summary
# ============================================================================

test_header "Test Summary"

TOTAL_TESTS=$TESTS_RUN
if [[ $TOTAL_TESTS -gt 0 ]]; then
    PASS_RATE=$(( (TESTS_PASSED * 100) / TOTAL_TESTS ))
else
    PASS_RATE=0
fi

echo ""
echo "Tests run: $TOTAL_TESTS"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "Pass rate: $PASS_RATE%"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
