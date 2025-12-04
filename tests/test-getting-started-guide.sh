#!/usr/bin/env bash
# Test: Getting Started Guide for tmux-sane
# Validates that the Getting Started Guide documentation exists, is well-structured,
# and includes all required sections with practical examples and troubleshooting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test files
GUIDE_FILE="$PROJECT_DIR/GETTING-STARTED.md"

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

# Test 1: Getting Started Guide file exists
if [[ -f "$GUIDE_FILE" ]]; then
    test_pass "Getting Started Guide file exists"
else
    test_fail "Getting Started Guide file exists" "File exists" "File does not exist at $GUIDE_FILE"
fi

# Test 2: File is readable and not empty
if [[ -f "$GUIDE_FILE" ]] && [[ -s "$GUIDE_FILE" ]]; then
    test_pass "Getting Started Guide is readable and not empty"
else
    test_fail "Getting Started Guide is readable and not empty" "File is readable" "File is empty or not readable"
fi

# Test 3: Contains introduction section
if [[ -f "$GUIDE_FILE" ]] && grep -q -i "introduction\|welcome\|what is" "$GUIDE_FILE"; then
    test_pass "Contains introduction/welcome section"
else
    test_fail "Contains introduction/welcome section" "Intro section found" "No intro section found"
fi

# Test 4: Contains prerequisites section
if [[ -f "$GUIDE_FILE" ]] && grep -q -i "prerequisite\|requirement\|before you start" "$GUIDE_FILE"; then
    test_pass "Contains prerequisites section"
else
    test_fail "Contains prerequisites section" "Prerequisites section found" "No prerequisites section found"
fi

# Test 5: Contains installation/setup section
if [[ -f "$GUIDE_FILE" ]] && grep -q -i "install\|setup\|getting set up\|how to get started" "$GUIDE_FILE"; then
    test_pass "Contains installation/setup section"
else
    test_fail "Contains installation/setup section" "Setup section found" "No setup section found"
fi

# Test 6: Contains first example
if [[ -f "$GUIDE_FILE" ]] && grep -q -i "example 1\|first example\|simple.*example" "$GUIDE_FILE"; then
    test_pass "Contains first practical example"
else
    test_fail "Contains first practical example" "Example 1 found" "No first example found"
fi

# Test 7: Contains second example
if [[ -f "$GUIDE_FILE" ]] && grep -q -i "example 2\|second example" "$GUIDE_FILE"; then
    test_pass "Contains second practical example"
else
    test_fail "Contains second practical example" "Example 2 found" "No second example found"
fi

# Test 8: Contains third example
if [[ -f "$GUIDE_FILE" ]] && grep -q -i "example 3\|third example" "$GUIDE_FILE"; then
    test_pass "Contains third practical example"
else
    test_fail "Contains third practical example" "Example 3 found" "No third example found"
fi

# Test 9: Contains troubleshooting section
if [[ -f "$GUIDE_FILE" ]] && grep -q -i "troubleshoot\|problem\|error\|issue\|help" "$GUIDE_FILE"; then
    test_pass "Contains troubleshooting section"
else
    test_fail "Contains troubleshooting section" "Troubleshooting section found" "No troubleshooting section found"
fi

# Test 10: Contains common commands reference
if [[ -f "$GUIDE_FILE" ]] && grep -q "sane-run-command\|sane-create-file\|sane-list-panes" "$GUIDE_FILE"; then
    test_pass "Contains references to common sane-* commands"
else
    test_fail "Contains references to common sane-* commands" "Command references found" "No command references found"
fi

# Test 11: Contains information about structured prompts
if [[ -f "$GUIDE_FILE" ]] && grep -q -i "prompt\|PS1\|pane\|session" "$GUIDE_FILE"; then
    test_pass "Contains information about tmux-sane concepts"
else
    test_fail "Contains information about tmux-sane concepts" "Concepts explained" "No concepts explained"
fi

# Test 12: Contains links to other documentation
if [[ -f "$GUIDE_FILE" ]] && grep -q -E "\[.+\]\(.*\.md\)|\[.*\]:" "$GUIDE_FILE"; then
    test_pass "Contains links to other documentation"
else
    test_fail "Contains links to other documentation" "Links found" "No documentation links found"
fi

# Test 13: Contains code blocks or examples
if [[ -f "$GUIDE_FILE" ]] && grep -q '```' "$GUIDE_FILE"; then
    test_pass "Contains code examples with proper formatting"
else
    test_fail "Contains code examples with proper formatting" "Code blocks found" "No code blocks found"
fi

# Test 14: Contains next steps section
if [[ -f "$GUIDE_FILE" ]] && grep -q -i "next\|further\|advanced\|learn more\|what's next" "$GUIDE_FILE"; then
    test_pass "Contains next steps/further learning section"
else
    test_fail "Contains next steps/further learning section" "Next steps section found" "No next steps section found"
fi

# Test 15: File is valid markdown (basic check)
if [[ -f "$GUIDE_FILE" ]] && grep -q "^#" "$GUIDE_FILE"; then
    test_pass "File uses proper markdown heading syntax"
else
    test_fail "File uses proper markdown heading syntax" "Markdown headings found" "No markdown headings found"
fi

# Print summary
echo ""
echo "========================================"
echo "Getting Started Guide Test Results"
echo "========================================"
echo "Tests passed: $TESTS_PASSED/$TESTS_RUN"
echo ""

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
