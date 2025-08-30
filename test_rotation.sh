#!/bin/bash

echo "=== Testing RPiPlay Rotation ==="

# Compile first
echo "Compiling RPiPlay..."
make clean && make

if [ ! -f "./rpiplay" ]; then
    echo "ERROR: rpiplay binary not found after compilation"
    exit 1
fi

echo "Starting RPiPlay with GStreamer renderer..."
echo "Look for debug messages about rotation..."
echo "Press Ctrl+C to stop"
echo ""

# Force GStreamer renderer and show debug output
./rpiplay -vr gstreamer -d

echo ""
echo "=== Test completed ==="
