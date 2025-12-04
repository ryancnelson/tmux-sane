# Sample Agent Workflow: Multi-file Project Creation

## Overview

This workflow demonstrates how AI agents can use tmux-sane primitives to create a complete project structure with multiple files of different types (Markdown, JSON, Bash, Python, YAML).

The workflow is practical, composable, and shows patterns that agents can repeat for more complex scenarios.

## Workflow Steps

### Step 1: Create Directory Structure

```bash
sane-run-command SESSION:PANE "mkdir -p /path/to/project && cd /path/to/project && pwd"
```

**Key Points:**
- Always verify directory creation before creating files
- Use `pwd` to confirm you're in the correct location
- Parse JSON output from sane-run-command

### Step 2: Validate Content Before Creation (Optional but Recommended)

For JSON content, validate before creating:
```bash
sane-validate-json '{"key": "value"}'
# Returns: {"valid": true/false, "error": "..."}
```

For Bash scripts, validate syntax:
```bash
sane-validate-bash '#!/bin/bash\necho "test"'
# Returns: {"valid": true/false, "error": "..."}
```

### Step 3: Create Files with Content

```bash
sane-create-file SESSION:PANE "/path/to/file.json" '{"key": "value"}'
# Returns: {"status": "created", "path": "...", "checksum": "...", "size_bytes": N}
```

**Key Points:**
- Content is automatically escaped for special characters
- Files with special chars are base64-encoded internally
- Always check the JSON response for success
- Checksums can be used for verification

### Step 4: Verify Files Created

```bash
sane-run-command SESSION:PANE "ls -la /path/to/project"
# Parse JSON output to verify files exist
```

## Complete Example Workflow

```bash
#!/usr/bin/env bash
# Example: Create a complete Node.js project structure

PROJECT_DIR="/tmp/my-project"
SESSION="tues"
PANE="$SESSION:0.0"

# Step 1: Create directory
sane-run-command "$PANE" "mkdir -p '$PROJECT_DIR' && cd '$PROJECT_DIR' && pwd"

# Step 2: Create package.json (with validation)
PACKAGE_JSON='{"name":"my-project","version":"1.0.0","description":"Test"}'
sane-validate-json "$PACKAGE_JSON"
sane-create-file "$PANE" "$PROJECT_DIR/package.json" "$PACKAGE_JSON"

# Step 3: Create README.md
README='# My Project

## Usage

```bash
npm install
npm start
```'
sane-create-file "$PANE" "$PROJECT_DIR/README.md" "$README"

# Step 4: Create startup script
SCRIPT='#!/bin/bash
echo "Starting project..."
cd "$(dirname "$0")"
npm start'
sane-validate-bash "$SCRIPT"
sane-create-file "$PANE" "$PROJECT_DIR/start.sh" "$SCRIPT"

# Step 5: Verify
sane-run-command "$PANE" "ls -la '$PROJECT_DIR'"
sane-run-command "$PANE" "find '$PROJECT_DIR' -type f"
```

## Key Agent Patterns

### Pattern 1: Sequential File Creation

Create files one at a time. Parse JSON responses to ensure each succeeds before moving to the next.

```bash
for file in file1.txt file2.txt file3.txt; do
    OUTPUT=$(sane-create-file "$PANE" "/path/$file" "content")
    if echo "$OUTPUT" | jq -e '.status == "created"' > /dev/null; then
        echo "✓ Created $file"
    else
        echo "✗ Failed to create $file"
        exit 1
    fi
done
```

### Pattern 2: Content Validation Before Creation

Always validate JSON and Bash content before creating files. This catches errors early.

```bash
# Bad: Create without validation
sane-create-file "$PANE" "/app/config.json" "$POTENTIALLY_INVALID_JSON"

# Good: Validate first
if sane-validate-json "$JSON_CONTENT" | jq -e '.valid' > /dev/null; then
    sane-create-file "$PANE" "/app/config.json" "$JSON_CONTENT"
fi
```

### Pattern 3: Checksum-Based Verification

Use returned checksums to verify file integrity.

```bash
# Create file and capture checksum
RESULT=$(sane-create-file "$PANE" "/app/config.yaml" "$YAML_CONTENT")
CHECKSUM=$(echo "$RESULT" | jq -r '.checksum')

# Later, verify file hasn't changed
VERIFY_OUTPUT=$(sane-run-command "$PANE" "md5sum /app/config.yaml")
CURRENT_CHECKSUM=$(echo "$VERIFY_OUTPUT" | jq -r '.output' | awk '{print $1}')

if [[ "$CHECKSUM" == "$CURRENT_CHECKSUM" ]]; then
    echo "✓ File integrity verified"
fi
```

### Pattern 4: Directory Structure with Progress Tracking

Build complex structures with progress output.

```bash
DIRS=("config" "src" "src/components" "tests" "docs")

for dir in "${DIRS[@]}"; do
    OUTPUT=$(sane-run-command "$PANE" "mkdir -p '$PROJECT_DIR/$dir'")
    if echo "$OUTPUT" | jq -e '.exit_code == 0' > /dev/null; then
        echo "✓ Created directory: $dir"
    fi
done
```

## Real-World Use Cases

### Use Case 1: Bootstrap a New Microservice

Create service structure with:
- README with setup instructions
- package.json with dependencies
- docker-compose.yml for local development
- .env.example for configuration
- src/index.js with starter code

### Use Case 2: Create Test Fixtures

Generate consistent test data files:
- test-data.json with sample records
- fixtures.sql with database initialization
- mock-responses.yaml for API mocks
- seed.sh for populating test environment

### Use Case 3: Deploy Configuration

Create deployment-specific files:
- terraform/main.tf with infrastructure
- kubernetes/deployment.yaml for orchestration
- .github/workflows/deploy.yml for CI/CD
- ansible/playbook.yml for configuration management

## Best Practices

1. **Always validate JSON and Bash content** before creating files
2. **Create parent directories first** - files need their parent to exist
3. **Check JSON responses** - never assume success, verify the `status` field
4. **Use checksums** for important configuration files
5. **Add delays** if creating many files rapidly (tmux needs time to process)
6. **Verify after creation** - especially for critical files

## Error Handling

Common errors and solutions:

### Error: "No such file or directory"
**Cause:** Parent directory doesn't exist
**Solution:** Create directory first with `sane-run-command` before creating files

### Error: jq parsing error
**Cause:** Command output is not valid JSON
**Solution:** Check stderr - errors are reported before JSON. See command error output.

### Error: "File exists"
**Cause:** Not a real error if `status: "created"` - it means file was created/updated
**Solution:** Check the `status` field, not exit_code

## Testing the Workflow

Run the comprehensive test suite:

```bash
./tests/test-sample-workflow-multifile.sh
```

Expected output:
- All 16 tests pass
- Demonstrates all workflow steps
- Shows proper use of each sane-* primitive
- Verifies files were created correctly

## Integration with Agents

For AI agents using this workflow:

1. **Plan the project structure first** - know what files you need
2. **Prepare content separately** - don't generate content during execution
3. **Validate incrementally** - catch errors early
4. **Parse JSON carefully** - always use `jq` for reliable parsing
5. **Add error recovery** - check each step before proceeding

## Next Steps

- Advanced workflow: **Deploy to Multiple Servers** (Iteration 18)
  - Use multiple panes for parallel operations
  - Coordinate across SSH sessions
  - Deploy app + database + services
  - Verify health checks

