#!/bin/bash
# OpenCode Installation Script

set -euo pipefail

echo "Installing OpenCode..."

# Install OpenCode via npm
npm install -g opencode-ai

# Verify installation
if ! command -v opencode >/dev/null 2>&1; then
    echo "ERROR: OpenCode installation failed - binary not found"
    exit 1
fi

# Print version
echo "OpenCode installed successfully:"
opencode --version
