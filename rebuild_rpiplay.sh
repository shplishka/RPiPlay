#!/bin/bash

# Rebuild RPiPlay with Touch and ESP32 Support
# This script rebuilds RPiPlay with the new functionality

echo "=============================================="
echo "  Rebuilding RPiPlay with Touch Support"
echo "=============================================="
echo ""

# Check if we're in the right directory
if [ ! -f "rpiplay.cpp" ] || [ ! -d "lib" ]; then
    echo "❌ Not in RPiPlay source directory!"
    echo ""
    echo "Navigate to your RPiPlay directory first:"
    echo "cd ~/RPiPlay"
    echo "Then run this script again."
    exit 1
fi

echo "✓ In RPiPlay source directory"

# Check if our new files exist
echo ""
echo "[STEP 1] Checking for new touch/ESP32 files..."

if [ -f "lib/esp32_comm.h" ] && [ -f "lib/esp32_comm.cpp" ]; then
    echo "✓ ESP32 communication files found"
else
    echo "❌ ESP32 communication files missing!"
    echo "Make sure esp32_comm.h and esp32_comm.cpp are in lib/ directory"
    exit 1
fi

if [ -f "lib/touch_handler.h" ] && [ -f "lib/touch_handler.cpp" ]; then
    echo "✓ Touch handler files found"
else
    echo "❌ Touch handler files missing!"
    echo "Make sure touch_handler.h and touch_handler.cpp are in lib/ directory"
    exit 1
fi

# Check if main file was modified
if grep -q "esp32_comm.h" rpiplay.cpp; then
    echo "✓ Main file includes ESP32 support"
else
    echo "❌ Main file (rpiplay.cpp) not modified!"
    echo "The rpiplay.cpp file needs to include the new functionality"
    exit 1
fi

echo ""
echo "[STEP 2] Cleaning previous build..."

# Remove old build directory
if [ -d "build" ]; then
    echo "Removing old build directory..."
    rm -rf build
fi

# Create new build directory
mkdir build
cd build

echo "✓ Clean build directory created"

echo ""
echo "[STEP 3] Configuring build with CMake..."

# Run cmake
if cmake ..; then
    echo "✓ CMake configuration successful"
    
    # Check if OpenMAX was detected
    if grep -q "Found OpenMAX libraries for Raspberry Pi" CMakeCache.txt 2>/dev/null; then
        echo "✓ OpenMAX libraries detected - hardware acceleration enabled"
    else
        echo "ℹ Using software rendering (GStreamer fallback)"
    fi
else
    echo "❌ CMake configuration failed!"
    echo ""
    echo "Common issues:"
    echo "1. Missing dependencies - run: sudo apt install cmake build-essential"
    echo "2. Missing libraries - run: sudo apt install libssl-dev libavahi-compat-libdnssd-dev libplist-dev"
    exit 1
fi

echo ""
echo "[STEP 4] Building RPiPlay..."
echo "This may take several minutes..."

# Build with all CPU cores
if make -j$(nproc); then
    echo "✓ Build successful!"
else
    echo "❌ Build failed!"
    echo ""
    echo "Check the error messages above."
    echo "Common issues:"
    echo "1. Missing header files"
    echo "2. Syntax errors in new code"
    echo "3. Missing dependencies"
    exit 1
fi

echo ""
echo "[STEP 5] Installing RPiPlay..."

# Install the new version
if sudo make install; then
    echo "✓ Installation successful!"
else
    echo "❌ Installation failed!"
    exit 1
fi

echo ""
echo "[STEP 6] Verifying new functionality..."

# Check if the new options are available
if rpiplay -h | grep -q "esp32"; then
    echo "✓ ESP32 support detected"
else
    echo "❌ ESP32 support not found in help"
fi

if rpiplay -h | grep -q "touch"; then
    echo "✓ Touch support detected"
else
    echo "❌ Touch support not found in help"
fi

# Show the new options
echo ""
echo "New command line options:"
rpiplay -h | grep -E "(esp32|touch|iphone|rpi)" || echo "No new options found"

echo ""
echo "=============================================="
echo "  BUILD COMPLETE!"
echo "=============================================="
echo ""

# Check if everything is working
if rpiplay -h | grep -E "(esp32|touch)" >/dev/null; then
    echo "✅ SUCCESS! RPiPlay rebuilt with touch and ESP32 support"
    echo ""
    echo "Test command:"
    echo "rpiplay -d -esp32 /dev/ttyUSB0 -touch /dev/input/event4 -n 'Touch Test'"
    echo ""
    echo "Full command with settings:"
    echo "rpiplay -esp32 /dev/ttyUSB0 -touch /dev/input/event4 -iphone 390x844 -rpi 800x480 -n 'RPi Touch'"
    
    # Create a test script
    cd ..
    cat > ~/test_rpiplay_touch.sh <<'EOF'
#!/bin/bash
echo "Testing RPiPlay Touch Control..."
echo "Touch the screen and watch for debug messages!"
echo "Press Ctrl+C to stop"
echo ""
rpiplay -d -esp32 /dev/ttyUSB0 -touch /dev/input/event4 -n "Touch Test" -iphone 390x844
EOF
    chmod +x ~/test_rpiplay_touch.sh
    echo ""
    echo "✓ Created test script: ~/test_rpiplay_touch.sh"
    
else
    echo "❌ PROBLEM: New options not detected after rebuild"
    echo ""
    echo "Possible issues:"
    echo "1. Source code modifications were not applied correctly"
    echo "2. Build used cached files - try: rm -rf build && mkdir build && cd build && cmake .. && make -j"
    echo "3. Installation path issues"
    echo ""
    echo "Debug steps:"
    echo "1. Check source modifications: grep -n 'esp32_comm' rpiplay.cpp"
    echo "2. Check build: ls -la rpiplay"
    echo "3. Check installation: which rpiplay"
fi

echo ""
echo "Next steps:"
echo "1. Make sure ESP32 is connected and programmed"
echo "2. Pair iPhone with ESP32 Bluetooth"
echo "3. Run: ~/test_rpiplay_touch.sh"
echo "==============================================" 