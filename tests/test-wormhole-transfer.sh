#!/usr/bin/env bash
# Test: sane-transfer-to-workstation and sane-transfer-from-workstation for wormhole-based file transfers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The scripts we're testing
TRANSFER_TO_SCRIPT="$PROJECT_DIR/sane-transfer-to-workstation"
TRANSFER_FROM_SCRIPT="$PROJECT_DIR/sane-transfer-from-workstation"
RUN_COMMAND_SCRIPT="$PROJECT_DIR/sane-run-command"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Unique suffix for test files
TEST_SUFFIX="$$-$RANDOM"
TEST_DIR="/tmp/sane-wormhole-test-$TEST_SUFFIX"

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
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

trap cleanup EXIT

echo "Testing wormhole file transfer..."
echo ""

# Create test directory
mkdir -p "$TEST_DIR"

# Test 1: sane-transfer-to-workstation script should exist and be executable
if [[ -x "$TRANSFER_TO_SCRIPT" ]]; then
    test_pass "sane-transfer-to-workstation exists and is executable"
else
    test_fail "sane-transfer-to-workstation exists and is executable" \
              "File exists at $TRANSFER_TO_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: sane-transfer-from-workstation script should exist and be executable
if [[ -x "$TRANSFER_FROM_SCRIPT" ]]; then
    test_pass "sane-transfer-from-workstation exists and is executable"
else
    test_fail "sane-transfer-from-workstation exists and is executable" \
              "File exists at $TRANSFER_FROM_SCRIPT" \
              "File not found or not executable"
fi

# Test 3: transfer-to-workstation should require arguments
OUTPUT=$("$TRANSFER_TO_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|argument\|required\|pane\|path"; then
    test_pass "transfer-to-workstation requires arguments"
else
    test_fail "transfer-to-workstation requires arguments" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 4: transfer-to-workstation should require pane argument
OUTPUT=$("$TRANSFER_TO_SCRIPT" "/tmp/test.txt" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|pane\|session\|required"; then
    test_pass "transfer-to-workstation requires pane argument"
else
    test_fail "transfer-to-workstation requires pane argument" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 5: transfer-from-workstation should require arguments
OUTPUT=$("$TRANSFER_FROM_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|argument\|required\|pane\|wormhole"; then
    test_pass "transfer-from-workstation requires arguments"
else
    test_fail "transfer-from-workstation requires arguments" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 6: transfer-from-workstation should require wormhole code
OUTPUT=$("$TRANSFER_FROM_SCRIPT" "tues:0.0" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|wormhole\|code\|required"; then
    test_pass "transfer-from-workstation requires wormhole code"
else
    test_fail "transfer-from-workstation requires wormhole code" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 7: transfer-to-workstation should detect invalid pane
OUTPUT=$("$TRANSFER_TO_SCRIPT" "nonexistent:0.0" "/tmp/test.txt" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "error\|does not exist\|not found\|invalid"; then
    test_pass "transfer-to-workstation detects invalid pane"
else
    test_fail "transfer-to-workstation detects invalid pane" \
              "Error message about invalid pane" \
              "$OUTPUT"
fi

# Test 8: transfer-from-workstation should detect invalid pane
OUTPUT=$("$TRANSFER_FROM_SCRIPT" "nonexistent:0.0" "1-test-code" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "error\|does not exist\|not found\|invalid"; then
    test_pass "transfer-from-workstation detects invalid pane"
else
    test_fail "transfer-from-workstation detects invalid pane" \
              "Error message about invalid pane" \
              "$OUTPUT"
fi

# Test 9: transfer-to-workstation should detect non-existent file
OUTPUT=$("$TRANSFER_TO_SCRIPT" "tues:0.0" "/nonexistent/path/test.txt" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "error\|does not exist\|not found"; then
    test_pass "transfer-to-workstation detects non-existent file"
else
    test_fail "transfer-to-workstation detects non-existent file" \
              "Error message about missing file" \
              "$OUTPUT"
fi

# Test 10: transfer-to-workstation should validate wormhole is installed
command -v wormhole >/dev/null 2>&1 || {
    test_fail "wormhole command-line tool" \
              "wormhole to be installed" \
              "wormhole not found in PATH"
}

# Test 11: transfer-to-workstation should accept valid pane
TEST_FILE="$TEST_DIR/test-content.txt"
echo "Test content for wormhole transfer" > "$TEST_FILE"
OUTPUT=$("$TRANSFER_TO_SCRIPT" "tues:0.0" "$TEST_FILE" 2>&1) || true
if echo "$OUTPUT" | grep -q -E "\"(wormhole_code|status|size|checksum)\""; then
    test_pass "transfer-to-workstation returns JSON with expected fields"
else
    test_fail "transfer-to-workstation returns JSON with expected fields" \
              'JSON with wormhole_code, status, size, checksum fields' \
              "$OUTPUT"
fi

# Test 12: transfer-to-workstation output should be valid JSON
OUTPUT=$("$TRANSFER_TO_SCRIPT" "tues:0.0" "$TEST_FILE" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "transfer-to-workstation returns valid JSON"
else
    test_fail "transfer-to-workstation returns valid JSON" \
              "Valid JSON output" \
              "$OUTPUT"
fi

# Test 13: transfer-to-workstation error response should have status field
OUTPUT=$("$TRANSFER_TO_SCRIPT" "tues:0.0" "$TEST_FILE" 2>&1) || true
if echo "$OUTPUT" | jq -e '.status' >/dev/null 2>&1; then
    test_pass "transfer-to-workstation error response includes status field"
else
    test_fail "transfer-to-workstation error response includes status field" \
              "JSON with status field" \
              "$OUTPUT"
fi

# Test 14: transfer-to-workstation error response should have error field
OUTPUT=$("$TRANSFER_TO_SCRIPT" "tues:0.0" "$TEST_FILE" 2>&1) || true
if echo "$OUTPUT" | jq -e '.error' >/dev/null 2>&1; then
    test_pass "transfer-to-workstation error response includes error field"
else
    test_fail "transfer-to-workstation error response includes error field" \
              "JSON with error field" \
              "$OUTPUT"
fi

# Test 15: transfer-to-workstation should handle pane without file gracefully
# This tests that the error message is clear and helpful
OUTPUT=$("$TRANSFER_TO_SCRIPT" "tues:0.0" "/tmp/nonexistent-file-$$" 2>&1) || true
if echo "$OUTPUT" | jq -e '.error' >/dev/null 2>&1; then
    ERROR_MSG=$(echo "$OUTPUT" | jq -r '.error')
    if echo "$ERROR_MSG" | grep -q -i "not found\|file"; then
        test_pass "transfer-to-workstation provides helpful error for missing file"
    else
        test_fail "transfer-to-workstation provides helpful error for missing file" \
                  "Error mentioning 'not found' or 'file'" \
                  "$ERROR_MSG"
    fi
else
    test_fail "transfer-to-workstation provides helpful error for missing file" \
              "JSON with error field" \
              "$OUTPUT"
fi

# Test 16: transfer-from-workstation error response should have proper structure
OUTPUT=$("$TRANSFER_FROM_SCRIPT" "tues:0.0" "1-invalid-code" 2>&1) || true
if echo "$OUTPUT" | jq -e '.status' >/dev/null 2>&1; then
    test_pass "transfer-from-workstation error response includes status field"
else
    test_fail "transfer-from-workstation error response includes status field" \
              "JSON with status field" \
              "$OUTPUT"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
