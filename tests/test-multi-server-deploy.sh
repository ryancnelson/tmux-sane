#!/usr/bin/env bash
# Test: Complex Agent Workflow - Deploy to Multiple Servers
# Demonstrates orchestrating deployments to multiple servers using sane-* commands
#
# This test shows how AI agents can:
# - Manage multiple deployment targets
# - Track deployment state across servers
# - Verify health checks on each server
# - Coordinate multi-server orchestration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Scripts we're using
CREATE_FILE_SCRIPT="$PROJECT_DIR/sane-create-file"
RUN_COMMAND_SCRIPT="$PROJECT_DIR/sane-run-command"
LIST_PANES_SCRIPT="$PROJECT_DIR/sane-list-panes"
DETECT_PLATFORM_SCRIPT="$PROJECT_DIR/sane-detect-platform"

# Test session
TEST_SESSION="tues"
TEST_SUFFIX="$$-$RANDOM"

# Use default pane for orchestration
ORCHESTRATOR_PANE="$TEST_SESSION:0.0"

# Deployment directories
DEPLOY_DIR="/tmp/deploy-test-$TEST_SUFFIX"
SERVER1_ROOT="$DEPLOY_DIR/server1"
SERVER2_ROOT="$DEPLOY_DIR/server2"
SERVER3_ROOT="$DEPLOY_DIR/server3"

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

cleanup() {
    # Remove test directories
    if [[ -d "$DEPLOY_DIR" ]]; then
        rm -rf "$DEPLOY_DIR"
    fi
}

trap cleanup EXIT

echo "=========================================="
echo "Complex Workflow: Deploy to Multiple Servers"
echo "=========================================="
echo ""

# Verify session exists
echo "Verifying tmux session..."
if ! tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
    echo "Error: Test session '$TEST_SESSION' does not exist"
    echo "Please create it: tmux new-session -d -s $TEST_SESSION"
    exit 1
fi
test_pass "Test session exists"
echo ""

# Verify required scripts exist
echo "Verifying required scripts..."
for script in "$CREATE_FILE_SCRIPT" "$RUN_COMMAND_SCRIPT" "$LIST_PANES_SCRIPT" "$DETECT_PLATFORM_SCRIPT"; do
    if [[ ! -x "$script" ]]; then
        echo "Error: Required script not found: $script"
        exit 1
    fi
done
test_pass "All required scripts available"
echo ""

# PHASE 1: Setup deployment environment
echo "=== PHASE 1: Setup Deployment Environment ==="

# Create server directories
echo "Creating server directories..."
CREATE_CMD="mkdir -p '$SERVER1_ROOT' '$SERVER2_ROOT' '$SERVER3_ROOT' && ls -d '$DEPLOY_DIR'/server* | wc -l"
OUTPUT=$($RUN_COMMAND_SCRIPT "$ORCHESTRATOR_PANE" "$CREATE_CMD" 15)

if echo "$OUTPUT" | jq -e '.exit_code == 0' > /dev/null 2>&1; then
    OUTPUT_TEXT=$(echo "$OUTPUT" | jq -r '.output // empty')
    SERVER_COUNT=$(echo "$OUTPUT_TEXT" | tail -1 | tr -d '[:space:]')
    if [[ "$SERVER_COUNT" == "3" ]]; then
        test_pass "3 server directories created"
    else
        test_fail "Server directory count" "3 directories" "$SERVER_COUNT"
    fi
else
    test_fail "Creating server directories" "exit code 0" "$(echo "$OUTPUT" | jq -r '.exit_code // empty')"
fi
echo ""

# PHASE 2: Deploy and verify each server
echo "=== PHASE 2: Deploy and Verify Servers ==="
echo ""

SERVERS=("server1" "server2" "server3")
DEPLOYMENTS_OK=0
HEALTH_OK=0

for SERVER in "${SERVERS[@]}"; do
    echo "Deploying to $SERVER..."
    
    # Simulate deployment by creating a health status file
    SERVER_ROOT="$DEPLOY_DIR/$SERVER"
    DEPLOY_CMD="echo 'Deploying to $SERVER'; mkdir -p '$SERVER_ROOT'; echo '{\"status\":\"healthy\",\"version\":\"1.0.0\"}' > '$SERVER_ROOT/health.json' && cat '$SERVER_ROOT/health.json'"
    
    OUTPUT=$($RUN_COMMAND_SCRIPT "$ORCHESTRATOR_PANE" "$DEPLOY_CMD" 15)
    
    if echo "$OUTPUT" | jq -e '.exit_code == 0' > /dev/null 2>&1; then
        test_pass "$SERVER deployment completed"
        ((DEPLOYMENTS_OK=DEPLOYMENTS_OK+1))
        
        # Check health status
        OUTPUT_TEXT=$(echo "$OUTPUT" | jq -r '.output // empty')
        if echo "$OUTPUT_TEXT" | grep -q "healthy"; then
            test_pass "$SERVER health status shows healthy"
            ((HEALTH_OK=HEALTH_OK+1))
        fi
    else
        test_fail "$SERVER deployment" "exit code 0" "$(echo "$OUTPUT" | jq -r '.exit_code // empty')"
    fi
done
echo ""

# PHASE 3: Orchestrated verification
echo "=== PHASE 3: Orchestrated Verification ==="
echo ""

echo "Running orchestrated health check across all servers..."

# Check each server's health file
ORCHESTRATED_OK=0
for SERVER in server1 server2 server3; do
    SERVER_ROOT="$DEPLOY_DIR/$SERVER"
    CHECK_CMD="[[ -f '$SERVER_ROOT/health.json' ]] && jq -r '.status' < '$SERVER_ROOT/health.json'"
    
    OUTPUT=$($RUN_COMMAND_SCRIPT "$ORCHESTRATOR_PANE" "$CHECK_CMD" 15)
    
    if echo "$OUTPUT" | jq -e '.exit_code == 0' > /dev/null 2>&1; then
        OUTPUT_TEXT=$(echo "$OUTPUT" | jq -r '.output // empty')
        if echo "$OUTPUT_TEXT" | grep -q "healthy"; then
            ((ORCHESTRATED_OK=ORCHESTRATED_OK+1))
        fi
    fi
done

if [[ $ORCHESTRATED_OK -ge 3 ]]; then
    test_pass "All servers verified as healthy"
else
    test_fail "Server health reports" "at least 3 healthy" "$ORCHESTRATED_OK healthy"
fi
echo ""

# PHASE 4: List and track deployment state
echo "=== PHASE 4: Deployment State Tracking ==="
echo ""

echo "Listing deployment files..."
LIST_CMD="find '$DEPLOY_DIR' -type f -name 'health.json' | xargs wc -l | tail -1"
OUTPUT=$($RUN_COMMAND_SCRIPT "$ORCHESTRATOR_PANE" "$LIST_CMD" 15)

if echo "$OUTPUT" | jq -e '.exit_code == 0' > /dev/null 2>&1; then
    OUTPUT_TEXT=$(echo "$OUTPUT" | jq -r '.output // empty')
    if echo "$OUTPUT_TEXT" | grep -qE '[0-9]+'; then
        test_pass "Deployment files verified and tracked"
    fi
fi
echo ""

# PHASE 5: Platform awareness and context tracking
echo "=== PHASE 5: Platform and Context Awareness ==="
echo ""

echo "Detecting platform on orchestrator pane..."
OUTPUT=$($DETECT_PLATFORM_SCRIPT "$ORCHESTRATOR_PANE")
if echo "$OUTPUT" | jq -e '.os' > /dev/null 2>&1; then
    PLATFORM=$(echo "$OUTPUT" | jq -r '.os // empty')
    test_pass "Orchestrator platform detected: $PLATFORM"
else
    test_fail "Platform detection" "JSON with os or platform field" "$OUTPUT"
fi
echo ""

# PHASE 6: Summary
echo "=== PHASE 6: Deployment Summary ==="
echo ""

echo "Deployment Results:"
echo "  Servers deployed: $DEPLOYMENTS_OK/3"
echo "  Servers healthy: $HEALTH_OK/3"
echo ""

if [[ $DEPLOYMENTS_OK -eq 3 ]] && [[ $HEALTH_OK -eq 3 ]]; then
    test_pass "Complete deployment workflow successful"
fi

echo "Key Agent Workflow Lessons:"
echo "  ✓ Orchestrate commands across multiple targets"
echo "  ✓ Track deployment state per server"
echo "  ✓ Verify health independently"
echo "  ✓ Run coordinated verification"
echo "  ✓ Maintain system context across operations"
echo ""

# Results
echo "=========================================="
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
echo "=========================================="

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
