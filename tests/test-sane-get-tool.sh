#!/usr/bin/env bash
# Test: sane-get-tool should return platform-specific tool paths

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The script we're testing
GET_TOOL_SCRIPT="$PROJECT_DIR/sane-get-tool"

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

echo "Testing sane-get-tool..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$GET_TOOL_SCRIPT" ]]; then
    test_pass "sane-get-tool exists and is executable"
else
    test_fail "sane-get-tool exists and is executable" \
              "File exists at $GET_TOOL_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: Tool lookup should return valid JSON
echo "Test 2: Basic tool lookup..."
OUTPUT=$("$GET_TOOL_SCRIPT" "grep" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Tool lookup returns valid JSON"
else
    test_fail "Tool lookup returns valid JSON" "Valid JSON" "$OUTPUT"
fi

# Test 3: JSON should have 'tool' field
echo "Test 3: Checking for tool field..."
OUTPUT=$("$GET_TOOL_SCRIPT" "grep" 2>&1) || true
if echo "$OUTPUT" | jq -e '.tool' > /dev/null 2>&1; then
    test_pass "Output contains 'tool' field"
    TOOL=$(echo "$OUTPUT" | jq -r '.tool') || true
    if [[ "$TOOL" == "grep" ]]; then
        test_pass "Tool field contains requested tool name"
    else
        test_fail "Tool field contains requested tool name" "grep" "$TOOL"
    fi
else
    test_fail "Output contains 'tool' field" "tool field present" "field missing"
fi

# Test 4: JSON should have 'path' field
echo "Test 4: Checking for path field..."
OUTPUT=$("$GET_TOOL_SCRIPT" "grep" 2>&1) || true
if echo "$OUTPUT" | jq -e '.path' > /dev/null 2>&1; then
    test_pass "Output contains 'path' field"
else
    test_fail "Output contains 'path' field" "path field present" "field missing"
fi

# Test 5: JSON should have 'found' field
echo "Test 5: Checking for found field..."
OUTPUT=$("$GET_TOOL_SCRIPT" "grep" 2>&1) || true
if echo "$OUTPUT" | jq -e '.found' > /dev/null 2>&1; then
    test_pass "Output contains 'found' field"
else
    test_fail "Output contains 'found' field" "found field present" "field missing"
fi

# Test 6: Common tools should be found
echo "Test 6: Common tool should be found..."
OUTPUT=$("$GET_TOOL_SCRIPT" "grep" 2>&1) || true
FOUND=$(echo "$OUTPUT" | jq -r '.found') || true
if [[ "$FOUND" == "true" ]]; then
    test_pass "Common tool 'grep' is found"
    PATH_OUTPUT=$(echo "$OUTPUT" | jq -r '.path') || true
    if [[ -n "$PATH_OUTPUT" && "$PATH_OUTPUT" != "null" ]]; then
        test_pass "Path field is not empty for found tool"
    else
        test_fail "Path field is not empty for found tool" "non-empty path" "$PATH_OUTPUT"
    fi
else
    test_fail "Common tool 'grep' is found" "found=true" "$FOUND"
fi

# Test 7: Non-existent tool should have found=false
echo "Test 7: Non-existent tool should not be found..."
OUTPUT=$("$GET_TOOL_SCRIPT" "nonexistent-tool-xyz-12345" 2>&1) || true
FOUND=$(echo "$OUTPUT" | jq -r '.found') || true
if [[ "$FOUND" == "false" ]]; then
    test_pass "Non-existent tool has found=false"
else
    test_fail "Non-existent tool has found=false" "false" "$FOUND"
fi

# Test 8: Support for common Unix tools
echo "Test 8: Testing various common tools..."
for tool in "sed" "awk" "cut"; do
    OUTPUT=$("$GET_TOOL_SCRIPT" "$tool" 2>&1) || true
    if echo "$OUTPUT" | jq -e '.tool' > /dev/null 2>&1; then
        TOOL_NAME=$(echo "$OUTPUT" | jq -r '.tool') || true
        if [[ "$TOOL_NAME" == "$tool" ]]; then
            test_pass "Tool '$tool' returns correct name"
        else
            test_fail "Tool '$tool' returns correct name" "$tool" "$TOOL_NAME"
        fi
    else
        test_fail "Tool '$tool' returns valid JSON" "Valid JSON" "$OUTPUT"
    fi
done

# Test 9: Platform-specific tool mapping (macOS GNU tools)
echo "Test 9: Platform-specific tool mapping..."
CURRENT_OS=$(uname -s)
OUTPUT=$("$GET_TOOL_SCRIPT" "grep" 2>&1) || true
PATH_OUTPUT=$(echo "$OUTPUT" | jq -r '.path') || true

# Verify path is reasonable (not empty and contains /grep or just grep)
if [[ -n "$PATH_OUTPUT" && "$PATH_OUTPUT" != "null" ]]; then
    if [[ "$PATH_OUTPUT" == *"grep"* ]] || [[ "$PATH_OUTPUT" == "grep" ]]; then
        test_pass "Path output is reasonable"
    else
        test_fail "Path output is reasonable" "contains 'grep'" "$PATH_OUTPUT"
    fi
else
    test_fail "Path output is not empty" "non-empty path" "$PATH_OUTPUT"
fi

# Test 10: With explicit platform specification
echo "Test 10: Tool lookup with explicit platform..."
OUTPUT=$("$GET_TOOL_SCRIPT" "grep" "Darwin" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Tool lookup with platform returns valid JSON"
    TOOL=$(echo "$OUTPUT" | jq -r '.tool') || true
    if [[ "$TOOL" == "grep" ]]; then
        test_pass "Platform-specific lookup returns correct tool name"
    else
        test_fail "Platform-specific lookup returns correct tool name" "grep" "$TOOL"
    fi
else
    test_fail "Tool lookup with platform returns valid JSON" "Valid JSON" "$OUTPUT"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
