#!/usr/bin/env bash
# Test pane targeting support in sane-detect-platform

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DETECT_SCRIPT="$PROJECT_DIR/sane-detect-platform"
SESSION="tues"

TESTS_PASSED=0
TESTS_TOTAL=0

test_case() {
    local name="$1"
    local target="$2"
    local should_succeed="$3"
    
    ((TESTS_TOTAL++))
    
    OUTPUT=$("$DETECT_SCRIPT" "$target" 2>&1) || RESULT=$?
    RESULT=${RESULT:-0}
    
    if [[ "$should_succeed" == "true" ]]; then
        if [[ $RESULT -eq 0 ]] && echo "$OUTPUT" | jq -e '.os' > /dev/null 2>&1; then
            echo "✓ $name"
            ((TESTS_PASSED++))
        else
            echo "✗ $name (exit code: $RESULT, output: $OUTPUT)"
        fi
    else
        if [[ $RESULT -ne 0 ]]; then
            echo "✓ $name (correctly failed)"
            ((TESTS_PASSED++))
        else
            echo "✗ $name (should have failed but didn't)"
        fi
    fi
}

echo "Testing pane targeting support..."
echo ""

# Test cases
test_case "Session only (backward compatible)" "$SESSION" "true"
test_case "Session with WINDOW.PANE format" "${SESSION}:0.0" "true"
test_case "Session with WINDOW only" "${SESSION}:0" "true"
test_case "Invalid pane format" "${SESSION}:bad-format" "false"
test_case "Non-existent session" "nonexistent-session-xyz" "false"
test_case "Non-existent pane" "${SESSION}:99.99" "false"

echo ""
echo "Results: $TESTS_PASSED/$TESTS_TOTAL tests passed"

if [[ $TESTS_PASSED -eq $TESTS_TOTAL ]]; then
    exit 0
else
    exit 1
fi
