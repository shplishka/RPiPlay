#!/bin/bash

# Quick Touch Test for Raspberry Pi
# Now that ESP32 is found at /dev/ttyUSB0, let's test touch input

ESP32_DEVICE="/dev/ttyUSB0"

echo "=============================================="
echo "  Quick Touch Test - Raspberry Pi"
echo "=============================================="
echo ""

echo "✓ ESP32 found at: $ESP32_DEVICE"
echo ""

echo "[STEP 1] Testing ESP32 communication..."
if [ -w "$ESP32_DEVICE" ]; then
    echo "✓ ESP32 device is writable"
    
    # Send test command
    echo "STATUS" > "$ESP32_DEVICE" 2>/dev/null && echo "✓ STATUS command sent to ESP32"
    sleep 1
    echo "HOME" > "$ESP32_DEVICE" 2>/dev/null && echo "✓ HOME command sent to ESP32"
    
    echo "Check ESP32 serial monitor (115200 baud) to see if it received commands"
else
    echo "✗ Cannot write to ESP32 device"
    echo "Fix: sudo chmod 666 $ESP32_DEVICE"
    echo "Or: sudo usermod -a -G dialout $USER && reboot"
fi

echo ""
echo "[STEP 2] Finding touch input devices..."

# List all input devices
echo "Available input devices:"
for device in /dev/input/event*; do
    if [ -e "$device" ]; then
        echo "  $device"
    fi
done

echo ""
echo "[STEP 3] Testing each device for touch activity..."
echo "Touch the screen when prompted!"

for device in /dev/input/event*; do
    if [ -e "$device" ]; then
        echo ""
        echo "Testing $device (touch screen for 3 seconds)..."
        if timeout 3 cat "$device" >/dev/null 2>&1; then
            echo "✓ $device shows activity - this might be your touch device!"
            TOUCH_DEVICE="$device"
        else
            echo "  $device - no activity"
        fi
    fi
done

if [ -n "$TOUCH_DEVICE" ]; then
    echo ""
    echo "✓ Potential touch device found: $TOUCH_DEVICE"
    
    echo ""
    echo "[STEP 4] Testing RPiPlay with touch control..."
    echo "Starting RPiPlay with touch and ESP32..."
    echo "Touch the screen and watch for debug messages!"
    echo "Press Ctrl+C to stop when done testing"
    echo ""
    
    read -p "Press Enter to start RPiPlay test..."
    
    # Start RPiPlay with debug logging
    rpiplay -d -esp32 "$ESP32_DEVICE" -touch "$TOUCH_DEVICE" -n "Touch Test" -iphone 390x844
    
else
    echo ""
    echo "✗ No touch device detected"
    echo ""
    echo "Manual detection steps:"
    echo "1. Install evtest: sudo apt install evtest"
    echo "2. Run evtest: sudo evtest"
    echo "3. Touch screen to see which device responds"
    echo "4. Use that device with: rpiplay -touch /dev/input/eventX ..."
    echo ""
    echo "Common touch devices to try:"
    echo "- /dev/input/event0"
    echo "- /dev/input/event1" 
    echo "- /dev/input/event2"
    echo ""
    echo "Test manually with: sudo cat /dev/input/event0"
    echo "(Touch screen - should see binary output)"
fi

echo ""
echo "=============================================="
echo "Summary:"
echo "✓ ESP32 detected at: $ESP32_DEVICE"
if [ -n "$TOUCH_DEVICE" ]; then
    echo "✓ Touch device: $TOUCH_DEVICE"
    echo ""
    echo "To run RPiPlay with touch control:"
    echo "rpiplay -esp32 $ESP32_DEVICE -touch $TOUCH_DEVICE -n 'RPi Touch'"
else
    echo "✗ Touch device needs manual detection"
fi
echo "==============================================" 