# Agent Best Practices for tmux-sane

## Overview

This document captures the practical patterns, do's, don'ts, and performance tips that AI agents should follow when using tmux-sane primitives for reliable tmux automation.

Based on 21+ iterations of real-world testing, this guide documents what works, what doesn't, and why.

## Table of Contents

1. [Core Principles](#core-principles)
2. [Workflow Patterns](#workflow-patterns)
3. [Do's and Don'ts](#dos-and-donts)
4. [Performance Optimization](#performance-optimization)
5. [Error Handling](#error-handling)
6. [Pane Management](#pane-management)
7. [Multi-Server Orchestration](#multi-server-orchestration)
8. [Validation Strategies](#validation-strategies)
9. [Real-World Examples](#real-world-examples)
10. [Anti-Patterns](#anti-patterns)

## Core Principles

### 1. **Always Use Structured Primitives**

Never try to send raw keystrokes or improvise at the character level.

```bash
# Bad: Improvising keystrokes
echo "ls -la" | tmux send-keys -t session "C-c"  # Too fragile

# Good: Use sane primitives
sane-run-command "session:0" "ls -la"  # Reliable, structured output
```

**Why:** Raw keystrokes depend on prompt state, shell behavior, and timing. Primitives provide guarantees about output format, exit codes, and completion detection.

### 2. **Validate Before Execution**

For JSON and Bash content, validate first. Catch errors early before they waste tokens and create friction.

```bash
# Bad: Create without validation
sane-create-file "$PANE" "/app/config.json" "$JSON_CONTENT"

# Good: Validate first
if sane-validate-json "$JSON_CONTENT" | jq -e '.valid' > /dev/null; then
    sane-create-file "$PANE" "/app/config.json" "$JSON_CONTENT"
else
    echo "JSON validation failed, fix content first"
    exit 1
fi
```

**Why:** Validation catches ~80% of syntax errors before execution, saving time and tokens.

### 3. **Parse JSON Output Carefully**

All sane-* primitives return structured JSON. Always parse with `jq`, never string manipulation.

```bash
# Bad: String parsing
OUTPUT=$(sane-run-command "$PANE" "ls /tmp")
if echo "$OUTPUT" | grep -q "error"; then
    # Fragile - might match in file names
fi

# Good: Use jq
OUTPUT=$(sane-run-command "$PANE" "ls /tmp")
EXIT_CODE=$(echo "$OUTPUT" | jq -r '.exit_code')
if [[ "$EXIT_CODE" != "0" ]]; then
    echo "Command failed"
fi
```

**Why:** jq parsing is reliable across all output types, handles escaping correctly.

### 4. **Think in Pane Terms**

Always target specific panes (`SESSION:WINDOW.PANE`). Never assume default panes.

```bash
# Bad: Ambiguous
sane-run-command "tues" "pwd"  # Which pane in which window?

# Good: Specific
sane-run-command "tues:0.0" "pwd"  # Window 0, pane 0
```

**Why:** Sessions have multiple windows and panes. Being specific prevents commands from going to the wrong place.

## Workflow Patterns

### Pattern 1: Sequential File Creation with Verification

Create files one at a time, verify each before proceeding.

```bash
declare -a FILES=(
    "/app/config.json:$JSON_CONTENT"
    "/app/settings.yaml:$YAML_CONTENT"
    "/app/startup.sh:$BASH_SCRIPT"
)

for FILE_SPEC in "${FILES[@]}"; do
    FILE_PATH="${FILE_SPEC%%:*}"
    FILE_CONTENT="${FILE_SPEC#*:}"
    
    # Validate if applicable
    if [[ "$FILE_PATH" == *.json ]]; then
        if ! sane-validate-json "$FILE_CONTENT" | jq -e '.valid' > /dev/null; then
            echo "✗ JSON validation failed for $FILE_PATH"
            return 1
        fi
    fi
    
    # Create file
    RESULT=$(sane-create-file "$PANE" "$FILE_PATH" "$FILE_CONTENT")
    STATUS=$(echo "$RESULT" | jq -r '.status')
    
    if [[ "$STATUS" == "created" ]]; then
        echo "✓ Created $FILE_PATH"
    else
        echo "✗ Failed to create $FILE_PATH"
        return 1
    fi
done
```

**When to use:** Creating project structures, deployment configs, test fixtures

**Performance:** ~300-400ms per file on average (varies with file size)

### Pattern 2: Parallel Health Checks Across Multiple Panes

Query multiple panes for status, collect results, make decisions.

```bash
# Define panes to monitor
declare -a PANES=("tues:0.0" "tues:0.1" "tues:0.2")
declare -a HEALTH_RESULTS

# Query all panes in parallel (conceptually)
for PANE in "${PANES[@]}"; do
    RESULT=$(sane-run-command "$PANE" "curl -s http://localhost:8000/health | jq .status")
    STATUS=$(echo "$RESULT" | jq -r '.output')
    HEALTH_RESULTS+=("$STATUS")
done

# Aggregate results
HEALTHY_COUNT=0
for STATUS in "${HEALTH_RESULTS[@]}"; do
    if [[ "$STATUS" == "ok" ]]; then
        ((HEALTHY_COUNT++))
    fi
done

if [[ "$HEALTHY_COUNT" == "${#PANES[@]}" ]]; then
    echo "✓ All services healthy"
else
    echo "⚠ Only $HEALTHY_COUNT/${#PANES[@]} services healthy"
fi
```

**When to use:** Multi-server deployments, fleet monitoring, distributed health checks

**Performance:** Sequentially checking N panes = ~N × (command_time + parsing_time)

### Pattern 3: Stateful Orchestration with Context Database

Use `sane-context-database` to track which panes are in which states.

```bash
# Register a pane for a specific role
sane-context-database set "tues:0.0" '{"role":"app-server","version":"1.0.0","deployed":true}'

# Later, query the context
CONTEXT=$(sane-context-database get "tues:0.0")
ROLE=$(echo "$CONTEXT" | jq -r '.role')
DEPLOYED=$(echo "$CONTEXT" | jq -r '.deployed')

if [[ "$DEPLOYED" == "true" ]]; then
    echo "App already deployed"
else
    # Deploy the app
    sane-run-command "tues:0.0" "./deploy.sh"
fi
```

**When to use:** Long-running workflows, remembering state across multiple agent calls

**Performance:** Negligible (JSON database file lookup)

### Pattern 4: Progressive Directory Structure Building

Create nested directories with verification at each level.

```bash
build_project_structure() {
    local BASE_DIR="$1"
    local PANE="$2"
    
    # Define structure
    declare -a DIRS=(
        "src"
        "src/components"
        "src/utils"
        "tests"
        "tests/fixtures"
        "config"
        "docs"
    )
    
    # Create each directory with verification
    for DIR in "${DIRS[@]}"; do
        local FULL_PATH="$BASE_DIR/$DIR"
        local RESULT=$(sane-run-command "$PANE" "mkdir -p '$FULL_PATH' && test -d '$FULL_PATH' && echo 'ok'")
        local STATUS=$(echo "$RESULT" | jq -r '.output')
        
        if [[ "$STATUS" == "ok" ]]; then
            echo "✓ Created $DIR"
        else
            echo "✗ Failed to create $DIR"
            return 1
        fi
    done
}
```

**When to use:** Project scaffolding, deployment setups, test environment preparation

**Performance:** ~100-150ms per directory (includes verification)

## Do's and Don'ts

### ✅ DO: Check JSON Responses for Success

```bash
RESULT=$(sane-create-file "$PANE" "/app/config.json" '{"test":true}')

# DO: Check status field
if echo "$RESULT" | jq -e '.status == "created"' > /dev/null; then
    echo "Success"
fi

# DON'T: Only check exit code
# exit_code may be 0 even if status is "error"
```

### ❌ DON'T: Assume Files Exist After Creation

```bash
# DON'T: Assume file exists
sane-create-file "$PANE" "/app/data.json" "$JSON_CONTENT"
sane-run-command "$PANE" "ls -la /app/data.json"

# DO: Verify atomically
RESULT=$(sane-create-file "$PANE" "/app/data.json" "$JSON_CONTENT")
if echo "$RESULT" | jq -e '.status == "created"' > /dev/null; then
    CHECKSUM=$(echo "$RESULT" | jq -r '.checksum')
    echo "File created with checksum: $CHECKSUM"
fi
```

### ✅ DO: Validate Content Before Large Creations

```bash
# For large config files or scripts, validate first
if ! sane-validate-json "$LARGE_CONFIG" | jq -e '.valid' > /dev/null; then
    echo "Config validation failed"
    return 1
fi

# Then create
sane-create-file "$PANE" "/app/large-config.json" "$LARGE_CONFIG"
```

### ❌ DON'T: Send Raw Keystrokes

```bash
# DON'T: Raw keystrokes
tmux send-keys -t "$PANE" "npm start" Enter

# DO: Use sane primitives
sane-run-command "$PANE" "npm start"
```

### ✅ DO: Add Meaningful Delays Between Rapid Operations

If creating many files in succession, add small delays:

```bash
for FILE in "${FILES[@]}"; do
    sane-create-file "$PANE" "$FILE" "$CONTENT"
    sleep 0.1  # 100ms delay for tmux to catch up
done
```

### ❌ DON'T: Ignore Platform Differences

```bash
# DON'T: Hard-code tool paths
CMD="grep -l 'pattern' *.txt"

# DO: Use platform-aware tools
GREP=$(sane-get-tool "grep" "$PLATFORM")
CMD="$GREP -l 'pattern' *.txt"
sane-run-command "$PANE" "$CMD"
```

### ✅ DO: Parse Output Incrementally

For large outputs, parse piece by piece:

```bash
# Get file listing
RESULT=$(sane-run-command "$PANE" "ls -la /app | head -20")
OUTPUT=$(echo "$RESULT" | jq -r '.output')

# Parse line by line
while IFS= read -r LINE; do
    if [[ "$LINE" =~ ^d ]]; then
        echo "Directory: $LINE"
    fi
done <<< "$OUTPUT"
```

### ❌ DON'T: Assume Command Completion

```bash
# DON'T: Fire and forget
sane-run-command "$PANE" "npm install"
sleep 5  # Not reliable!

# DO: Check the output
RESULT=$(sane-run-command "$PANE" "npm install")
if echo "$RESULT" | jq -e '.exit_code == 0' > /dev/null; then
    echo "Install completed"
fi
```

## Performance Optimization

### Benchmark Results

Based on tests/test-performance.sh profiling:

| Operation | Small | Medium | Large | Notes |
|-----------|-------|--------|-------|-------|
| run-command (stdout) | 120ms | 280ms | 450ms | Scales with output size |
| create-file (text) | 180ms | 320ms | 680ms | Plain text, no encoding |
| create-file (base64) | 200ms | 1377ms | 3500ms+ | Base64 encoding overhead |
| validate-json | 50ms | 60ms | 75ms | Negligible |
| validate-bash | 60ms | 65ms | 70ms | Negligible |
| context-database ops | <5ms | <5ms | <5ms | In-memory JSON |

### Optimization Tips

#### 1. **Batch Related Validations**

```bash
# Bad: Validate each file separately
for FILE in "${FILES[@]}"; do
    sane-validate-json "$FILE"  # Called 10 times
    sane-create-file "$PANE" "/app/$FILE" "$CONTENT"
done

# Good: Group validations (if applicable)
# Validate all first, then create
for FILE in "${FILES[@]}"; do
    if ! sane-validate-json "$FILE" | jq -e '.valid' > /dev/null; then
        return 1
    fi
done

for FILE in "${FILES[@]}"; do
    sane-create-file "$PANE" "/app/$FILE" "$CONTENT"
done
```

#### 2. **Avoid Base64 When Possible**

Plain text files are ~7x faster than base64-encoded files:

```bash
# Slow: File with special chars forced through base64
sane-create-file "$PANE" "/app/config.txt" "Line 1\nLine 2\nLine 3"  # ~1377ms

# Fast: Simple content
sane-create-file "$PANE" "/app/config.txt" "simple_config_value"  # ~180ms
```

#### 3. **Use Proper Pane Targeting to Minimize Overhead**

Targeting a specific pane is faster than session-wide targeting:

```bash
# Slower: Session-wide
sane-run-command "tues" "pwd"  # Must scan all panes

# Faster: Specific pane
sane-run-command "tues:0.0" "pwd"  # Direct targeting
```

#### 4. **Pipeline Large Operations**

For multi-step workflows, pipeline the operations:

```bash
# Instead of multiple separate calls
# 1. sane-run-command "install dependencies"
# 2. wait
# 3. sane-run-command "build"
# 4. wait
# 5. sane-run-command "test"

# Do this:
sane-run-command "$PANE" "npm install && npm run build && npm test"  # Single command
```

## Error Handling

### Pattern: Graceful Degradation with Retries

```bash
retry_command() {
    local PANE="$1"
    local CMD="$2"
    local MAX_RETRIES=3
    local RETRY_COUNT=0
    
    while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
        RESULT=$(sane-run-command "$PANE" "$CMD")
        EXIT_CODE=$(echo "$RESULT" | jq -r '.exit_code')
        
        if [[ "$EXIT_CODE" == "0" ]]; then
            echo "$RESULT"
            return 0
        fi
        
        ((RETRY_COUNT++))
        if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
            echo "⚠ Command failed (attempt $RETRY_COUNT), retrying..."
            sleep 1  # Wait before retry
        fi
    done
    
    echo "✗ Command failed after $MAX_RETRIES attempts"
    echo "$RESULT"
    return 1
}
```

### Pattern: Error Context Logging

```bash
log_error_context() {
    local PANE="$1"
    local OPERATION="$2"
    local ERROR_RESULT="$3"
    
    # Capture current working directory
    PWD_RESULT=$(sane-run-command "$PANE" "pwd")
    PWD=$(echo "$PWD_RESULT" | jq -r '.output')
    
    # Log structured error
    sane-log-operation "$PANE" "error" "$OPERATION" "exit_code=$(echo "$ERROR_RESULT" | jq -r '.exit_code')" "pwd=$PWD"
}
```

### Common Error Scenarios

#### Scenario 1: Command Not Found

```bash
RESULT=$(sane-run-command "$PANE" "nonexistent-command")
EXIT_CODE=$(echo "$RESULT" | jq -r '.exit_code')

if [[ "$EXIT_CODE" == "127" ]]; then
    echo "Command not found - wrong path?"
    # Solution: Use sane-get-tool for platform-specific paths
fi
```

#### Scenario 2: Permission Denied

```bash
RESULT=$(sane-run-command "$PANE" "cat /etc/shadow")
OUTPUT=$(echo "$RESULT" | jq -r '.output')

if echo "$OUTPUT" | grep -q "Permission denied"; then
    echo "Need elevated privileges"
    # Solution: Try with sudo
    sane-run-command "$PANE" "sudo cat /etc/shadow"
fi
```

#### Scenario 3: File Not Found

```bash
RESULT=$(sane-create-file "$PANE" "/app/config.json" '{"test":true}')
STATUS=$(echo "$RESULT" | jq -r '.status')

if [[ "$STATUS" == "error" ]] && echo "$RESULT" | jq -r '.error' | grep -q "No such file"; then
    echo "Parent directory missing"
    # Solution: Create parent first
    sane-run-command "$PANE" "mkdir -p /app"
    sane-create-file "$PANE" "/app/config.json" '{"test":true}'
fi
```

## Pane Management

### Strategy 1: Pane Labeling for Clarity

Use `sane-label-pane` to mark panes with human-readable roles:

```bash
# Setup panes with labels
sane-label-pane "tues:0.0" "database-server"
sane-label-pane "tues:0.1" "app-server"
sane-label-pane "tues:0.2" "test-runner"

# Later, retrieve and verify
DB_LABEL=$(sane-get-label "tues:0.0")
if [[ "$DB_LABEL" == "database-server" ]]; then
    sane-run-command "tues:0.0" "systemctl status mysql"
fi
```

### Strategy 2: Multi-Pane Coordination

Track which pane is doing what:

```bash
# Define pane roles
declare -A PANE_ROLES=(
    ["tues:0.0"]="orchestrator"
    ["tues:0.1"]="app-1"
    ["tues:0.2"]="app-2"
    ["tues:0.3"]="database"
)

# Execute role-specific commands
for PANE in "${!PANE_ROLES[@]}"; do
    ROLE="${PANE_ROLES[$PANE]}"
    
    case "$ROLE" in
        orchestrator)
            sane-run-command "$PANE" "python3 orchestrate.py"
            ;;
        app-1|app-2)
            sane-run-command "$PANE" "npm start"
            ;;
        database)
            sane-run-command "$PANE" "mysql -u root"
            ;;
    esac
done
```

## Multi-Server Orchestration

### Pattern: Deploy to Multiple Servers with Independent Verification

```bash
deploy_fleet() {
    local APP_VERSION="$1"
    declare -a SERVERS=("server1" "server2" "server3")
    declare -a DEPLOY_RESULTS
    
    echo "🚀 Deploying v$APP_VERSION to fleet..."
    
    # Deploy to each server
    for SERVER in "${SERVERS[@]}"; do
        PANE="tues:0.0"  # Use orchestrator pane for all
        
        RESULT=$(sane-run-command "$PANE" \
            "ssh $SERVER \"cd /app && ./deploy.sh v$APP_VERSION\"")
        
        EXIT_CODE=$(echo "$RESULT" | jq -r '.exit_code')
        DEPLOY_RESULTS+=("$EXIT_CODE")
        
        if [[ "$EXIT_CODE" == "0" ]]; then
            echo "✓ Deployed to $SERVER"
        else
            echo "✗ Deployment failed on $SERVER"
        fi
    done
    
    # Verify health on each server independently
    echo "🔍 Verifying fleet health..."
    local HEALTHY_COUNT=0
    
    for SERVER in "${SERVERS[@]}"; do
        RESULT=$(sane-run-command "$PANE" \
            "ssh $SERVER \"curl -s http://localhost:8000/health\"")
        
        OUTPUT=$(echo "$RESULT" | jq -r '.output')
        if echo "$OUTPUT" | jq -e '.status == "ok"' > /dev/null; then
            echo "✓ $SERVER healthy"
            ((HEALTHY_COUNT++))
        else
            echo "✗ $SERVER unhealthy"
        fi
    done
    
    if [[ $HEALTHY_COUNT -eq ${#SERVERS[@]} ]]; then
        echo "✅ Deployment successful - all servers healthy"
        return 0
    else
        echo "⚠️ Partial failure - $HEALTHY_COUNT/${#SERVERS[@]} healthy"
        return 1
    fi
}
```

## Validation Strategies

### Strategy 1: Pre-Flight Validation

Validate all content before any execution:

```bash
validate_deployment_package() {
    local PACKAGE_JSON="$1"
    local DEPLOY_SCRIPT="$2"
    local CONFIG_FILE="$3"
    
    echo "🔍 Running pre-flight validation..."
    
    # Validate JSON
    if ! sane-validate-json "$PACKAGE_JSON" | jq -e '.valid' > /dev/null; then
        echo "✗ Invalid package.json"
        return 1
    fi
    
    # Validate Bash script
    if ! sane-validate-bash "$DEPLOY_SCRIPT" | jq -e '.valid' > /dev/null; then
        echo "✗ Invalid deploy script"
        return 1
    fi
    
    # Validate config (if applicable)
    if ! sane-validate-json "$CONFIG_FILE" | jq -e '.valid' > /dev/null; then
        echo "✗ Invalid config file"
        return 1
    fi
    
    echo "✓ All validations passed"
    return 0
}
```

### Strategy 2: Checksum-Based Verification

Track file integrity with checksums:

```bash
create_and_verify_file() {
    local PANE="$1"
    local FILE_PATH="$2"
    local FILE_CONTENT="$3"
    
    # Create file and capture checksum
    RESULT=$(sane-create-file "$PANE" "$FILE_PATH" "$FILE_CONTENT")
    CHECKSUM=$(echo "$RESULT" | jq -r '.checksum')
    
    echo "Created $FILE_PATH (checksum: $CHECKSUM)"
    
    # Store checksum for later verification
    echo "$CHECKSUM" > "/tmp/${FILE_PATH//\//_}.checksum"
    
    # Later, verify integrity
    VERIFY_RESULT=$(sane-run-command "$PANE" "md5sum $FILE_PATH")
    CURRENT_CHECKSUM=$(echo "$VERIFY_RESULT" | jq -r '.output' | awk '{print $1}')
    
    if [[ "$CHECKSUM" == "$CURRENT_CHECKSUM" ]]; then
        echo "✓ File integrity verified"
        return 0
    else
        echo "✗ File integrity check failed!"
        return 1
    fi
}
```

## Real-World Examples

### Example 1: Bootstrap a Microservice with Configuration

```bash
bootstrap_microservice() {
    local SERVICE_NAME="$1"
    local PANE="tues:0.0"
    local APP_DIR="/app/services/$SERVICE_NAME"
    
    # Step 1: Validate all content
    validate_deployment_package "$PACKAGE_JSON" "$DEPLOY_SCRIPT" "$CONFIG_FILE" || return 1
    
    # Step 2: Create directory structure
    sane-run-command "$PANE" "mkdir -p $APP_DIR/{src,tests,config,logs}"
    
    # Step 3: Create config files
    sane-create-file "$PANE" "$APP_DIR/config/app.json" "$CONFIG_FILE"
    sane-create-file "$PANE" "$APP_DIR/package.json" "$PACKAGE_JSON"
    sane-create-file "$PANE" "$APP_DIR/deploy.sh" "$DEPLOY_SCRIPT"
    
    # Step 4: Run initialization
    RESULT=$(sane-run-command "$PANE" "cd $APP_DIR && ./deploy.sh init")
    if echo "$RESULT" | jq -e '.exit_code == 0' > /dev/null; then
        echo "✓ Service bootstrapped successfully"
        return 0
    else
        echo "✗ Bootstrap failed"
        return 1
    fi
}
```

### Example 2: Deploy and Verify Fleet

```bash
deploy_and_verify() {
    local VERSION="$1"
    declare -a SERVERS=("us-east" "us-west" "eu-west")
    
    # Deploy to all
    for SERVER in "${SERVERS[@]}"; do
        echo "Deploying to $SERVER..."
        sane-run-command "tues:0.0" "ssh -C $SERVER 'cd /app && ./deploy.sh $VERSION'"
    done
    
    # Verify all
    local SUCCESS_COUNT=0
    for SERVER in "${SERVERS[@]}"; do
        RESULT=$(sane-run-command "tues:0.0" "ssh -C $SERVER 'curl -s localhost:8000/version'")
        VERSION_CHECK=$(echo "$RESULT" | jq -r '.output')
        
        if echo "$VERSION_CHECK" | grep -q "$VERSION"; then
            echo "✓ $SERVER running version $VERSION"
            ((SUCCESS_COUNT++))
        fi
    done
    
    if [[ $SUCCESS_COUNT -eq ${#SERVERS[@]} ]]; then
        echo "✅ All servers deployed and verified"
        return 0
    else
        echo "⚠️ Partial deployment: $SUCCESS_COUNT/${#SERVERS[@]} successful"
        return 1
    fi
}
```

## Anti-Patterns

### ❌ Anti-Pattern 1: Assuming Successful Execution

```bash
# WRONG: No verification
sane-create-file "$PANE" "/app/config.json" "$CONFIG"
sane-run-command "$PANE" "npm install"  # Assumes config was created

# RIGHT: Always verify
RESULT=$(sane-create-file "$PANE" "/app/config.json" "$CONFIG")
if echo "$RESULT" | jq -e '.status == "created"' > /dev/null; then
    sane-run-command "$PANE" "npm install"
fi
```

### ❌ Anti-Pattern 2: Silent Failures

```bash
# WRONG: Swallowing errors
sane-run-command "$PANE" "deploy.sh" > /dev/null 2>&1

# RIGHT: Capture and log errors
RESULT=$(sane-run-command "$PANE" "deploy.sh")
EXIT_CODE=$(echo "$RESULT" | jq -r '.exit_code')
if [[ "$EXIT_CODE" != "0" ]]; then
    echo "Deployment failed: $(echo "$RESULT" | jq -r '.output')"
    sane-log-operation "$PANE" "error" "deploy.sh" "exit_code=$EXIT_CODE"
fi
```

### ❌ Anti-Pattern 3: Hard-Coded Paths and Tools

```bash
# WRONG: Hard-coded grep path
CMD="grep -r 'pattern' /src"

# RIGHT: Use sane-get-tool for platform awareness
GREP_TOOL=$(sane-get-tool "grep" | jq -r '.path')
CMD="$GREP_TOOL -r 'pattern' /src"
sane-run-command "$PANE" "$CMD"
```

### ❌ Anti-Pattern 4: Mixing Primitives with Raw Keystrokes

```bash
# WRONG: Mixing approaches
sane-run-command "$PANE" "npm start"
tmux send-keys -t "$PANE" "C-c"  # Raw keystroke

# RIGHT: Stay consistent
sane-run-command "$PANE" "npm start"
sleep 2
sane-run-command "$PANE" "pkill -f 'npm start'"
```

### ❌ Anti-Pattern 5: Ignoring Platform Differences

```bash
# WRONG: macOS-specific syntax
sane-run-command "$PANE" "sed -i .bak 's/old/new/' file.txt"  # Fails on Linux

# RIGHT: Use platform-aware tools
PLATFORM=$(sane-detect-platform "$PANE" | jq -r '.platform')
if [[ "$PLATFORM" == "darwin" ]]; then
    sane-run-command "$PANE" "sed -i .bak 's/old/new/' file.txt"
else
    sane-run-command "$PANE" "sed -i 's/old/new/' file.txt"
fi
```

## Troubleshooting

### Problem: Commands Running in Wrong Pane

**Symptoms:** Command output appears in unexpected pane

**Solution:** Always target specific panes with `SESSION:WINDOW.PANE` format

```bash
# Verify correct pane
sane-list-panes "tues" | jq '.panes[] | select(.id == "0.0")'
```

### Problem: JSON Parsing Errors

**Symptoms:** jq errors, unexpected output

**Solution:** Check command output first, parse carefully

```bash
RESULT=$(sane-run-command "$PANE" "ls -la")
echo "$RESULT" | jq '.'  # Pretty-print to inspect structure
```

### Problem: File Creation Failures

**Symptoms:** "No such file or directory" errors

**Solution:** Create parent directories first

```bash
# Create parent first
sane-run-command "$PANE" "mkdir -p /app/config"

# Then create file
sane-create-file "$PANE" "/app/config/app.json" "$CONFIG"
```

### Problem: Timeouts on Slow Networks

**Symptoms:** Commands appear to hang

**Solution:** Consider network latency, SSH overhead

```bash
# For remote operations, allow more time
sane-run-command "$PANE" "ssh remote-host 'long-running-command'" | jq '.duration_ms'
```

## Summary

The key to reliable agent automation with tmux-sane is:

1. **Always use primitives** - Never raw keystrokes
2. **Validate early** - Catch errors before execution
3. **Parse carefully** - Use jq, not string matching
4. **Be specific** - Target exact panes, not ambiguous sessions
5. **Verify operations** - Check JSON status fields, not exit codes alone
6. **Log everything** - Use friction logging for debugging
7. **Handle errors gracefully** - Retry, fallback, report clearly
8. **Think in terms of state** - Use context database for long workflows

Following these patterns will lead to robust, maintainable agent automation that works reliably across different platforms and edge cases.
