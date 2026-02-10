#!/bin/bash
set -e

echo "Starting tinyproxy..."

tinyproxy -c /home/tinyproxy/tinyproxy.conf -d &
TINYPROXY_PID=$!

echo "Tinyproxy started with PID $TINYPROXY_PID"
echo "Monitoring allowlist for changes..."

while true; do
    inotifywait -e modify,create,delete /home/tinyproxy/allowlist.txt 2>/dev/null
    echo "$(date -Iseconds) Allowlist changed, reloading tinyproxy..."
    kill -USR1 $TINYPROXY_PID || {
        echo "Tinyproxy process died, exiting"
        exit 1
    }
    echo "$(date -Iseconds) Tinyproxy reloaded"
done &
INOTIFYPID=$!

shutdown() {
    echo "Received shutdown signal, stopping tinyproxy..."
    kill $TINYPROXY_PID 2>/dev/null || true
    kill $INOTIFY_PID 2>/dev/null || true
    exit 0
}

trap shutdown SIGTERM SIGINT

wait $TINYPROXY_PID
