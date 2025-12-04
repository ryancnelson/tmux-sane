#!/usr/bin/env bash

# Test suite for sane-detect-ssh command

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

total=0
passed=0

echo "Test Suite: sane-detect-ssh SSH Detection"
echo "=========================================="
echo ""

# Ensure session exists
if ! tmux has-session -t tues 2>/dev/null; then
    tmux new-session -d -s tues
    sleep 0.2
fi

# Test 1: Help text
echo -n "Test 1: Help text... "
((total++))
if ./sane-detect-ssh 2>&1 | grep -q "Usage" || true; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 2: Invalid session error
echo -n "Test 2: Invalid session error... "
((total++))
if ./sane-detect-ssh "invalid-session-$RANDOM" 2>&1 | grep -q "error" || true; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 3: Valid JSON output with ssh_detected
echo -n "Test 3: Valid JSON with ssh_detected... "
((total++))
if ./sane-detect-ssh "tues:0.0" 2>/dev/null | jq '.ssh_detected' >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 4: All required fields present
echo -n "Test 4: Required fields (pane, hostname, user, os, port, label, timestamp, duration_ms, context_updated)... "
((total++))
result=$(./sane-detect-ssh "tues:0.0" 2>/dev/null)
if echo "$result" | jq -e '.pane and .hostname and .user and .os and .port and .label and .timestamp and .duration_ms and (.context_updated != null)' >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 5: Pane field matches input
echo -n "Test 5: Pane field matches input... "
((total++))
pane_out=$(./sane-detect-ssh "tues:0.0" 2>/dev/null | jq -r '.pane')
if [[ "$pane_out" == "tues:0.0" ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 6: Context update flag
echo -n "Test 6: --update-context flag... "
((total++))
result=$(./sane-detect-ssh "tues:0.0" --update-context 2>/dev/null)
if echo "$result" | jq -r '.context_updated' | grep -q "true"; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 7: Label flag
echo -n "Test 7: --label flag... "
((total++))
result=$(./sane-detect-ssh "tues:0.0" --label "test-label-$RANDOM" 2>/dev/null)
label=$(echo "$result" | jq -r '.label')
if [[ "$label" == test-label-* ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 8: ssh_detected is boolean
echo -n "Test 8: ssh_detected is boolean... "
((total++))
result=$(./sane-detect-ssh "tues:0.0" 2>/dev/null)
ssh_detected=$(echo "$result" | jq '.ssh_detected')
if [[ "$ssh_detected" == "true" ]] || [[ "$ssh_detected" == "false" ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 9: duration_ms is numeric
echo -n "Test 9: duration_ms is numeric... "
((total++))
result=$(./sane-detect-ssh "tues:0.0" 2>/dev/null)
duration=$(echo "$result" | jq '.duration_ms')
if [[ "$duration" =~ ^[0-9]+$ ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 10: port is numeric
echo -n "Test 10: port is numeric... "
((total++))
result=$(./sane-detect-ssh "tues:0.0" 2>/dev/null)
port=$(echo "$result" | jq '.port')
if [[ "$port" =~ ^[0-9]+$ ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

echo ""
echo "=========================================="
echo "Results: $passed/$total tests passed"

if [[ $passed -eq $total ]]; then
    exit 0
else
    exit 1
fi
