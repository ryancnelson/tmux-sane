#!/usr/bin/env bash
# Test: sane-validate-bash should validate bash syntax and return JSON

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The script we're testing
VALIDATE_SCRIPT="$PROJECT_DIR/sane-validate-bash"

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

echo "Testing bash validation..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$VALIDATE_SCRIPT" ]]; then
    test_pass "sane-validate-bash exists and is executable"
else
    test_fail "sane-validate-bash exists and is executable" \
              "File exists at $VALIDATE_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: Valid bash code should return valid JSON with valid: true
echo "Test 2: Testing valid script..."
VALID_SCRIPT="echo hello"
OUTPUT=$("$VALIDATE_SCRIPT" "$VALID_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Valid script returns valid JSON"
    
    # Check if valid field is true
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "true" ]]; then
        test_pass "Valid script has valid: true"
    else
        test_fail "Valid script has valid: true" "true" "$VALID"
    fi
else
    test_fail "Valid script returns valid JSON" "Valid JSON" "$OUTPUT"
fi

# Test 3: Invalid bash code should return valid JSON with valid: false
echo "Test 3: Testing invalid script..."
INVALID_SCRIPT="for i in {1..5"
OUTPUT=$("$VALIDATE_SCRIPT" "$INVALID_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Invalid script returns valid JSON"
    
    # Check if valid field is false
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "false" ]]; then
        test_pass "Invalid script has valid: false"
    else
        test_fail "Invalid script has valid: false" "false" "$VALID"
    fi
    
    # Check if error field exists
    if echo "$OUTPUT" | jq -e '.error' > /dev/null 2>&1; then
        test_pass "Invalid script has error field"
        ERROR=$(echo "$OUTPUT" | jq -r '.error') || true
        if [[ -n "$ERROR" && "$ERROR" != "null" ]]; then
            test_pass "Invalid script error message is not empty"
        else
            test_fail "Invalid script error message is not empty" "Non-empty error" "Empty or null"
        fi
    else
        test_fail "Invalid script has error field" "error field present" "field missing"
    fi
else
    test_fail "Invalid script returns valid JSON" "Valid JSON" "$OUTPUT"
fi

# Test 4: Valid multi-line script should pass validation
echo "Test 4: Testing multi-line script..."
MULTILINE_SCRIPT="#!/bin/bash
set -euo pipefail
for i in {1..5}; do
    echo \$i
done"
OUTPUT=$("$VALIDATE_SCRIPT" "$MULTILINE_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "true" ]]; then
        test_pass "Multi-line valid script passes validation"
    else
        test_fail "Multi-line valid script passes validation" "true" "$VALID"
    fi
else
    test_fail "Multi-line valid script returns JSON" "Valid JSON" "$OUTPUT"
fi

# Test 5: Script must have 'valid' field
echo "Test 5: Checking for valid field..."
VALID_SCRIPT="echo test"
OUTPUT=$("$VALIDATE_SCRIPT" "$VALID_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | jq -e '.valid' > /dev/null 2>&1; then
    test_pass "Output contains 'valid' field"
else
    test_fail "Output contains 'valid' field" "valid field present" "field missing"
fi

# Test 6: Handle scripts with special characters
echo "Test 6: Testing special characters..."
SPECIAL_SCRIPT='echo "test: $VAR | grep pattern"'
OUTPUT=$("$VALIDATE_SCRIPT" "$SPECIAL_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "true" ]]; then
        test_pass "Script with special characters validates correctly"
    else
        test_fail "Script with special characters validates correctly" "true" "$VALID"
    fi
else
    test_fail "Script with special characters returns JSON" "Valid JSON" "$OUTPUT"
fi

# Test 7: Empty string should be valid bash
echo "Test 7: Testing empty string..."
OUTPUT=$("$VALIDATE_SCRIPT" "" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "true" ]]; then
        test_pass "Empty string is valid bash"
    else
        test_fail "Empty string is valid bash" "true" "$VALID"
    fi
else
    test_fail "Empty string returns JSON" "Valid JSON" "$OUTPUT"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
