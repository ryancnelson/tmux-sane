#!/usr/bin/env bash
# platform-detect.sh - Detect platform information and return as JSON
# Returns: {os, arch, hostname, user, distro (Linux only)}

set -euo pipefail

# Detect OS
OS=$(uname -s)

# Detect architecture
ARCH=$(uname -m)

# Detect hostname (short form)
HOSTNAME=$(hostname -s 2>/dev/null || hostname | cut -d. -f1)

# Detect user
USER_NAME="${USER:-$(whoami)}"

# Build base JSON
JSON="{\"os\":\"$OS\",\"arch\":\"$ARCH\",\"hostname\":\"$HOSTNAME\",\"user\":\"$USER_NAME\""

# Add distro info for Linux
if [[ "$OS" == "Linux" ]]; then
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        DISTRO="${ID:-unknown}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
        JSON="$JSON,\"distro\":\"$DISTRO\",\"distro_version\":\"$DISTRO_VERSION\""
    fi
fi

# Close JSON
JSON="$JSON}"

# Output JSON
echo "$JSON"
