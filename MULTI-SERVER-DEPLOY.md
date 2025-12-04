# Complex Workflow: Deploy to Multiple Servers

This document demonstrates using **tmux-sane** primitives to orchestrate deployments across multiple servers - a realistic multi-host agent workflow.

## Scenario

An AI agent needs to:
1. Deploy an application to 3 remote servers simultaneously
2. Verify health status on each server
3. Run coordinated checks across all servers
4. Track deployment state across the fleet
5. Handle errors gracefully if any server fails

## Commands Used

- `sane-run-command` - Execute commands on remote servers
- `sane-create-file` - Create deployment scripts
- `sane-detect-platform` - Detect platform on orchestrator
- `sane-list-panes` - Track session structure

## Workflow Steps

### Step 1: Setup Deployment Environment

The orchestrator creates directories for each server's deployment:

```bash
# Create server directories
mkdir -p /tmp/deploy/server1 /tmp/deploy/server2 /tmp/deploy/server3

# Verify structure
ls -d /tmp/deploy/server* | wc -l  # Should output: 3
```

### Step 2: Deploy to Each Server

For each server, the agent:
1. Copies the deployment script
2. Executes the deployment
3. Creates a health status file

```bash
# On each server:
# 1. Simulate deployment steps
# 2. Create health.json with status
echo '{"status":"healthy","version":"1.0.0"}' > /server/health.json
```

### Step 3: Independent Health Verification

Verify each server's health independently:

```bash
# Check server1
if [[ -f /deploy/server1/health.json ]]; then
    jq -r '.status' < /deploy/server1/health.json
fi

# Check server2
if [[ -f /deploy/server2/health.json ]]; then
    jq -r '.status' < /deploy/server2/health.json
fi
```

### Step 4: Orchestrated Multi-Server Verification

Run a coordinated check across all servers:

```bash
# Verify all servers are healthy
for SERVER in server1 server2 server3; do
    if [[ -f "/deploy/$SERVER/health.json" ]]; then
        STATUS=$(jq -r '.status' < "/deploy/$SERVER/health.json")
        if [[ "$STATUS" == "healthy" ]]; then
            echo "✓ [$SERVER] healthy"
        fi
    fi
done
```

## Key Agent Lessons

### 1. Orchestration Pattern
- Use a single orchestrator pane to coordinate all servers
- Track state for each server separately
- Maintain independence while coordinating

### 2. Health Tracking
- Each server reports its own health status
- Store status files in predictable locations
- Query status from orchestrator independently

### 3. Error Handling
- Check each server's status before declaring success
- Accumulate success counts
- Handle partial failures gracefully

### 4. Scalability
- The pattern works for 3 servers or 30 servers
- Loop structure scales automatically
- No hard-coded server limits

## Example: Handling a Failed Server

If server2 deployment fails:

```bash
# Deployment fails for server2
# But agent continues with server3

# Verification shows:
# ✓ server1 healthy
# ✗ server2 failed
# ✓ server3 healthy

# Agent can:
# 1. Alert operator to server2 issue
# 2. Retry server2 deployment
# 3. Rollback other servers if needed
```

## Testing This Workflow

Run the comprehensive test:

```bash
bash tests/test-multi-server-deploy.sh
```

The test demonstrates:
- Setting up 3 simulated servers
- Deploying to each independently
- Verifying health across the fleet
- Handling success/failure scenarios

## Real-World Applications

This workflow pattern works for:
- **Blue-Green Deployments**: Deploy to server1, server2, then switch traffic
- **Canary Releases**: Deploy to server1 first, verify, then deploy to server2
- **Multi-Region Deployments**: Deploy to us-east, us-west, eu-west
- **Disaster Recovery**: Deploy to primary and backup sites
- **A/B Testing**: Deploy version A to server1, version B to server2

## Performance Characteristics

- Sequential deployments: ~O(n) where n = number of servers
- Parallel verification: Can check all servers in one round with `sane-run-command`
- Health status lookup: O(1) per server with JSON queries

## Integration with AI Agents

An expensive AI agent (Claude Sonnet):
1. Plans the multi-server deployment
2. Calls `sane-run-command` for each step
3. Uses cheap agents for health polling
4. Makes decisions based on results

A cheap AI agent (Nova Lite):
1. Polls health status frequently
2. Detects completion via status changes
3. Alerts expensive agent when done

This separation keeps costs low while maintaining reliability.
