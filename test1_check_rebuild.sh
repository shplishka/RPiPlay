#!/bin/bash

# TEST 1: Check if RPiPlay rebuild was successful
# Copy this script to Raspberry Pi and run: bash test1_check_rebuild.sh

echo "=============================================="
echo "  TEST 1: Checking RPiPlay Rebuild"
echo "=============================================="
echo ""

# Check if rpiplay command exists
if command -v rpiplay >/dev/null; then
    echo "✓ rpiplay command found"
    echo ""
    
    # Show rpiplay help
    echo "RPiPlay help output:"
    rpiplay -h
    echo ""
    
    # Check for new options
    if rpiplay -h | grep -q "esp32"; then
        echo "✅ SUCCESS: ESP32 support detected!"
    else
        echo "❌ FAILED: ESP32 support missing"
        echo ""
        echo "SOLUTION: Rebuild RPiPlay with new code"
        echo "Commands to run on RPi:"
        echo "  cd ~/RPiPlay"
        echo "  rm -rf build"
        echo "  mkdir build && cd build"
        echo "  cmake .."
        echo "  make -j"
        echo "  sudo make install"
        exit 1
    fi
    
    if rpiplay -h | grep -q "touch"; then
        echo "✅ SUCCESS: Touch support detected!"
    else
        echo "❌ FAILED: Touch support missing"
        echo "SOLUTION: Rebuild RPiPlay - see above commands"
        exit 1
    fi
    
    echo ""
    echo "New options found:"
    rpiplay -h | grep -E "esp32|touch|iphone|rpi" || echo "None found"
    
else
    echo "❌ FAILED: rpiplay command not found"
    echo ""
    echo "SOLUTION: Install or rebuild RPiPlay"
    echo "Commands:"
    echo "  cd ~/RPiPlay"
    echo "  mkdir build && cd build"  
    echo "  cmake .. && make -j && sudo make install"
    exit 1
fi

echo ""
echo "=============================================="
echo "✅ RESULT: RPiPlay rebuild SUCCESSFUL!"
echo "Proceed to test2_check_devices.sh"
echo "==============================================" 