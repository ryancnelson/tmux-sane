#!/usr/bin/env bash
# lib/retry-logic.sh - Retry helper functions with exponential backoff
# Usage: source lib/retry-logic.sh
# Functions:
#   with_retry "command" [max_attempts] [initial_delay_seconds]
#   retry_with_backoff "command" [max_attempts] [initial_delay_seconds]

set -euo pipefail

# Execute command with simple retry on non-zero exit code
# with_retry "command" [max_attempts] [initial_delay]
# Returns the command's exit code
with_retry() {
    local command="$1"
    local max_attempts="${2:-3}"
    local delay="${3:-1}"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        echo "[Attempt $attempt/$max_attempts] Running: $command" >&2
        
        if eval "$command"; then
            echo "[Success on attempt $attempt]" >&2
            return 0
        fi
        
        local exit_code=$?
        
        if [[ $attempt -lt $max_attempts ]]; then
            echo "[Failed with exit code $exit_code, retrying in ${delay}s...]" >&2
            sleep "$delay"
        else
            echo "[Failed after $max_attempts attempts]" >&2
            return "$exit_code"
        fi
        
        ((attempt++))
    done
    
    return 1
}

# Execute command with exponential backoff retry
# retry_with_backoff "command" [max_attempts] [initial_delay_seconds]
# Returns the command's exit code
# Delay doubles each time: 1s, 2s, 4s, 8s, etc.
retry_with_backoff() {
    local command="$1"
    local max_attempts="${2:-3}"
    local initial_delay="${3:-1}"
    local attempt=1
    local current_delay=$initial_delay
    
    while [[ $attempt -le $max_attempts ]]; do
        echo "[Attempt $attempt/$max_attempts] Running: $command" >&2
        
        if eval "$command"; then
            echo "[Success on attempt $attempt]" >&2
            return 0
        fi
        
        local exit_code=$?
        
        if [[ $attempt -lt $max_attempts ]]; then
            echo "[Failed with exit code $exit_code, retrying in ${current_delay}s (exponential backoff)...]" >&2
            sleep "$current_delay"
            # Double the delay for next attempt (exponential backoff)
            current_delay=$((current_delay * 2))
        else
            echo "[Failed after $max_attempts attempts]" >&2
            return "$exit_code"
        fi
        
        ((attempt++))
    done
    
    return 1
}

# Check if a command should be retried based on exit code
# is_retriable_error EXIT_CODE
# Returns 0 (true) if error is retriable, 1 (false) otherwise
is_retriable_error() {
    local exit_code="${1:-0}"
    
    # These exit codes are typically transient/retriable:
    # - Exit code 1: Generic error (might be transient)
    # - Exit code 124: timeout command timeout
    # - Exit code 255: SSH connection error (transient)
    # - Exit code 28: Operation timed out
    
    case "$exit_code" in
        124|255|28)
            return 0  # Retriable
            ;;
        *)
            return 1  # Not retriable
            ;;
    esac
}

# Smart retry - only retries on specific transient error codes
# smart_retry "command" [max_attempts] [initial_delay]
smart_retry() {
    local command="$1"
    local max_attempts="${2:-3}"
    local initial_delay="${3:-1}"
    local attempt=1
    local current_delay=$initial_delay
    
    while [[ $attempt -le $max_attempts ]]; do
        echo "[Attempt $attempt/$max_attempts] Running: $command" >&2
        
        if eval "$command"; then
            echo "[Success on attempt $attempt]" >&2
            return 0
        fi
        
        local exit_code=$?
        
        # Check if this error is retriable
        if ! is_retriable_error "$exit_code"; then
            echo "[Failed with non-retriable exit code $exit_code, not retrying]" >&2
            return "$exit_code"
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            echo "[Transient failure (exit code $exit_code), retrying in ${current_delay}s...]" >&2
            sleep "$current_delay"
            current_delay=$((current_delay * 2))
        else
            echo "[Failed after $max_attempts attempts]" >&2
            return "$exit_code"
        fi
        
        ((attempt++))
    done
    
    return 1
}
