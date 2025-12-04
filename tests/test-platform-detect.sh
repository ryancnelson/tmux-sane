#!/usr/bin/env bash
# Test: Platform detection should return JSON with OS, arch, hostname, user

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the script we're testing (when it exists)
DETECT_SCRIPT="$PROJECT_DIR/lib/platform-detect.sh"

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

echo "Testing platform detection..."
echo ""

# Test 1: Script should exist and be executable
if [[ -x "$DETECT_SCRIPT" ]]; then
    test_pass "platform-detect.sh exists and is executable"
else
    test_fail "platform-detect.sh exists and is executable" \
              "File exists at $DETECT_SCRIPT" \
              "File not found or not executable"
fi

# Test 2: Should return valid JSON
if [[ -x "$DETECT_SCRIPT" ]]; then
    OUTPUT=$("$DETECT_SCRIPT")
    if echo "$OUTPUT" | jq empty 2>/dev/null; then
        test_pass "Returns valid JSON"
    else
        test_fail "Returns valid JSON" "Valid JSON output" "$OUTPUT"
    fi
    
    # Test 3: Should include 'os' field
    if echo "$OUTPUT" | jq -e '.os' > /dev/null 2>&1; then
        test_pass "JSON contains 'os' field"
    else
        test_fail "JSON contains 'os' field" "Field 'os' present" "Field missing"
    fi
    
    # Test 4: Should include 'arch' field
    if echo "$OUTPUT" | jq -e '.arch' > /dev/null 2>&1; then
        test_pass "JSON contains 'arch' field"
    else
        test_fail "JSON contains 'arch' field" "Field 'arch' present" "Field missing"
    fi
    
    # Test 5: Should include 'hostname' field
    if echo "$OUTPUT" | jq -e '.hostname' > /dev/null 2>&1; then
        test_pass "JSON contains 'hostname' field"
    else
        test_fail "JSON contains 'hostname' field" "Field 'hostname' present" "Field missing"
    fi
    
    # Test 6: Should include 'user' field
    if echo "$OUTPUT" | jq -e '.user' > /dev/null 2>&1; then
        test_pass "JSON contains 'user' field"
    else
        test_fail "JSON contains 'user' field" "Field 'user' present" "Field missing"
    fi
    
    # Test 7: OS should be Darwin, Linux, or FreeBSD
    OS=$(echo "$OUTPUT" | jq -r '.os')
    if [[ "$OS" == "Darwin" ]] || [[ "$OS" == "Linux" ]] || [[ "$OS" == "FreeBSD" ]]; then
        test_pass "OS is recognized (Darwin/Linux/FreeBSD): $OS"
    else
        test_fail "OS is recognized" "Darwin, Linux, or FreeBSD" "$OS"
    fi
    
    # Test 8: Hostname should match system hostname
    SYSTEM_HOSTNAME=$(hostname -s 2>/dev/null || hostname | cut -d. -f1)
    DETECTED_HOSTNAME=$(echo "$OUTPUT" | jq -r '.hostname')
    if [[ "$DETECTED_HOSTNAME" == "$SYSTEM_HOSTNAME" ]]; then
        test_pass "Hostname matches system: $DETECTED_HOSTNAME"
    else
        test_fail "Hostname matches system" "$SYSTEM_HOSTNAME" "$DETECTED_HOSTNAME"
    fi
    
    # Test 9: User should match current user
    DETECTED_USER=$(echo "$OUTPUT" | jq -r '.user')
    if [[ "$DETECTED_USER" == "$USER" ]]; then
        test_pass "User matches current user: $DETECTED_USER"
    else
        test_fail "User matches current user" "$USER" "$DETECTED_USER"
    fi
fi

echo ""
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
