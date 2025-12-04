#!/usr/bin/env bash
# tests/test-ask-helpers.sh - Test suite for ask-* helper functions
#
# Tests the ask-helpers library which provides AI-powered validation
# for bash syntax, jq queries, and tool flag detection.

set -euo pipefail

# Source the library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/ask-helpers.sh"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_code="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo -n "Test $TESTS_TOTAL: $test_name... "
    
    if eval "$test_code" >/dev/null 2>&1; then
        echo "✓"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 1: check_ask_helpers_available exists
run_test "check_ask_helpers_available function exists" \
    "type check_ask_helpers_available >/dev/null"

# Test 2: ask_nova_lite_yn exists
run_test "ask_nova_lite_yn function exists" \
    "type ask_nova_lite_yn >/dev/null"

# Test 3: ask_haiku_yn exists
run_test "ask_haiku_yn function exists" \
    "type ask_haiku_yn >/dev/null"

# Test 4: validate_bash_with_ai exists
run_test "validate_bash_with_ai function exists" \
    "type validate_bash_with_ai >/dev/null"

# Test 5: validate_jq_with_ai exists
run_test "validate_jq_with_ai function exists" \
    "type validate_jq_with_ai >/dev/null"

# Test 6: tool_supports_flag exists
run_test "tool_supports_flag function exists" \
    "type tool_supports_flag >/dev/null"

# Test 7: validate_bash_with_ai with valid bash (local check)
run_test "validate_bash_with_ai accepts valid bash code" \
    "result=\$(validate_bash_with_ai 'echo hello'); echo \$result | grep -q '\"valid\":true'"

# Test 8: validate_bash_with_ai with invalid bash (local check)
run_test "validate_bash_with_ai rejects invalid bash code" \
    "result=\$(validate_bash_with_ai 'if [ 1 = 1'); echo \$result | grep -q '\"valid\":false'"

# Test 9: validate_bash_with_ai returns JSON with method field
run_test "validate_bash_with_ai returns method field in JSON" \
    "result=\$(validate_bash_with_ai 'echo test'); echo \$result | grep -q '\"method\"'"

# Test 10: validate_bash_with_ai handles empty input
run_test "validate_bash_with_ai handles empty input gracefully" \
    "result=\$(validate_bash_with_ai ''); echo \$result | grep -q '\"valid\":false'"

# Test 11: validate_jq_with_ai with valid jq query (local check)
run_test "validate_jq_with_ai accepts valid jq query" \
    "result=\$(validate_jq_with_ai '.'); echo \$result | grep -q '\"valid\":true'"

# Test 12: validate_jq_with_ai with invalid jq query (local check)
run_test "validate_jq_with_ai rejects invalid jq query" \
    "result=\$(validate_jq_with_ai 'invalid!!!jq'); echo \$result | grep -q '\"valid\":false'"

# Test 13: validate_jq_with_ai returns JSON with method field
run_test "validate_jq_with_ai returns method field in JSON" \
    "result=\$(validate_jq_with_ai '.[0]'); echo \$result | grep -q '\"method\"'"

# Test 14: validate_jq_with_ai handles empty input
run_test "validate_jq_with_ai handles empty input gracefully" \
    "result=\$(validate_jq_with_ai ''); echo \$result | grep -q '\"valid\":false'"

# Test 15: validate_bash_with_ai with complex multi-line bash
run_test "validate_bash_with_ai accepts complex multi-line bash" \
    "result=\$(validate_bash_with_ai 'for i in {1..5}; do echo \$i; done'); echo \$result | grep -q '\"valid\":true'"

# Test 16: validate_bash_with_ai with bash containing special characters
run_test "validate_bash_with_ai handles bash with special characters" \
    "result=\$(validate_bash_with_ai 'echo \"hello with \\\\\"quotes\\\\\"\"'); echo \$result | grep -q '\"valid\":true'"

# Test 17: Functions are exported
run_test "ask_nova_lite_yn is exported" \
    "bash -c 'source lib/ask-helpers.sh && type ask_nova_lite_yn' >/dev/null"

# Test 18: Functions are exported
run_test "validate_bash_with_ai is exported" \
    "bash -c 'source lib/ask-helpers.sh && type validate_bash_with_ai' >/dev/null"

# Test 19: validate_bash_with_ai with simple echo command
run_test "validate_bash_with_ai with simple echo command" \
    "result=\$(validate_bash_with_ai 'echo hello world'); echo \$result | grep -q '\"valid\":true'"

# Test 20: validate_jq_with_ai with complex query
run_test "validate_jq_with_ai with complex query" \
    "result=\$(validate_jq_with_ai 'map(select(.type == \"active\")) | sort_by(.name)'); echo \$result | grep -q '\"valid\":true'"

echo ""
echo "==========================================="
echo "Results: $TESTS_PASSED/$TESTS_TOTAL tests passed"
echo "==========================================="
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
