#!/bin/bash
set -e

export NVM_DIR="/home/claude/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
fi

if [ -f "$NVM_DIR/alias/default" ]; then
    nvm use default >/dev/null 2>&1 || true
fi

exec "$NVM_DIR/versions/node/$(nvm version)/bin/claude" "$@"
