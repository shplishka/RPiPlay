#!/bin/bash

echo "=== Testing RPiPlay Rotation ==="

# Test 1: Check if GStreamer is available
echo "1. Checking GStreamer installation..."
if command -v gst-launch-1.0 &> /dev/null; then
    echo "   ✓ GStreamer found"
    
    # Test if rotate element works (like your working test)
    echo "2. Testing rotate element..."
    if gst-inspect-1.0 rotate &> /dev/null; then
        echo "   ✓ rotate element available"
        
        # Test the actual rotation command that worked for you
        echo "3. Testing rotation with videotestsrc..."
        timeout 3 gst-launch-1.0 -q videotestsrc num-buffers=10 ! rotate angle=1.5708 ! videoconvert ! fakesink &> /dev/null
        if [ $? -eq 0 ]; then
            echo "   ✓ rotate element works correctly"
        else
            echo "   ✗ rotate element has issues"
        fi
    else
        echo "   ✗ rotate element NOT available - this is the problem!"
        echo "   Install with: sudo apt-get install gstreamer1.0-plugins-good"
        exit 1
    fi
else
    echo "   ✗ GStreamer not found"
    echo "   Install with: sudo apt-get install gstreamer1.0-tools"
    exit 1
fi

# Test 3: Compile RPiPlay  
echo "4. Compiling RPiPlay..."
make clean && make

if [ ! -f "./rpiplay" ]; then
    echo "   ✗ rpiplay binary not found after compilation"
    exit 1
else
    echo "   ✓ rpiplay compiled successfully"
fi

# Test 4: Run with debug output  
echo "5. Starting RPiPlay with debug output..."
echo "   Look for debug messages about rotation..."
echo "   Press Ctrl+C to stop"
echo ""

# Force GStreamer renderer and show debug output
./rpiplay -vr gstreamer -d

echo ""
echo "=== Test completed ==="
