#!/usr/bin/env bash
# Test: Detect platform inside a tmux session by sending commands

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# The script we're testing
DETECT_SCRIPT="$PROJECT_DIR/sane-detect-platform"

# Test session
SESSION="tues"

# Test counter
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

echo "Testing platform detection in tmux session '$SESSION'..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$DETECT_SCRIPT" ]]; then
    test_pass "sane-detect-platform exists and is executable"
else
    test_fail "sane-detect-platform exists and is executable" \
              "File exists at $DETECT_SCRIPT" \
              "File not found or not executable"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi

# Test 2: Should work with existing tmux session
if tmux has-session -t "$SESSION" 2>/dev/null; then
    OUTPUT=$("$DETECT_SCRIPT" "$SESSION" 2>&1)
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
    
    # Test 4: Should include 'os' field
    if echo "$OUTPUT" | jq -e '.os' > /dev/null 2>&1; then
        test_pass "JSON contains 'os' field"
        OS=$(echo "$OUTPUT" | jq -r '.os')
        echo "  → Detected OS: $OS"
    else
        test_fail "JSON contains 'os' field" "Field 'os' present" "Field missing"
    fi
    
    # Test 5: Should include 'arch' field
    if echo "$OUTPUT" | jq -e '.arch' > /dev/null 2>&1; then
        test_pass "JSON contains 'arch' field"
        ARCH=$(echo "$OUTPUT" | jq -r '.arch')
        echo "  → Detected arch: $ARCH"
    else
        test_fail "JSON contains 'arch' field" "Field 'arch' present" "Field missing"
    fi
    
    # Test 6: Should include 'hostname' field
    if echo "$OUTPUT" | jq -e '.hostname' > /dev/null 2>&1; then
        test_pass "JSON contains 'hostname' field"
        HOSTNAME=$(echo "$OUTPUT" | jq -r '.hostname')
        echo "  → Detected hostname: $HOSTNAME"
    else
        test_fail "JSON contains 'hostname' field" "Field 'hostname' present" "Field missing"
    fi
    
    # Test 7: Should include 'user' field
    if echo "$OUTPUT" | jq -e '.user' > /dev/null 2>&1; then
        test_pass "JSON contains 'user' field"
        USER_NAME=$(echo "$OUTPUT" | jq -r '.user')
        echo "  → Detected user: $USER_NAME"
    else
        test_fail "JSON contains 'user' field" "Field 'user' present" "Field missing"
    fi
    
else
    test_fail "Session exists" "Session '$SESSION' exists" "Session not found"
fi

# Test 8: Should fail gracefully with non-existent session
OUTPUT=$("$DETECT_SCRIPT" "nonexistent-session-xyz" 2>&1 || true)
if echo "$OUTPUT" | grep -q "does not exist"; then
    test_pass "Fails gracefully with non-existent session"
else
    test_fail "Fails gracefully with non-existent session" \
              "Error message about session not existing" \
              "$OUTPUT"
fi

# Test 9: Should work with pane targeting format (WINDOW.PANE)
if tmux has-session -t "$SESSION" 2>/dev/null; then
    # Get first pane in first window
    PANE_TARGET="${SESSION}:0.0"
    
    if tmux list-panes -t "$PANE_TARGET" > /dev/null 2>&1; then
        OUTPUT=$("$DETECT_SCRIPT" "$PANE_TARGET" 2>&1)
        EXIT_CODE=$?
        
        if [[ $EXIT_CODE -eq 0 ]]; then
            test_pass "Runs successfully with pane target format: $PANE_TARGET"
        else
            test_fail "Runs successfully with pane target format" \
                      "Exit code 0" \
                      "Exit code $EXIT_CODE: $OUTPUT"
        fi
        
        # Verify JSON output for pane target
        if echo "$OUTPUT" | jq empty 2>/dev/null; then
            test_pass "Pane target returns valid JSON"
        else
            test_fail "Pane target returns valid JSON" "Valid JSON output" "$OUTPUT"
        fi
    fi
fi

# Test 10: Should fail gracefully with invalid pane format
OUTPUT=$("$DETECT_SCRIPT" "${SESSION}:invalid-pane-format" 2>&1 || true)
if echo "$OUTPUT" | grep -q "Invalid pane specification"; then
    test_pass "Fails gracefully with invalid pane format"
else
    test_fail "Fails gracefully with invalid pane format" \
              "Error message about invalid pane format" \
              "$OUTPUT"
fi

# Test 11: Should fail gracefully with non-existent pane
OUTPUT=$("$DETECT_SCRIPT" "${SESSION}:99.99" 2>&1 || true)
if echo "$OUTPUT" | grep -q "does not exist\|invalid"; then
    test_pass "Fails gracefully with non-existent pane"
else
    test_fail "Fails gracefully with non-existent pane" \
              "Error message about pane not existing" \
              "$OUTPUT"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
