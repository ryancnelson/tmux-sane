#!/bin/bash
#
# next-iteration.sh - Automate the start of a new iteration
#
# This script handles the mechanical parts of starting a new iteration:
# - Increments iteration count
# - Creates a git branch
# - Shows the backlog for task selection
# - Prepares the working environment
#
# Usage:
#   ./scripts/next-iteration.sh                    # Interactive mode
#   ./scripts/next-iteration.sh "add-feature-x"    # With branch name
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get project root (script is in scripts/ subdirectory)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}=== SignOz Query Tool - New Iteration Setup ===${NC}\n"

# 1. Check if we're in a clean git state
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}Warning: You have uncommitted changes.${NC}"
    echo "Please commit or stash them before starting a new iteration."
    echo ""
    git status --short
    exit 1
fi

# 2. Read and increment iteration count
if [ ! -f ".iteration-count" ]; then
    echo "Error: .iteration-count file not found"
    exit 1
fi

CURRENT_ITERATION=$(cat .iteration-count)
NEXT_ITERATION=$((CURRENT_ITERATION + 1))

echo -e "${GREEN}Current iteration:${NC} $CURRENT_ITERATION"
echo -e "${GREEN}Next iteration:${NC} $NEXT_ITERATION"
echo ""

# 3. Check if strategic review is due (every 8 iterations)
NEXT_REVIEW=$((((CURRENT_ITERATION / 8) + 1) * 8))
if [ $NEXT_ITERATION -eq $NEXT_REVIEW ]; then
    echo -e "${YELLOW}⚠️  STRATEGIC REVIEW DUE at iteration $NEXT_ITERATION${NC}"
    echo "See STRATEGIC-REVIEW-CHECKLIST.md for review process"
    echo ""
fi

# 4. Show backlog priorities
echo -e "${BLUE}=== Priority 1 Items from BACKLOG.md ===${NC}\n"
if [ -f "BACKLOG.md" ]; then
    # Extract Priority 1 section (everything between "## Priority 1" and next "##")
    sed -n '/## Priority 1:/,/## Priority 2:/p' BACKLOG.md | head -n -1 | grep '^\- \[ \]' | head -5
    echo ""
    echo -e "${BLUE}See BACKLOG.md for full list and details${NC}"
else
    echo "Warning: BACKLOG.md not found"
fi
echo ""

# 5. Get feature name for branch
if [ $# -eq 0 ]; then
    echo -e "${BLUE}What feature/improvement are you working on?${NC}"
    echo "(This will be used for the git branch name)"
    echo "Example: add-query-wizard, fix-timeout-handling, docs-troubleshooting"
    echo ""
    read -p "Feature name: " FEATURE_NAME
else
    FEATURE_NAME="$1"
fi

# Sanitize branch name (lowercase, replace spaces/special chars with dash)
BRANCH_NAME="iteration-${NEXT_ITERATION}-${FEATURE_NAME}"
BRANCH_NAME=$(echo "$BRANCH_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g')

echo ""
echo -e "${BLUE}=== Creating iteration setup ===${NC}"

# 6. Create git branch
echo -e "Creating branch: ${GREEN}$BRANCH_NAME${NC}"
git checkout -b "$BRANCH_NAME" 2>/dev/null || {
    echo "Branch already exists or error creating it"
    exit 1
}

# 7. Increment iteration count
echo "$NEXT_ITERATION" > .iteration-count
git add .iteration-count
echo -e "Incremented iteration count to ${GREEN}$NEXT_ITERATION${NC}"

# 8. Show next steps
echo ""
echo -e "${GREEN}✓ Setup complete!${NC}\n"
echo -e "${BLUE}=== Next Steps ===${NC}"
echo "1. Read the task description from BACKLOG.md"
echo "2. Activate environment: source test_env/bin/activate"
echo "3. Run tests to confirm baseline: python -m pytest lib/test_signozctl.py -v"
echo "4. Implement the feature/improvement"
echo "5. Run tests again to verify: python -m pytest lib/test_signozctl.py -v"
echo "6. Commit your changes: git commit -m 'feat: description'"
echo "7. Merge to main: git checkout main && git merge $BRANCH_NAME"
echo ""
echo -e "${BLUE}Branch:${NC} $BRANCH_NAME"
echo -e "${BLUE}Iteration:${NC} $NEXT_ITERATION"
echo ""

# 9. Optional: Show testing commands reminder
echo -e "${YELLOW}Reminder - Testing commands:${NC}"
echo "  python -m pytest lib/test_signozctl.py -v           # Run all tests"
echo "  python lib/cli.py --help                             # Test CLI"
echo "  python lib/cli.py list-metrics | head -10           # Quick smoke test"
echo ""

# 10. Optional: Check if test environment exists
if [ ! -d "test_env" ]; then
    echo -e "${YELLOW}Note: test_env not found. You may need to create it:${NC}"
    echo "  python3 -m venv test_env"
    echo "  source test_env/bin/activate"
    echo "  pip install -r requirements.txt"
    echo ""
fi

# 11. Optional: Open key files in editor
echo -e "${BLUE}Ready to start iteration $NEXT_ITERATION!${NC}"
