#!/bin/bash

# Detailed Touch Debug - Find Why Touch Still Doesn't Work
# This script traces every step of the touch process

ESP32_DEVICE="/dev/ttyUSB0"
TOUCH_DEVICE="/dev/input/event4"

echo "=============================================="
echo "  Detailed Touch Debugging"
echo "=============================================="
echo ""

# Step 1: Verify rebuild was successful
echo "[STEP 1] Verifying RPiPlay rebuild..."
echo ""

if command -v rpiplay >/dev/null; then
    echo "✓ rpiplay command found"
    
    echo "RPiPlay version and options:"
    rpiplay -h | head -5
    echo ""
    
    if rpiplay -h | grep -q "esp32"; then
        echo "✓ ESP32 support detected"
    else
        echo "❌ ESP32 support missing - rebuild failed!"
        echo "Try: cd ~/RPiPlay && rm -rf build && mkdir build && cd build && cmake .. && make -j && sudo make install"
        exit 1
    fi
    
    if rpiplay -h | grep -q "touch"; then
        echo "✓ Touch support detected"
    else
        echo "❌ Touch support missing - rebuild failed!"
        exit 1
    fi
else
    echo "❌ rpiplay command not found"
    exit 1
fi

# Step 2: Test raw touch input
echo ""
echo "[STEP 2] Testing raw touch input..."
echo ""

echo "Testing if $TOUCH_DEVICE produces data when touched..."
echo "Touch the screen NOW for 3 seconds..."

# Capture touch data and analyze it
touch_data=$(timeout 3 cat "$TOUCH_DEVICE" | hexdump -C)
if [ -n "$touch_data" ]; then
    echo "✓ Touch device produces data:"
    echo "$touch_data" | head -5
    echo ""
    
    # Check if it's the right type of data
    if echo "$touch_data" | grep -q "03.*01\|03.*00"; then
        echo "✓ Data looks like touch events (EV_ABS)"
    else
        echo "⚠ Data doesn't look like standard touch events"
    fi
    
    TOUCH_RAW_OK=true
else
    echo "❌ No touch data detected"
    echo ""
    echo "Try other devices:"
    for dev in /dev/input/event*; do
        if [ -e "$dev" ]; then
            echo "Test: sudo timeout 2 cat $dev | hexdump -C"
        fi
    done
    TOUCH_RAW_OK=false
fi

# Step 3: Test ESP32 communication
echo ""
echo "[STEP 3] Testing ESP32 communication..."
echo ""

if [ -w "$ESP32_DEVICE" ]; then
    echo "✓ ESP32 device writable"
    
    # Send test commands
    echo "Sending test commands..."
    {
        echo "STATUS"
        sleep 0.5
        echo "HOME"
        sleep 0.5
        echo "CLICK,100,200"
    } > "$ESP32_DEVICE"
    
    echo "✓ Commands sent to ESP32"
    echo "Check ESP32 serial monitor to see if commands were received"
    ESP32_OK=true
else
    echo "❌ Cannot write to ESP32 device"
    echo "Fix: sudo chmod 666 $ESP32_DEVICE"
    ESP32_OK=false
fi

# Step 4: Test RPiPlay initialization
echo ""
echo "[STEP 4] Testing RPiPlay initialization..."
echo ""

echo "Starting RPiPlay with debug output for 10 seconds..."
echo "Look for initialization messages:"
echo ""

# Run RPiPlay and capture initialization output
timeout 10 rpiplay -d -esp32 "$ESP32_DEVICE" -touch "$TOUCH_DEVICE" -n "Init Test" 2>&1 | tee /tmp/rpiplay_debug.log &
rpiplay_pid=$!

sleep 2

# Check if RPiPlay is running
if kill -0 $rpiplay_pid 2>/dev/null; then
    echo "✓ RPiPlay started successfully"
    
    # Check for initialization messages
    sleep 3
    if grep -q "Touch input enabled" /tmp/rpiplay_debug.log; then
        echo "✓ Touch handler initialized"
        TOUCH_INIT_OK=true
    else
        echo "❌ Touch handler NOT initialized"
        TOUCH_INIT_OK=false
    fi
    
    if grep -q "ESP32 communication enabled" /tmp/rpiplay_debug.log; then
        echo "✓ ESP32 communication initialized"
        ESP32_INIT_OK=true
    else
        echo "❌ ESP32 communication NOT initialized"
        ESP32_INIT_OK=false
    fi
    
    # Stop RPiPlay
    kill $rpiplay_pid 2>/dev/null
    wait $rpiplay_pid 2>/dev/null
else
    echo "❌ RPiPlay failed to start"
    TOUCH_INIT_OK=false
    ESP32_INIT_OK=false
fi

# Step 5: Manual touch test with RPiPlay
if [ "$TOUCH_RAW_OK" = true ] && [ "$TOUCH_INIT_OK" = true ]; then
    echo ""
    echo "[STEP 5] Manual touch test with RPiPlay..."
    echo ""
    
    echo "Starting RPiPlay and monitoring for touch events..."
    echo "Touch the screen repeatedly and watch for debug messages!"
    echo "Press Ctrl+C when done testing"
    echo ""
    read -p "Press Enter to start the test..."
    
    # Run with maximum debug output
    timeout 30 strace -f -e trace=read,write,ioctl rpiplay -d -esp32 "$ESP32_DEVICE" -touch "$TOUCH_DEVICE" -n "Touch Test" 2>&1 | grep -E "(Touch|ESP32|event4|read.*event|write.*ttyUSB)" || true
    
    echo ""
    echo "Did you see 'Touch up/click' messages when touching? (y/n)"
    read -r saw_touch
    
    echo "Did you see 'Sent to ESP32' messages? (y/n)" 
    read -r saw_esp32
    
    if [ "$saw_touch" = "y" ] && [ "$saw_esp32" = "y" ]; then
        echo "✅ Touch detection and ESP32 communication working!"
        FULL_TEST_OK=true
    else
        echo "❌ Touch detection or ESP32 communication failed"
        FULL_TEST_OK=false
    fi
else
    echo ""
    echo "[STEP 5] Skipping manual test - prerequisites failed"
    FULL_TEST_OK=false
fi

# Step 6: Check system calls and permissions
echo ""
echo "[STEP 6] System diagnostics..."
echo ""

echo "File permissions:"
ls -la "$TOUCH_DEVICE" "$ESP32_DEVICE"

echo ""
echo "User groups:"
groups

echo ""
echo "Process limits:"
ulimit -n

echo ""
echo "Touch device info:"
if command -v udevadm >/dev/null; then
    udevadm info --query=property --name="$TOUCH_DEVICE" | grep -E "ID_INPUT|DEVNAME"
fi

# Summary and recommendations
echo ""
echo "=============================================="
echo "  DIAGNOSTIC SUMMARY"
echo "=============================================="

echo ""
echo "Test Results:"
[ "$TOUCH_RAW_OK" = true ] && echo "✓ Raw touch data: OK" || echo "❌ Raw touch data: FAILED"
[ "$ESP32_OK" = true ] && echo "✓ ESP32 communication: OK" || echo "❌ ESP32 communication: FAILED"  
[ "$TOUCH_INIT_OK" = true ] && echo "✓ Touch handler init: OK" || echo "❌ Touch handler init: FAILED"
[ "$ESP32_INIT_OK" = true ] && echo "✓ ESP32 handler init: OK" || echo "❌ ESP32 handler init: FAILED"
[ "$FULL_TEST_OK" = true ] && echo "✓ Full system test: OK" || echo "❌ Full system test: FAILED"

echo ""
if [ "$FULL_TEST_OK" = true ]; then
    echo "🎉 SUCCESS! Touch control should be working"
    echo ""
    echo "Final test command:"
    echo "rpiplay -esp32 $ESP32_DEVICE -touch $TOUCH_DEVICE -n 'RPi Touch'"
    
elif [ "$TOUCH_RAW_OK" = false ]; then
    echo "🔍 ISSUE: Touch device not producing data"
    echo ""
    echo "Solutions:"
    echo "1. Try different event device: ls /dev/input/event*"
    echo "2. Install evtest: sudo apt install evtest && sudo evtest"
    echo "3. Check touchscreen driver: dmesg | grep -i touch"
    echo "4. Reboot and test again"
    
elif [ "$TOUCH_INIT_OK" = false ]; then
    echo "🔍 ISSUE: Touch handler initialization failed"
    echo ""
    echo "Solutions:"
    echo "1. Check file permissions: sudo chmod 666 $TOUCH_DEVICE"
    echo "2. Check user groups: sudo usermod -a -G input $USER && reboot"
    echo "3. Check if device exists: ls -la $TOUCH_DEVICE"
    echo "4. Try different event device"
    
else
    echo "🔍 ISSUE: Touch detection logic problem"
    echo ""
    echo "Solutions:"
    echo "1. Check coordinate mapping - screen resolution settings"
    echo "2. Try different touch thresholds"
    echo "3. Debug touch handler code"
    echo "4. Check if touch events are being filtered out"
fi

echo ""
echo "Debug log saved to: /tmp/rpiplay_debug.log"
echo "View with: cat /tmp/rpiplay_debug.log"
echo ""
echo "==============================================" 