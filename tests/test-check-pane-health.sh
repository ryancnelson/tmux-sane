#!/usr/bin/env bash

# Test suite for sane-check-pane-health command
# Tests pane health checking (responsive, frozen, dead states)

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

total=0
passed=0

echo "Test Suite: sane-check-pane-health Command"
echo "==========================================="
echo ""

# Ensure we're in the project directory
cd "$(dirname "$0")/.." || exit 1

# Check if sane-check-pane-health exists
if [ ! -f ./sane-check-pane-health ]; then
    echo "❌ sane-check-pane-health not found. Creating stub..."
    exit 1
fi

# Ensure we have a test tmux session
if ! tmux has-session -t tues 2>/dev/null; then
    echo "❌ Test session 'tues' not found"
    exit 1
fi

# Test 1: Help text
echo -n "Test 1: Help text... "
((total++))
if ./sane-check-pane-health | grep -q "Usage"; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 2: Invalid session error
echo -n "Test 2: Invalid session error... "
((total++))
if (./sane-check-pane-health invalid-session-$RANDOM 2>&1 || true) | grep -q -i "error"; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 3: Valid JSON output
echo -n "Test 3: Valid JSON output... "
((total++))
if ./sane-check-pane-health tues:0.0 2>/dev/null | jq . > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 4: Has required fields (pane, health_status, responsive, frozen, details)
echo -n "Test 4: Required fields (pane, health_status, responsive, frozen, details, timestamp, duration_ms)... "
((total++))
result=$(./sane-check-pane-health tues:0.0 2>/dev/null)
if echo "$result" | jq -e '.pane and .health_status and (.responsive != null) and (.frozen != null) and .details and .timestamp and .duration_ms' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 5: Pane field matches input
echo -n "Test 5: Pane field matches input... "
((total++))
pane_out=$(./sane-check-pane-health tues:0.0 2>/dev/null | jq -r .pane)
if [ "$pane_out" = "tues:0.0" ]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 6: health_status is one of: healthy, frozen, dead, unknown
echo -n "Test 6: health_status is valid enum (healthy/frozen/dead/unknown)... "
((total++))
status=$(./sane-check-pane-health tues:0.0 2>/dev/null | jq -r .health_status)
if [[ "$status" =~ ^(healthy|frozen|dead|unknown)$ ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 7: responsive is boolean
echo -n "Test 7: responsive is boolean... "
((total++))
responsive=$(./sane-check-pane-health tues:0.0 2>/dev/null | jq .responsive)
if [[ "$responsive" == "true" ]] || [[ "$responsive" == "false" ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 8: frozen is boolean
echo -n "Test 8: frozen is boolean... "
((total++))
frozen=$(./sane-check-pane-health tues:0.0 2>/dev/null | jq .frozen)
if [[ "$frozen" == "true" ]] || [[ "$frozen" == "false" ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 9: duration_ms is numeric
echo -n "Test 9: duration_ms is numeric... "
((total++))
duration=$(./sane-check-pane-health tues:0.0 2>/dev/null | jq .duration_ms)
if [[ "$duration" =~ ^[0-9]+$ ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 10: timestamp is ISO8601 format
echo -n "Test 10: timestamp is ISO8601 format... "
((total++))
timestamp=$(./sane-check-pane-health tues:0.0 2>/dev/null | jq -r .timestamp)
if [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 11: Can check all panes in session
echo -n "Test 11: Can check all panes (--all flag)... "
((total++))
if ./sane-check-pane-health tues --all 2>/dev/null | jq . > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

# Test 12: --all returns array
echo -n "Test 12: --all returns array of panes... "
((total++))
result=$(./sane-check-pane-health tues --all 2>/dev/null)
if echo "$result" | jq -e '. | length > 0' > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
    ((passed++))
else
    echo -e "${RED}✗${NC}"
fi

echo ""
echo "==========================================="
echo "Results: $passed/$total tests passed"

if [ "$passed" -eq "$total" ]; then
    exit 0
else
    exit 1
fi
