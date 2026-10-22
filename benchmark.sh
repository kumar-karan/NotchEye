#!/bin/bash
# Benchmark NotchEye's resource usage
set -euo pipefail

APP_NAME="NotchEye"
APP_BUNDLE="$(dirname "$0")/$APP_NAME.app"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ $APP_BUNDLE not found. Run ./build.sh first."
    exit 1
fi

echo "📊 NotchEye Resource Benchmark"
echo "================================"
echo ""

# Binary size
BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
BINARY_SIZE=$(stat -f%z "$BINARY")
echo "Binary size: $(echo "scale=2; $BINARY_SIZE / 1048576" | bc) MB ($BINARY_SIZE bytes)"

# Start the app
echo ""
echo "Starting $APP_NAME..."
open "$APP_BUNDLE"
sleep 3

# Find PID
PID=$(pgrep -x "$APP_NAME" 2>/dev/null || true)
if [ -z "$PID" ]; then
    echo "❌ Could not find $APP_NAME process"
    exit 1
fi

echo "PID: $PID"
echo ""

# Memory (RSS and Virtual)
echo "--- Memory ---"
ps -p "$PID" -o pid,rss,vsz,command | head -2
RSS=$(ps -p "$PID" -o rss= | tr -d ' ')
echo "Resident Memory (RSS): $(echo "scale=2; $RSS / 1024" | bc) MB"
echo ""

# CPU (sample over 5 seconds)
echo "--- CPU (idle, 5s sample) ---"
top -pid "$PID" -l 3 -stats pid,cpu,mem,vsize -n 0 2>/dev/null | tail -1

echo ""
echo "--- Thread Count ---"
THREADS=$(ps -M -p "$PID" | wc -l)
echo "Threads: $((THREADS - 1))"

echo ""
echo "--- Open Files ---"
OPEN_FILES=$(lsof -p "$PID" 2>/dev/null | wc -l)
echo "Open file descriptors: $OPEN_FILES"

echo ""
echo "✅ Benchmark complete. Kill with: kill $PID"
