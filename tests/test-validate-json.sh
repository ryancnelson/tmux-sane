#!/usr/bin/env bash
# Test: sane-validate-json should validate JSON and return JSON

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The script we're testing
VALIDATE_SCRIPT="$PROJECT_DIR/sane-validate-json"

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

echo "Testing JSON validation..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$VALIDATE_SCRIPT" ]]; then
    test_pass "sane-validate-json exists and is executable"
else
    test_fail "sane-validate-json exists and is executable" \
              "File exists at $VALIDATE_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: Valid JSON should return valid JSON with valid: true
echo "Test 2: Testing valid JSON..."
VALID_JSON='{"key": "value"}'
OUTPUT=$("$VALIDATE_SCRIPT" "$VALID_JSON" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Valid JSON returns valid JSON"
    
    # Check if valid field is true
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "true" ]]; then
        test_pass "Valid JSON has valid: true"
    else
        test_fail "Valid JSON has valid: true" "true" "$VALID"
    fi
else
    test_fail "Valid JSON returns valid JSON" "Valid JSON" "$OUTPUT"
fi

# Test 3: Invalid JSON should return valid JSON with valid: false
echo "Test 3: Testing invalid JSON..."
INVALID_JSON='{"key": "value"'
OUTPUT=$("$VALIDATE_SCRIPT" "$INVALID_JSON" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    test_pass "Invalid JSON returns valid JSON"
    
    # Check if valid field is false
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "false" ]]; then
        test_pass "Invalid JSON has valid: false"
    else
        test_fail "Invalid JSON has valid: false" "false" "$VALID"
    fi
    
    # Check if error field exists
    if echo "$OUTPUT" | jq -e '.error' > /dev/null 2>&1; then
        test_pass "Invalid JSON has error field"
        ERROR=$(echo "$OUTPUT" | jq -r '.error') || true
        if [[ -n "$ERROR" && "$ERROR" != "null" ]]; then
            test_pass "Invalid JSON error message is not empty"
        else
            test_fail "Invalid JSON error message is not empty" "Non-empty error" "Empty or null"
        fi
    else
        test_fail "Invalid JSON has error field" "error field present" "field missing"
    fi
else
    test_fail "Invalid JSON returns valid JSON" "Valid JSON" "$OUTPUT"
fi

# Test 4: Valid multi-line JSON should pass validation
echo "Test 4: Testing multi-line JSON..."
MULTILINE_JSON='{
    "name": "test",
    "values": [1, 2, 3],
    "nested": {
        "key": "value"
    }
}'
OUTPUT=$("$VALIDATE_SCRIPT" "$MULTILINE_JSON" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "true" ]]; then
        test_pass "Multi-line valid JSON passes validation"
    else
        test_fail "Multi-line valid JSON passes validation" "true" "$VALID"
    fi
else
    test_fail "Multi-line valid JSON returns JSON" "Valid JSON" "$OUTPUT"
fi

# Test 5: Script must have 'valid' field
echo "Test 5: Checking for valid field..."
VALID_JSON='{"test": true}'
OUTPUT=$("$VALIDATE_SCRIPT" "$VALID_JSON" 2>&1) || true
if echo "$OUTPUT" | jq -e '.valid' > /dev/null 2>&1; then
    test_pass "Output contains 'valid' field"
else
    test_fail "Output contains 'valid' field" "valid field present" "field missing"
fi

# Test 6: Handle JSON with special characters
echo "Test 6: Testing special characters..."
SPECIAL_JSON='{"message": "test with special chars: \n \t \r", "emoji": "😀"}'
OUTPUT=$("$VALIDATE_SCRIPT" "$SPECIAL_JSON" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "true" ]]; then
        test_pass "JSON with special characters validates correctly"
    else
        test_fail "JSON with special characters validates correctly" "true" "$VALID"
    fi
else
    test_fail "JSON with special characters returns JSON" "Valid JSON" "$OUTPUT"
fi

# Test 7: Empty string should be invalid JSON
echo "Test 7: Testing empty string..."
OUTPUT=$("$VALIDATE_SCRIPT" "" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "false" ]]; then
        test_pass "Empty string is invalid JSON"
    else
        test_fail "Empty string is invalid JSON" "false" "$VALID"
    fi
else
    test_fail "Empty string returns JSON" "Valid JSON" "$OUTPUT"
fi

# Test 8: Empty object should be valid JSON
echo "Test 8: Testing empty object..."
OUTPUT=$("$VALIDATE_SCRIPT" "{}" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "true" ]]; then
        test_pass "Empty object is valid JSON"
    else
        test_fail "Empty object is valid JSON" "true" "$VALID"
    fi
else
    test_fail "Empty object returns JSON" "Valid JSON" "$OUTPUT"
fi

# Test 9: Empty array should be valid JSON
echo "Test 9: Testing empty array..."
OUTPUT=$("$VALIDATE_SCRIPT" "[]" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "true" ]]; then
        test_pass "Empty array is valid JSON"
    else
        test_fail "Empty array is valid JSON" "true" "$VALID"
    fi
else
    test_fail "Empty array returns JSON" "Valid JSON" "$OUTPUT"
fi

# Test 10: Plain text should be invalid JSON
echo "Test 10: Testing plain text..."
OUTPUT=$("$VALIDATE_SCRIPT" "just plain text" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "false" ]]; then
        test_pass "Plain text is invalid JSON"
    else
        test_fail "Plain text is invalid JSON" "false" "$VALID"
    fi
else
    test_fail "Plain text returns JSON" "Valid JSON" "$OUTPUT"
fi

# Test 11: Trailing comma should be invalid JSON
echo "Test 11: Testing trailing comma..."
TRAILING_COMMA='{"key": "value",}'
OUTPUT=$("$VALIDATE_SCRIPT" "$TRAILING_COMMA" 2>&1) || true
if echo "$OUTPUT" | jq empty 2>/dev/null; then
    VALID=$(echo "$OUTPUT" | jq -r '.valid') || true
    if [[ "$VALID" == "false" ]]; then
        test_pass "Trailing comma is invalid JSON"
    else
        test_fail "Trailing comma is invalid JSON" "false" "$VALID"
    fi
else
    test_fail "Trailing comma returns JSON" "Valid JSON" "$OUTPUT"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
