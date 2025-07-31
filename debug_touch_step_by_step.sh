#!/bin/bash

# Step-by-Step Touch Debug
# Touch still not detected - let's find why

ESP32_DEVICE="/dev/ttyUSB0"
TOUCH_DEVICE="/dev/input/event4"

echo "=============================================="
echo "  Step-by-Step Touch Debugging"
echo "=============================================="
echo ""

# Step 1: Basic device checks
echo "[STEP 1] Basic device checks..."
echo ""

if [ -e "$TOUCH_DEVICE" ]; then
    echo "✓ Touch device exists: $TOUCH_DEVICE"
else
    echo "✗ Touch device missing: $TOUCH_DEVICE"
    echo "Available devices:"
    ls /dev/input/event* || echo "No input devices found"
    exit 1
fi

if [ -e "$ESP32_DEVICE" ]; then
    echo "✓ ESP32 device exists: $ESP32_DEVICE"
else
    echo "✗ ESP32 device missing: $ESP32_DEVICE"
    exit 1
fi

# Step 2: Permission checks
echo ""
echo "[STEP 2] Permission checks..."
echo ""

# Check readable
if [ -r "$TOUCH_DEVICE" ]; then
    echo "✓ Touch device readable"
else
    echo "✗ Touch device NOT readable"
    echo "Fixing permissions..."
    sudo chmod 666 "$TOUCH_DEVICE"
    if [ -r "$TOUCH_DEVICE" ]; then
        echo "✓ Fixed - now readable"
    else
        echo "✗ Still not readable - check user groups"
    fi
fi

# Check writable for ESP32
if [ -w "$ESP32_DEVICE" ]; then
    echo "✓ ESP32 device writable"
else
    echo "✗ ESP32 device NOT writable"
    echo "Fixing permissions..."
    sudo chmod 666 "$ESP32_DEVICE"
fi

# Check groups
echo ""
echo "User groups: $(groups)"
if groups | grep -q "input"; then
    echo "✓ User in 'input' group"
else
    echo "✗ User NOT in 'input' group"
    echo "Adding to input group..."
    sudo usermod -a -G input $USER
    echo "⚠ Reboot required after adding to groups"
fi

if groups | grep -q "dialout"; then
    echo "✓ User in 'dialout' group"
else
    echo "✗ User NOT in 'dialout' group"
    echo "Adding to dialout group..."
    sudo usermod -a -G dialout $USER
    echo "⚠ Reboot required after adding to groups"
fi

# Step 3: Raw touch data test
echo ""
echo "[STEP 3] Testing raw touch data..."
echo ""
echo "Touch the screen NOW for 5 seconds..."
echo "You should see hexadecimal output when touching."
echo ""

if timeout 5 cat "$TOUCH_DEVICE" | hexdump -C | head -20; then
    echo ""
    echo "✓ Touch device produces data"
    TOUCH_DATA_OK=true
else
    echo ""
    echo "✗ No touch data detected"
    echo ""
    echo "Let's try a different approach..."
    echo "Install evtest to identify the correct device:"
    echo "sudo apt install evtest"
    echo "sudo evtest"
    echo ""
    TOUCH_DATA_OK=false
fi

# Step 4: Check if RPiPlay has touch support
echo ""
echo "[STEP 4] Checking RPiPlay installation..."
echo ""

if command -v rpiplay >/dev/null; then
    echo "✓ rpiplay command found"
    
    # Check if it has touch options
    if rpiplay -h | grep -q "touch"; then
        echo "✓ RPiPlay has touch support"
        RPIPLAY_OK=true
    else
        echo "✗ RPiPlay does NOT have touch support"
        echo "Need to rebuild RPiPlay with the new code!"
        echo ""
        echo "Rebuild commands:"
        echo "cd ~/RPiPlay/build"
        echo "make clean"
        echo "cmake .."
        echo "make -j"
        echo "sudo make install"
        RPIPLAY_OK=false
    fi
else
    echo "✗ rpiplay command not found"
    RPIPLAY_OK=false
fi

# Step 5: ESP32 communication test
echo ""
echo "[STEP 5] Testing ESP32 communication..."
echo ""

echo "Sending test commands to ESP32..."
{
    echo "STATUS"
    sleep 1
    echo "HOME"  
    sleep 1
    echo "CLICK,100,200"
} > "$ESP32_DEVICE" 2>/dev/null

echo "✓ Commands sent to ESP32"
echo "Check ESP32 serial monitor (screen $ESP32_DEVICE 115200) to see responses"

# Step 6: Manual RPiPlay test (if both prerequisites are OK)
if [ "$TOUCH_DATA_OK" = true ] && [ "$RPIPLAY_OK" = true ]; then
    echo ""
    echo "[STEP 6] Manual RPiPlay test..."
    echo ""
    
    echo "Starting RPiPlay with maximum debug output..."
    echo "Touch the screen repeatedly and watch for messages."
    echo "Press Ctrl+C to stop when done."
    echo ""
    read -p "Press Enter to start RPiPlay debug test..."
    
    # Run with debug and show what happens
    strace -e trace=read rpiplay -d -esp32 "$ESP32_DEVICE" -touch "$TOUCH_DEVICE" -n "Debug Test" 2>&1 | grep -E "(touch|Touch|ESP32|event4|read)" || true
    
else
    echo ""
    echo "[STEP 6] Skipping RPiPlay test - prerequisites not met"
fi

# Step 7: Summary and recommendations
echo ""
echo "=============================================="
echo "  DIAGNOSIS SUMMARY"
echo "=============================================="

if [ "$TOUCH_DATA_OK" = false ]; then
    echo "❌ MAIN ISSUE: Touch device not producing data"
    echo ""
    echo "Solutions to try:"
    echo "1. Find correct device: sudo evtest"
    echo "2. Try other event devices:"
    for dev in /dev/input/event*; do
        [ -e "$dev" ] && echo "   sudo cat $dev  # Touch screen"
    done
    echo "3. Check if touchscreen driver is loaded:"
    echo "   dmesg | grep -i touch"
    echo "   lsmod | grep touch"
    echo "4. Reboot and try again"
    
elif [ "$RPIPLAY_OK" = false ]; then
    echo "❌ MAIN ISSUE: RPiPlay missing touch support"
    echo ""
    echo "Solution:"
    echo "1. Rebuild RPiPlay with new code:"
    echo "   cd ~/RPiPlay/build"
    echo "   make clean && cmake .. && make -j && sudo make install"
    echo "2. Verify: rpiplay -h | grep touch"
    
else
    echo "✅ Both touch data and RPiPlay seem OK"
    echo ""
    echo "If touch still doesn't work in RPiPlay:"
    echo "1. Check coordinate mapping (RPi screen size vs iPhone)"
    echo "2. Try different touch thresholds"
    echo "3. Run with strace to see system calls"
    echo "4. Check touch handler code for bugs"
fi

echo ""
echo "Current working command (if everything is OK):"
echo "rpiplay -d -esp32 $ESP32_DEVICE -touch $TOUCH_DEVICE -n 'Debug Test'"
echo ""
echo "==============================================" 