#!/usr/bin/env bash
# lib/ask-helpers.sh - Helper functions for AI-powered validation via ask-* scripts
#
# This library provides wrapper functions around ask-nova-lite and ask-claude-haiku
# for cheap, fast validation of bash syntax, jq queries, and other content.
#
# Design Principle:
# - ask-nova-lite: First choice for simple validation (cheapest, ~$0.00006 per call)
# - ask-claude-haiku: Fallback for complex syntax questions
# - Never call ask-* for every validation - use local tools first, then ask-* as fallback
#
# Environment:
# - Requires ask-nova-lite and ask-claude-haiku in PATH (from ~/bin/)
# - Gracefully degrades if ask-* scripts not available

set -euo pipefail

# Validate that ask-* scripts are available
check_ask_helpers_available() {
    local nova_lite_found=0
    local haiku_found=0
    
    if command -v ask-nova-lite &>/dev/null; then
        nova_lite_found=1
    fi
    
    if command -v ask-claude-haiku &>/dev/null; then
        haiku_found=1
    fi
    
    if [[ $nova_lite_found -eq 0 && $haiku_found -eq 0 ]]; then
        return 1  # No ask-* scripts available
    fi
    
    return 0  # At least one ask-* script available
}

# Ask a yes/no question using Nova Lite (super cheap)
# Usage: ask_nova_lite_yn "Does grep have -P flag on Linux?"
# Returns: 0 for YES, 1 for NO, 2 for error
ask_nova_lite_yn() {
    local question="${1:-}"
    
    if [[ -z "$question" ]]; then
        echo "Error: ask_nova_lite_yn requires a question" >&2
        return 2
    fi
    
    if ! command -v ask-nova-lite &>/dev/null; then
        echo "Error: ask-nova-lite not found in PATH" >&2
        return 2
    fi
    
    # Ask the question with explicit YES/NO instruction
    local response
    response=$(ask-nova-lite "Answer with only YES or NO. $question" 2>/dev/null) || {
        echo "Error: ask-nova-lite call failed" >&2
        return 2
    }
    
    # Parse response (case-insensitive)
    response_upper=$(echo "$response" | tr '[:lower:]' '[:upper:]')
    if [[ "$response_upper" =~ ^YES ]]; then
        return 0
    elif [[ "$response_upper" =~ ^NO ]]; then
        return 1
    else
        # Ambiguous response
        echo "Error: ambiguous response from ask-nova-lite: $response" >&2
        return 2
    fi
}

# Ask a yes/no question using Claude Haiku (cheap, smarter)
# Usage: ask_haiku_yn "Is this valid jq syntax: .data[] | select(.status == \"active\")"
# Returns: 0 for YES, 1 for NO, 2 for error
ask_haiku_yn() {
    local question="${1:-}"
    
    if [[ -z "$question" ]]; then
        echo "Error: ask_haiku_yn requires a question" >&2
        return 2
    fi
    
    if ! command -v ask-claude-haiku &>/dev/null; then
        echo "Error: ask-claude-haiku not found in PATH" >&2
        return 2
    fi
    
    # Ask the question with explicit YES/NO instruction
    local response
    response=$(ask-claude-haiku "Answer with only YES or NO. $question" 2>/dev/null) || {
        echo "Error: ask-claude-haiku call failed" >&2
        return 2
    }
    
    # Parse response (case-insensitive)
    response_upper=$(echo "$response" | tr '[:lower:]' '[:upper:]')
    if [[ "$response_upper" =~ ^YES ]]; then
        return 0
    elif [[ "$response_upper" =~ ^NO ]]; then
        return 1
    else
        # Ambiguous response
        echo "Error: ambiguous response from ask-claude-haiku: $response" >&2
        return 2
    fi
}

# Validate bash syntax using AI (with local fallback)
# This is a fallback to sane-validate-bash - only use if local validation fails
# Usage: validate_bash_with_ai "echo hello"
# Returns: JSON {valid: true/false, method: "local"|"ai", error: "..."}
validate_bash_with_ai() {
    local bash_code="${1:-}"
    
    if [[ -z "$bash_code" ]]; then
        echo '{"valid":false,"method":"none","error":"No bash code provided"}'
        return 0
    fi
    
    # First, try local validation (fastest, cheapest)
    local tmpfile
    tmpfile=$(mktemp)
    trap "rm -f '$tmpfile'" RETURN
    
    echo "$bash_code" > "$tmpfile"
    
    if bash -n "$tmpfile" 2>/dev/null; then
        # Local validation passed
        echo '{"valid":true,"method":"local"}'
        return 0
    fi
    
    # Local validation failed - try ask-nova-lite as fallback
    if ! command -v ask-nova-lite &>/dev/null; then
        echo '{"valid":false,"method":"none","error":"Bash syntax invalid (ask-nova-lite not available)"}'
        return 0
    fi
    
    # Ask Nova Lite if the bash is valid
    local escaped_code
    escaped_code=$(printf '%s' "$bash_code" | sed 's/"/\\"/g')
    
    if ask_nova_lite_yn "Is this valid bash syntax: $escaped_code" 2>/dev/null; then
        echo '{"valid":true,"method":"ai"}'
    else
        echo '{"valid":false,"method":"ai","error":"Bash syntax invalid (verified with ask-nova-lite)"}'
    fi
    
    return 0
}

# Validate jq syntax using AI (with local fallback)
# This is a fallback to sane-validate-json - only use if local validation fails
# Usage: validate_jq_with_ai ".data[] | select(.status == \"active\") | .name"
# Returns: JSON {valid: true/false, method: "local"|"ai", error: "..."}
validate_jq_with_ai() {
    local jq_query="${1:-}"
    
    if [[ -z "$jq_query" ]]; then
        echo '{"valid":false,"method":"none","error":"No jq query provided"}'
        return 0
    fi
    
    # First, try local validation with a simple JSON test
    local test_json='{"data": [{"status": "active", "name": "test"}]}'
    
    if echo "$test_json" | jq "$jq_query" >/dev/null 2>&1; then
        echo '{"valid":true,"method":"local"}'
        return 0
    fi
    
    # Local validation failed - try ask-claude-haiku as fallback
    if ! command -v ask-claude-haiku &>/dev/null; then
        echo '{"valid":false,"method":"none","error":"jq query invalid (ask-claude-haiku not available)"}'
        return 0
    fi
    
    # Ask Claude Haiku if the jq is valid
    if ask_haiku_yn "Is this a valid jq query: $jq_query" 2>/dev/null; then
        echo '{"valid":true,"method":"ai"}'
    else
        echo '{"valid":false,"method":"ai","error":"jq query invalid (verified with ask-claude-haiku)"}'
    fi
    
    return 0
}

# Check if a tool supports a specific flag using AI
# Usage: tool_supports_flag "grep" "-P" "Linux"
# Returns: 0 for YES, 1 for NO, 2 for error
tool_supports_flag() {
    local tool="${1:-}"
    local flag="${2:-}"
    local platform="${3:-}"
    
    if [[ -z "$tool" || -z "$flag" ]]; then
        echo "Error: tool_supports_flag requires tool and flag arguments" >&2
        return 2
    fi
    
    if ! command -v ask-nova-lite &>/dev/null; then
        echo "Error: ask-nova-lite not found in PATH" >&2
        return 2
    fi
    
    local question
    if [[ -n "$platform" ]]; then
        question="Does $tool on $platform support the $flag flag?"
    else
        question="Does $tool support the $flag flag?"
    fi
    
    ask_nova_lite_yn "$question"
}

# Export public functions
export -f check_ask_helpers_available
export -f ask_nova_lite_yn
export -f ask_haiku_yn
export -f validate_bash_with_ai
export -f validate_jq_with_ai
export -f tool_supports_flag
