#!/usr/bin/env bash
# Test: Performance profiling for sane-run-command and sane-create-file
# Measures execution time, memory usage, and identifies bottlenecks
# Scope: Profile with various output/file sizes to identify any >1s bottlenecks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RUN_COMMAND_SCRIPT="$PROJECT_DIR/sane-run-command"
CREATE_FILE_SCRIPT="$PROJECT_DIR/sane-create-file"

# Test counter and results
TESTS_RUN=0
TESTS_PASSED=0
PERFORMANCE_RESULTS=()

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

log_perf() {
    # Log performance metric: label, value, unit
    local label="$1"
    local value="$2"
    local unit="${3:-ms}"
    PERFORMANCE_RESULTS+=("$label: ${value}${unit}")
    echo "  → $label: ${value}${unit}"
}

echo "Performance Profiling: sane-* commands"
echo "======================================="
echo ""

# Check scripts exist
if [[ ! -x "$RUN_COMMAND_SCRIPT" ]]; then
    echo "✗ sane-run-command not found or not executable"
    exit 1
fi

if [[ ! -x "$CREATE_FILE_SCRIPT" ]]; then
    echo "✗ sane-create-file not found or not executable"
    exit 1
fi

test_pass "sane-run-command exists and is executable"
test_pass "sane-create-file exists and is executable"

# Check if we have the tues session for live tests
if ! tmux has-session -t tues 2>/dev/null; then
    echo ""
    echo "⚠ Test session 'tues' not found. Skipping live performance tests."
    echo "To run performance tests, create a tmux session: tmux new-session -d -s tues"
    echo ""
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 0
fi

echo ""
echo "Running performance tests with live tmux session 'tues'..."
echo ""

# ===== SANE-RUN-COMMAND PERFORMANCE TESTS =====

echo "1. sane-run-command Performance Tests"
echo "=====================================
"

# Test 1.1: Small output (< 100 bytes)
echo -n "Test 1.1: Small output (<100 bytes)... "
START=$(date +%s%N)
RESULT=$("$RUN_COMMAND_SCRIPT" tues "echo 'Hello World'" 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.exit_code == 0' > /dev/null 2>&1; then
    test_pass "Small output execution"
    log_perf "Small output (<100B) total time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms, expected <1000ms"
    fi
else
    test_fail "Small output execution" "exit_code 0" "$(echo "$RESULT" | jq -r '.exit_code')"
fi
echo ""

# Test 1.2: Medium output (1-10KB)
echo -n "Test 1.2: Medium output (1-10KB)... "
START=$(date +%s%N)
# Generate 5KB of output using seq and formatting
RESULT=$("$RUN_COMMAND_SCRIPT" tues "seq 1 100 | sed 's/^/Line /' | head -100" 60 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.exit_code == 0' > /dev/null 2>&1; then
    OUTPUT_SIZE=$(echo "$RESULT" | jq -r '.output' | wc -c)
    test_pass "Medium output execution"
    log_perf "Medium output (~${OUTPUT_SIZE}B) total time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms, expected <1000ms"
    fi
else
    test_fail "Medium output execution" "exit_code 0" "$(echo "$RESULT" | jq -r '.exit_code')"
fi
echo ""

# Test 1.3: Large output (10-100KB)
echo -n "Test 1.3: Large output (10-100KB)... "
START=$(date +%s%N)
# Generate ~50KB of output using cat and formatting
RESULT=$("$RUN_COMMAND_SCRIPT" tues "seq 1 500 | sed 's/^/This is line number: /' | head -500" 60 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.exit_code == 0' > /dev/null 2>&1; then
    OUTPUT_SIZE=$(echo "$RESULT" | jq -r '.output' | wc -c)
    test_pass "Large output execution"
    log_perf "Large output (~${OUTPUT_SIZE}B) total time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms (exceeds 1s threshold)"
    fi
else
    test_fail "Large output execution" "exit_code 0" "$(echo "$RESULT" | jq -r '.exit_code')"
fi
echo ""

# Test 1.4: Very large output (100KB+)
echo -n "Test 1.4: Very large output (100KB+)... "
START=$(date +%s%N)
# Generate ~100KB of output using seq
RESULT=$("$RUN_COMMAND_SCRIPT" tues "seq 1 1000 | sed 's/^/This is a longer line for performance testing. Line number: /' | head -1000" 60 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.exit_code == 0' > /dev/null 2>&1; then
    OUTPUT_SIZE=$(echo "$RESULT" | jq -r '.output' | wc -c)
    test_pass "Very large output execution"
    log_perf "Very large output (~${OUTPUT_SIZE}B) total time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms (exceeds 1s threshold)"
    fi
else
    test_fail "Very large output execution" "exit_code 0" "$(echo "$RESULT" | jq -r '.exit_code')"
fi
echo ""

# Test 1.5: Complex command with pipes
echo -n "Test 1.5: Complex command with pipes... "
START=$(date +%s%N)
# Generate output with multiple pipes
RESULT=$("$RUN_COMMAND_SCRIPT" tues "seq 1 100 | sed 's/^/Line: /' | grep -v 50 | wc -l" 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.exit_code == 0' > /dev/null 2>&1; then
    test_pass "Complex piped command"
    log_perf "Complex piped command time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms, expected <1000ms"
    fi
else
    test_fail "Complex piped command" "exit_code 0" "$(echo "$RESULT" | jq -r '.exit_code')"
fi
echo ""

# ===== SANE-CREATE-FILE PERFORMANCE TESTS =====

echo ""
echo "2. sane-create-file Performance Tests"
echo "====================================="
echo ""

TEMP_FILE="/tmp/perf-test-$RANDOM.txt"

# Test 2.1: Small file creation (< 1KB)
echo -n "Test 2.1: Small file creation (<1KB)... "
START=$(date +%s%N)
RESULT=$("$CREATE_FILE_SCRIPT" tues "$TEMP_FILE" "Hello World Test Content" 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.status == "created"' > /dev/null 2>&1; then
    FILE_SIZE=$(echo "$RESULT" | jq -r '.size_bytes')
    test_pass "Small file creation"
    log_perf "Small file creation (${FILE_SIZE}B) total time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms, expected <1000ms"
    fi
else
    test_fail "Small file creation" "status created" "$(echo "$RESULT" | jq -r '.status')"
fi
echo ""

# Test 2.2: Medium file creation (10-100KB)
echo -n "Test 2.2: Medium file creation (10-100KB)... "
# Generate ~50KB of content using printf and repeat
MEDIUM_CONTENT=$(printf '%s\n' "$(printf 'This is a test line for medium file performance testing. Line %03d' $(seq 1 200) | tr '\n' ' ')" | head -c 50000)
START=$(date +%s%N)
RESULT=$("$CREATE_FILE_SCRIPT" tues "$TEMP_FILE" "$MEDIUM_CONTENT" 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.status == "created"' > /dev/null 2>&1; then
    FILE_SIZE=$(echo "$RESULT" | jq -r '.size_bytes')
    test_pass "Medium file creation"
    log_perf "Medium file creation (~${FILE_SIZE}B) total time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms (exceeds 1s threshold)"
    fi
else
    test_fail "Medium file creation" "status created" "$(echo "$RESULT" | jq -r '.status')"
fi
echo ""

# Test 2.3: Large file creation (50KB)
echo -n "Test 2.3: Large file creation (~50KB)... "
# Generate ~50KB of JSON content using dd
LARGE_CONTENT=$(printf '{"line_%d":"test content with numbers %d and special chars"}\n' $(seq 1 100) $(seq 1 100) | head -c 50000)
START=$(date +%s%N)
RESULT=$("$CREATE_FILE_SCRIPT" tues "$TEMP_FILE" "$LARGE_CONTENT" false 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.status == "created"' > /dev/null 2>&1; then
    FILE_SIZE=$(echo "$RESULT" | jq -r '.size_bytes')
    test_pass "Large file creation"
    log_perf "Large file creation (~${FILE_SIZE}B) total time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms (exceeds 1s threshold)"
    fi
else
    test_fail "Large file creation" "status created" "$(echo "$RESULT" | jq -r '.status')"
fi
echo ""

# Test 2.4: File with special characters (base64 encoding path)
echo -n "Test 2.4: File with special characters... "
SPECIAL_CONTENT='Line 1: Hello\nLine 2: With "quotes"\nLine 3: With $vars\nLine 4: With `backticks`'
START=$(date +%s%N)
RESULT=$("$CREATE_FILE_SCRIPT" tues "$TEMP_FILE" "$SPECIAL_CONTENT" false 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.status == "created"' > /dev/null 2>&1; then
    FILE_SIZE=$(echo "$RESULT" | jq -r '.size_bytes')
    test_pass "File with special characters"
    log_perf "Special char file creation (${FILE_SIZE}B) total time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms, expected <1000ms"
    fi
else
    test_fail "File with special characters" "status created" "$(echo "$RESULT" | jq -r '.status')"
fi
echo ""

# Test 2.5: File creation with backup (file already exists)
echo -n "Test 2.5: File creation with existing backup... "
# First create the file
"$CREATE_FILE_SCRIPT" tues "$TEMP_FILE" "Original content" false > /dev/null 2>&1

# Now create it again with backup=true (should backup first)
START=$(date +%s%N)
RESULT=$("$CREATE_FILE_SCRIPT" tues "$TEMP_FILE" "New content" true 2>&1)
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))

if echo "$RESULT" | jq -e '.status == "created"' > /dev/null 2>&1; then
    test_pass "File creation with existing backup"
    log_perf "File creation with backup time" "$DURATION_MS"
    if [[ $DURATION_MS -gt 1000 ]]; then
        echo "  ⚠ Warning: Took ${DURATION_MS}ms, expected <1000ms"
    fi
else
    test_fail "File creation with existing backup" "status created" "$(echo "$RESULT" | jq -r '.status')"
fi
echo ""

# Cleanup
"$RUN_COMMAND_SCRIPT" tues "rm -f $TEMP_FILE /var/tmp/backup-*-perf-test-* 2>/dev/null" > /dev/null 2>&1 || true

# ===== SUMMARY =====

echo ""
echo "======================================="
echo "Performance Summary"
echo "======================================="
for result in "${PERFORMANCE_RESULTS[@]}"; do
    echo "$result"
done

echo ""
echo "Analysis:"
echo "---------"

# Count bottlenecks (>1000ms)
BOTTLENECK_COUNT=0
for result in "${PERFORMANCE_RESULTS[@]}"; do
    if echo "$result" | grep -oE '[0-9]{4,}ms' | grep -oE '[0-9]+' | grep -qE '^[1-9][0-9]{3,}$'; then
        ((BOTTLENECK_COUNT=BOTTLENECK_COUNT+1))
    fi
done

if [[ $BOTTLENECK_COUNT -gt 0 ]]; then
    echo "⚠ Found $BOTTLENECK_COUNT operation(s) exceeding 1s threshold"
    echo "  Recommendation: Investigate optimizations for slow operations"
else
    echo "✓ All profiled operations complete within acceptable time (<1s)"
    echo "  Production readiness: Good"
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
