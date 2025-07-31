#!/bin/bash

# Test Both Touch Devices with ESP32
# event4 and event9 detected

ESP32_DEVICE="/dev/ttyUSB0"
TOUCH1="/dev/input/event4"
TOUCH2="/dev/input/event9"

echo "=============================================="
echo "  Testing Both Touch Devices"
echo "=============================================="
echo ""
echo "✓ ESP32: $ESP32_DEVICE"
echo "✓ Touch Device 1: $TOUCH1"
echo "✓ Touch Device 2: $TOUCH2"
echo ""

# Test ESP32 first
echo "[STEP 1] Testing ESP32 communication..."
if [ -w "$ESP32_DEVICE" ]; then
    echo "✓ ESP32 is writable"
    echo "STATUS" > "$ESP32_DEVICE" && echo "✓ STATUS command sent"
    sleep 1
else
    echo "✗ ESP32 not writable - fixing permissions..."
    sudo chmod 666 "$ESP32_DEVICE"
fi

echo ""
echo "[STEP 2] Testing event4 vs event9..."

echo ""
echo "Testing $TOUCH1 (event4):"
echo "Touch the screen for 5 seconds..."
if timeout 5 cat "$TOUCH1" | hexdump -C | head -10; then
    echo "✓ event4 shows touch data"
    EVENT4_WORKS=true
else
    echo "✗ event4 no data"
    EVENT4_WORKS=false
fi

echo ""
echo "Testing $TOUCH2 (event9):"
echo "Touch the screen for 5 seconds..."
if timeout 5 cat "$TOUCH2" | hexdump -C | head -10; then
    echo "✓ event9 shows touch data"
    EVENT9_WORKS=true
else
    echo "✗ event9 no data"
    EVENT9_WORKS=false
fi

echo ""
echo "[STEP 3] Testing with RPiPlay..."

# Function to test RPiPlay with a specific device
test_rpiplay() {
    local device=$1
    local name=$2
    
    echo ""
    echo "Testing RPiPlay with $name ($device)..."
    echo "This will run for 30 seconds - touch the screen to test!"
    echo "Look for debug messages when you touch."
    echo "Press Ctrl+C if you want to stop early."
    echo ""
    read -p "Press Enter to start test with $name..."
    
    timeout 30 rpiplay -d -esp32 "$ESP32_DEVICE" -touch "$device" -n "Test $name" -iphone 390x844 -rpi 800x480 || true
    
    echo ""
    echo "Did you see debug messages when touching? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "✓ $name works with RPiPlay!"
        return 0
    else
        echo "✗ $name doesn't work with RPiPlay"
        return 1
    fi
}

# Test both devices with RPiPlay
if [ "$EVENT4_WORKS" = true ]; then
    if test_rpiplay "$TOUCH1" "event4"; then
        BEST_DEVICE="$TOUCH1"
        BEST_NAME="event4"
    fi
fi

if [ "$EVENT9_WORKS" = true ]; then
    if test_rpiplay "$TOUCH2" "event9"; then
        if [ -z "$BEST_DEVICE" ]; then
            BEST_DEVICE="$TOUCH2"
            BEST_NAME="event9"
        else
            echo ""
            echo "Both devices work! Which worked better?"
            echo "1. event4 ($TOUCH1)"
            echo "2. event9 ($TOUCH2)"
            read -p "Choose (1 or 2): " choice
            if [ "$choice" = "2" ]; then
                BEST_DEVICE="$TOUCH2"
                BEST_NAME="event9"
            fi
        fi
    fi
fi

echo ""
echo "=============================================="
echo "TEST RESULTS"
echo "=============================================="

if [ -n "$BEST_DEVICE" ]; then
    echo "✓ Best touch device: $BEST_DEVICE ($BEST_NAME)"
    echo ""
    echo "FINAL COMMAND TO USE:"
    echo "rpiplay -esp32 $ESP32_DEVICE -touch $BEST_DEVICE -n 'RPi Touch'"
    echo ""
    echo "Or with custom iPhone resolution:"
    echo "rpiplay -esp32 $ESP32_DEVICE -touch $BEST_DEVICE -iphone 390x844 -rpi 800x480 -n 'RPi Touch'"
    echo ""
    
    # Create a launch script with the working device
    cat > ~/start_touch_control.sh <<EOF
#!/bin/bash
echo "Starting RPiPlay Touch Control..."
echo "ESP32: $ESP32_DEVICE"
echo "Touch: $BEST_DEVICE"
echo "Press Ctrl+C to stop"
echo ""
rpiplay -esp32 "$ESP32_DEVICE" -touch "$BEST_DEVICE" -n "RPi Touch" -iphone 390x844 -rpi 800x480
EOF
    
    chmod +x ~/start_touch_control.sh
    echo "✓ Created launch script: ~/start_touch_control.sh"
    
else
    echo "✗ No working touch device found"
    echo ""
    echo "Try these manual tests:"
    echo "1. sudo cat $TOUCH1  # Touch screen"
    echo "2. sudo cat $TOUCH2  # Touch screen"
    echo "3. Check permissions: sudo chmod 666 /dev/input/event*"
    echo "4. Add to groups: sudo usermod -a -G input,dialout $USER"
    echo "5. Reboot and try again"
fi

echo "==============================================" 