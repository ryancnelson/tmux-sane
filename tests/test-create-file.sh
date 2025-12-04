#!/usr/bin/env bash
# Test: sane-create-file should create files with content and return structured output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The script we're testing
CREATE_FILE_SCRIPT="$PROJECT_DIR/sane-create-file"
RUN_COMMAND_SCRIPT="$PROJECT_DIR/sane-run-command"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Unique suffix for test files to avoid conflicts
TEST_SUFFIX="$$-$RANDOM"

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

echo "Testing sane-create-file..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$CREATE_FILE_SCRIPT" ]]; then
    test_pass "sane-create-file exists and is executable"
else
    test_fail "sane-create-file exists and is executable" \
              "File exists at $CREATE_FILE_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: Script should require arguments
OUTPUT=$("$CREATE_FILE_SCRIPT" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|argument\|required"; then
    test_pass "Script requires arguments"
else
    test_fail "Script requires arguments" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 3: Script should require path argument
OUTPUT=$("$CREATE_FILE_SCRIPT" "session:0.0" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|path\|content\|required"; then
    test_pass "Script requires path argument"
else
    test_fail "Script requires path argument" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 4: Script should require content argument
OUTPUT=$("$CREATE_FILE_SCRIPT" "session:0.0" "/tmp/test.txt" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "usage\|content\|required"; then
    test_pass "Script requires content argument"
else
    test_fail "Script requires content argument" \
              "Usage message" \
              "$OUTPUT"
fi

# Test 5: Script should detect invalid session
OUTPUT=$("$CREATE_FILE_SCRIPT" "nonexistent:0.0" "/tmp/test.txt" "test content" 2>&1) || true
if echo "$OUTPUT" | grep -q -i "error\|does not exist\|not found"; then
    test_pass "Script detects invalid session"
else
    test_fail "Script detects invalid session" \
              "Error message" \
              "$OUTPUT"
fi

# Check if we have the tues session for live tests
if tmux has-session -t tues 2>/dev/null; then
    echo ""
    echo "Running tests with live tmux session 'tues'..."
    echo ""
    
    # Setup: Ensure the tues session has the proper shell with structured prompt
    tmux send-keys -t tues:0.0 "export PS1='test@ - \D{%b%d%Y}:\t seq:\$HISTCMD rslt:\$? bash \$ '" Enter
    sleep 0.5
    
    # Test 6: Script should create a simple file
    TEST_FILE="/tmp/sane-create-test-simple-$TEST_SUFFIX.txt"
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "$TEST_FILE" "Hello World" 2>&1) || true
    # Verify file was created in the pane using run-command
    VERIFY_RESULT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "cat '$TEST_FILE'" 2>&1) || true
    if echo "$VERIFY_RESULT" | jq -r '.output // empty' 2>/dev/null | grep -q "Hello World"; then
        test_pass "Script creates a simple file with content"
    else
        test_fail "Script creates a simple file with content" \
                  "File created with content 'Hello World'" \
                  "$(echo "$VERIFY_RESULT" | jq -r '.output // empty')"
    fi
    
    # Test 7: Script should return valid JSON on success
    TEST_FILE="/tmp/sane-create-test-json-$TEST_SUFFIX.txt"
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "$TEST_FILE" "test content" 2>&1) || true
    if echo "$OUTPUT" | jq . > /dev/null 2>&1; then
        test_pass "Script returns valid JSON on success"
    else
        test_fail "Script returns valid JSON on success" \
                  "Valid JSON object" \
                  "$OUTPUT"
    fi
    
    # Test 8: JSON output should contain 'status' field
    if echo "$OUTPUT" | jq -e '.status' > /dev/null 2>&1; then
        test_pass "JSON output contains 'status' field"
    else
        test_fail "JSON output contains 'status' field" \
                  "status field in JSON" \
                  "$OUTPUT"
    fi
    
    # Test 9: JSON output should contain 'checksum' field
    if echo "$OUTPUT" | jq -e '.checksum' > /dev/null 2>&1; then
        test_pass "JSON output contains 'checksum' field"
    else
        test_fail "JSON output contains 'checksum' field" \
                  "checksum field in JSON" \
                  "$OUTPUT"
    fi
    
    # Test 10: JSON output should contain 'path' field
    if echo "$OUTPUT" | jq -e '.path' > /dev/null 2>&1; then
        test_pass "JSON output contains 'path' field"
    else
        test_fail "JSON output contains 'path' field" \
                  "path field in JSON" \
                  "$OUTPUT"
    fi
    
    # Test 11: Script should handle special characters (test with escaped quotes)
    TEST_FILE="/tmp/sane-create-test-special-$TEST_SUFFIX.txt"
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "$TEST_FILE" 'Hello "World"' 2>&1) || true
    VERIFY_RESULT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "cat '$TEST_FILE'" 2>&1) || true
    if echo "$VERIFY_RESULT" | jq -r '.output // empty' 2>/dev/null | grep -q "Hello \"World\""; then
        test_pass "Script handles special characters in content"
    else
        test_fail "Script handles special characters in content" \
                  "File with escaped quotes" \
                  "$(echo "$VERIFY_RESULT" | jq -r '.output // empty')"
    fi
    
    # Test 12: JSON output status should be "created" or "success"
    TEST_FILE="/tmp/sane-create-test-status-$TEST_SUFFIX.txt"
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "$TEST_FILE" "test content" 2>&1) || true
    STATUS=$(echo "$OUTPUT" | jq -r '.status // empty' 2>/dev/null)
    if [[ "$STATUS" == "created" || "$STATUS" == "success" ]]; then
        test_pass "JSON output status field is 'created' or 'success'"
    else
        test_fail "JSON output status field is 'created' or 'success'" \
                  "status: created or success" \
                  "status: $STATUS"
    fi
    
    # Test 13: Script should handle multiline content
    TEST_FILE="/tmp/sane-create-test-multiline-$TEST_SUFFIX.txt"
    MULTILINE_CONTENT=$'line 1\nline 2\nline 3'
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "$TEST_FILE" "$MULTILINE_CONTENT" 2>&1) || true
    VERIFY_RESULT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "wc -l < '$TEST_FILE'" 2>&1) || true
    LINES=$(echo "$VERIFY_RESULT" | jq -r '.output // empty' 2>/dev/null | tr -d ' ')
    if [[ "$LINES" -ge 3 ]]; then
        test_pass "Script handles multiline content"
    else
        test_fail "Script handles multiline content" \
                  "File with 3+ lines" \
                  "File has $LINES lines"
    fi
    
    # Test 14: Script should handle JSON content
    TEST_FILE="/tmp/sane-create-test-json-content-$TEST_SUFFIX.txt"
    JSON_CONTENT='{"key": "value", "number": 42}'
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "$TEST_FILE" "$JSON_CONTENT" 2>&1) || true
    VERIFY_RESULT=$("$RUN_COMMAND_SCRIPT" "tues:0.0" "cat '$TEST_FILE'" 2>&1) || true
    if echo "$VERIFY_RESULT" | jq -r '.output // empty' 2>/dev/null | grep -q '"key"'; then
        test_pass "Script handles JSON content"
    else
        test_fail "Script handles JSON content" \
                  "File with JSON content" \
                  "$(echo "$VERIFY_RESULT" | jq -r '.output // empty')"
    fi
    
    # Test 15: Checksum should be non-empty
    TEST_FILE="/tmp/sane-create-test-checksum-$TEST_SUFFIX.txt"
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "$TEST_FILE" "test content" 2>&1) || true
    CHECKSUM=$(echo "$OUTPUT" | jq -r '.checksum // empty' 2>/dev/null)
    if [[ -n "$CHECKSUM" ]]; then
        test_pass "Script returns non-empty checksum"
    else
        test_fail "Script returns non-empty checksum" \
                  "Non-empty checksum field" \
                  "checksum: $CHECKSUM"
    fi
    
    # Test 16: Size bytes should match file size
    TEST_FILE="/tmp/sane-create-test-size-$TEST_SUFFIX.txt"
    TEST_CONTENT="test content"
    OUTPUT=$("$CREATE_FILE_SCRIPT" "tues:0.0" "$TEST_FILE" "$TEST_CONTENT" 2>&1) || true
    SIZE_BYTES=$(echo "$OUTPUT" | jq -r '.size_bytes // 0' 2>/dev/null)
    # The content should be "test content" which is 12 bytes, but echo adds a newline so it's 13
    EXPECTED_SIZE=$((${#TEST_CONTENT} + 1))  # +1 for newline from echo
    if [[ "$SIZE_BYTES" -eq "$EXPECTED_SIZE" ]]; then
        test_pass "Script returns correct size_bytes"
    else
        test_fail "Script returns correct size_bytes" \
                  "size_bytes: $EXPECTED_SIZE" \
                  "size_bytes: $SIZE_BYTES"
    fi
    
else
    echo "Skipping live tmux tests (session 'tues' not available)"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
