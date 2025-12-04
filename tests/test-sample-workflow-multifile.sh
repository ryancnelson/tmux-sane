#!/usr/bin/env bash
# Test: Sample Agent Workflow - Multi-file Project Creation
# Demonstrates using sane-* primitives together to create a complete project structure
# with 5 files of different types (bash, JSON, markdown, python, yaml)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Scripts we're using
CREATE_FILE_SCRIPT="$PROJECT_DIR/sane-create-file"
RUN_COMMAND_SCRIPT="$PROJECT_DIR/sane-run-command"
SETUP_PROMPT_SCRIPT="$PROJECT_DIR/sane-setup-prompt"
LIST_PANES_SCRIPT="$PROJECT_DIR/sane-list-panes"
VALIDATE_BASH_SCRIPT="$PROJECT_DIR/sane-validate-bash"
VALIDATE_JSON_SCRIPT="$PROJECT_DIR/sane-validate-json"

# Test session and directory
TEST_SESSION="tues"
TEST_SUFFIX="$$-$RANDOM"
TEST_DIR="/tmp/sample-project-$TEST_SUFFIX"
BACKUP_DIR="$TEST_DIR/.backups"

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
    # Remove test directory if it exists
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

trap cleanup EXIT

echo "=== Sample Agent Workflow: Multi-file Project Creation ==="
echo "This test demonstrates a practical workflow for creating a complete"
echo "project structure using sane-* primitives."
echo ""

# Verify session exists
if ! tmux has-session -t "$TEST_SESSION" 2>/dev/null; then
    echo "Error: Test session '$TEST_SESSION' does not exist"
    echo "Please create it: tmux new-session -d -s $TEST_SESSION"
    echo "Results: 0/$TESTS_RUN tests passed"
    exit 1
fi

# Setup: Verify all required scripts exist
echo "Verifying required scripts..."
for script in "$CREATE_FILE_SCRIPT" "$RUN_COMMAND_SCRIPT" "$SETUP_PROMPT_SCRIPT" "$LIST_PANES_SCRIPT" "$VALIDATE_BASH_SCRIPT" "$VALIDATE_JSON_SCRIPT"; do
    if [[ ! -x "$script" ]]; then
        echo "Error: Required script not found: $script"
        exit 1
    fi
done
echo "✓ All scripts available"
echo ""

# Setup: Create test directory
echo "Setting up test environment..."
# First clean up if it exists
$RUN_COMMAND_SCRIPT "$TEST_SESSION:0.0" "rm -rf '$TEST_DIR'" > /dev/null 2>&1 || true
# Then create it and verify
OUTPUT=$($RUN_COMMAND_SCRIPT "$TEST_SESSION:0.0" "mkdir -p '$TEST_DIR' && cd '$TEST_DIR' && pwd")
if echo "$OUTPUT" | jq -r '.output // empty' | grep -q "$TEST_DIR"; then
    test_pass "Test directory created: $TEST_DIR"
else
    test_fail "Test directory created" "directory in pwd output" "$OUTPUT"
    echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
    exit 1
fi
echo ""

# WORKFLOW STEP 1: Create README.md (Markdown file)
echo "=== Workflow Step 1: Create README.md (Markdown) ==="
README_CONTENT='# Sample Project

A demonstration project created by sane-* primitives.

## Features

- Multi-file structure
- Different file types (bash, JSON, Python, YAML)
- Demonstrates agent workflow coordination

## Usage

```bash
./deploy.sh
./generate-config.py
```

## Project Structure

```
sample-project/
├── README.md            # This file
├── package.json         # Project metadata
├── deploy.sh            # Deployment script
├── generate-config.py   # Configuration generator
└── config-template.yaml # Configuration template
```
'

OUTPUT=$("$CREATE_FILE_SCRIPT" "$TEST_SESSION:0.0" "$TEST_DIR/README.md" "$README_CONTENT") || true
if echo "$OUTPUT" | jq -e '.status' > /dev/null 2>&1; then
    test_pass "README.md created successfully"
    # Extract checksum for verification
    README_CHECKSUM=$(echo "$OUTPUT" | jq -r '.checksum // empty')
    if [[ -n "$README_CHECKSUM" ]]; then
        test_pass "README.md checksum: $README_CHECKSUM"
    fi
else
    test_fail "README.md created" "JSON with status field" "$OUTPUT"
fi
echo ""

# WORKFLOW STEP 2: Create package.json (JSON file with validation)
echo "=== Workflow Step 2: Create package.json (JSON with validation) ==="
PACKAGE_JSON='{"name":"sample-project","version":"0.1.0","description":"Demonstration project","author":"AI Agent","scripts":{"deploy":"./deploy.sh","config":"python generate-config.py"},"dependencies":{"bash":"*","python":"3.8+"}}'

# Validate JSON before creating
VALIDATE_OUTPUT=$("$VALIDATE_JSON_SCRIPT" "$PACKAGE_JSON") || true
if echo "$VALIDATE_OUTPUT" | jq -e '.valid' > /dev/null 2>&1; then
    test_pass "package.json is valid JSON"
    
    # Create the file
    OUTPUT=$("$CREATE_FILE_SCRIPT" "$TEST_SESSION:0.0" "$TEST_DIR/package.json" "$PACKAGE_JSON") || true
    if echo "$OUTPUT" | jq -e '.status' > /dev/null 2>&1; then
        test_pass "package.json created successfully"
    else
        test_fail "package.json created" "JSON with status field" "$OUTPUT"
    fi
else
    test_fail "package.json validation" "JSON with valid field" "$VALIDATE_OUTPUT"
fi
echo ""

# WORKFLOW STEP 3: Create deploy.sh (Bash script with syntax validation)
echo "=== Workflow Step 3: Create deploy.sh (Bash script with validation) ==="
DEPLOY_SCRIPT='#!/usr/bin/env bash
# Deployment script for sample project

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Deploying project from: $PROJECT_DIR"
echo "Generating configuration..."
python "$PROJECT_DIR/generate-config.py"

if [[ -f "$PROJECT_DIR/config.yaml" ]]; then
    echo "Configuration generated successfully"
    echo "Deployment would proceed with config file"
else
    echo "Error: Configuration generation failed"
    exit 1
fi

echo "Deployment complete"
'

# Validate bash script before creating
VALIDATE_OUTPUT=$("$VALIDATE_BASH_SCRIPT" "$DEPLOY_SCRIPT") || true
if echo "$VALIDATE_OUTPUT" | jq -e '.valid' > /dev/null 2>&1; then
    test_pass "deploy.sh has valid bash syntax"
    
    # Create the file
    OUTPUT=$("$CREATE_FILE_SCRIPT" "$TEST_SESSION:0.0" "$TEST_DIR/deploy.sh" "$DEPLOY_SCRIPT") || true
    if echo "$OUTPUT" | jq -e '.status' > /dev/null 2>&1; then
        test_pass "deploy.sh created successfully"
    else
        test_fail "deploy.sh created" "JSON with status field" "$OUTPUT"
    fi
else
    test_fail "deploy.sh validation" "JSON with valid field" "$VALIDATE_OUTPUT"
fi
echo ""

# WORKFLOW STEP 4: Create generate-config.py (Python script)
echo "=== Workflow Step 4: Create generate-config.py (Python script) ==="
PYTHON_SCRIPT='#!/usr/bin/env python3
"""Configuration generator for sample project."""

import os
import yaml
from pathlib import Path

def main():
    project_dir = Path(__file__).parent
    config_file = project_dir / "config.yaml"
    
    config = {
        "project": "sample-project",
        "version": "0.1.0",
        "environment": {
            "debug": False,
            "log_level": "INFO"
        },
        "deployment": {
            "target": "localhost",
            "port": 8080
        }
    }
    
    with open(config_file, "w") as f:
        yaml.dump(config, f, default_flow_style=False)
    
    print(f"Configuration written to {config_file}")

if __name__ == "__main__":
    main()
'

OUTPUT=$("$CREATE_FILE_SCRIPT" "$TEST_SESSION:0.0" "$TEST_DIR/generate-config.py" "$PYTHON_SCRIPT") || true
if echo "$OUTPUT" | jq -e '.status' > /dev/null 2>&1; then
    test_pass "generate-config.py created successfully"
else
    test_fail "generate-config.py created" "JSON with status field" "$OUTPUT"
fi
echo ""

# WORKFLOW STEP 5: Create config-template.yaml (YAML configuration template)
echo "=== Workflow Step 5: Create config-template.yaml (YAML template) ==="
YAML_CONFIG='# Configuration template for sample project
project:
  name: sample-project
  version: 0.1.0
  description: Demonstration project

environment:
  debug: false
  log_level: INFO
  
deployment:
  target: localhost
  port: 8080
  region: us-east-1
  
features:
  - multi-file-structure
  - json-validation
  - bash-validation
  - yaml-configuration
'

OUTPUT=$("$CREATE_FILE_SCRIPT" "$TEST_SESSION:0.0" "$TEST_DIR/config-template.yaml" "$YAML_CONFIG") || true
if echo "$OUTPUT" | jq -e '.status' > /dev/null 2>&1; then
    test_pass "config-template.yaml created successfully"
else
    test_fail "config-template.yaml created" "JSON with status field" "$OUTPUT"
fi
echo ""

# VERIFICATION STEP: Verify all files were created
echo "=== Verification: Check Project Structure ==="
VERIFY_CMD="ls -la '$TEST_DIR'"
OUTPUT=$("$RUN_COMMAND_SCRIPT" "$TEST_SESSION:0.0" "$VERIFY_CMD") || true
OUTPUT_TEXT=$(echo "$OUTPUT" | jq -r '.output // empty')

EXPECTED_FILES=("README.md" "package.json" "deploy.sh" "generate-config.py" "config-template.yaml")
for file in "${EXPECTED_FILES[@]}"; do
    if echo "$OUTPUT_TEXT" | grep -q "$file"; then
        test_pass "File $file exists in project directory"
    else
        test_fail "File $file exists" "filename in ls output" "$OUTPUT_TEXT"
    fi
done
echo ""

# VERIFICATION STEP: Check file counts and sizes
echo "=== Verification: File Statistics ==="
COUNT_CMD="find '$TEST_DIR' -maxdepth 1 -type f | wc -l"
OUTPUT=$("$RUN_COMMAND_SCRIPT" "$TEST_SESSION:0.0" "$COUNT_CMD") || true
OUTPUT_TEXT=$(echo "$OUTPUT" | jq -r '.output // empty')
FILE_COUNT=$(echo "$OUTPUT_TEXT" | tr -d '\n')
if [[ "$FILE_COUNT" == "5" ]]; then
    test_pass "Exactly 5 files created"
else
    test_fail "Exactly 5 files created" "5 files" "$FILE_COUNT files"
fi

SIZE_CMD="du -sh '$TEST_DIR' | cut -f1"
OUTPUT=$("$RUN_COMMAND_SCRIPT" "$TEST_SESSION:0.0" "$SIZE_CMD") || true
OUTPUT_TEXT=$(echo "$OUTPUT" | jq -r '.output // empty')
if echo "$OUTPUT_TEXT" | grep -qE '[0-9]+(K|M|G)'; then
    test_pass "Project directory has measurable size"
fi
echo ""

# WORKFLOW SUMMARY
echo "=== Workflow Summary ==="
echo "This test demonstrated using sane-* primitives together to:"
echo "  1. Create a README.md with structured documentation"
echo "  2. Create package.json with JSON validation"
echo "  3. Create deploy.sh with bash syntax validation"
echo "  4. Create generate-config.py with Python code"
echo "  5. Create config-template.yaml with YAML structure"
echo ""
echo "Key Agent Workflow Lessons:"
echo "  - Validate content before creation (JSON, bash syntax)"
echo "  - Coordinate multiple file creations in sequence"
echo "  - Track success via structured JSON responses"
echo "  - Use sane-run-command for verification steps"
echo "  - Build complete projects with different file types"
echo ""

# Results
echo "Results: $TESTS_PASSED/$TESTS_RUN tests passed"
if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    exit 0
else
    exit 1
fi
