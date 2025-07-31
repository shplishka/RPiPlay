#!/bin/bash

# TEST 5: Test RPiPlay initialization
# Copy this script to Raspberry Pi and run: bash test5_test_rpiplay_init.sh

echo "=============================================="
echo "  TEST 5: Testing RPiPlay Initialization"
echo "=============================================="
echo ""

ESP32_DEVICE="/dev/ttyUSB0"
TOUCH_DEVICE="/dev/input/event4"

echo "Testing RPiPlay initialization with:"
echo "ESP32: $ESP32_DEVICE"  
echo "Touch: $TOUCH_DEVICE"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v rpiplay >/dev/null; then
    echo "❌ rpiplay command not found"
    exit 1
fi

if ! rpiplay -h | grep -q "esp32"; then
    echo "❌ RPiPlay missing ESP32 support"
    exit 1
fi

if ! rpiplay -h | grep -q "touch"; then
    echo "❌ RPiPlay missing touch support"
    exit 1
fi

if [ ! -e "$ESP32_DEVICE" ] || [ ! -w "$ESP32_DEVICE" ]; then
    echo "❌ ESP32 device not available"
    exit 1
fi

if [ ! -e "$TOUCH_DEVICE" ] || [ ! -r "$TOUCH_DEVICE" ]; then
    echo "❌ Touch device not available"
    echo "Available readable devices:"
    for dev in /dev/input/event*; do
        if [ -e "$dev" ] && [ -r "$dev" ]; then
            echo "  $dev"
        fi
    done
    exit 1
fi

echo "✓ All prerequisites met"
echo ""

# Start RPiPlay and capture initialization
echo "Starting RPiPlay with debug output..."
echo "This will run for 10 seconds to capture initialization messages"
echo ""

# Run RPiPlay in background and capture output
timeout 10 rpiplay -d -esp32 "$ESP32_DEVICE" -touch "$TOUCH_DEVICE" -n "Init Test" 2>&1 | tee /tmp/rpiplay_init.log &
rpiplay_pid=$!

echo "RPiPlay started (PID: $rpiplay_pid)"
echo "Waiting for initialization..."

# Wait for startup
sleep 3

# Check if still running
if ! kill -0 $rpiplay_pid 2>/dev/null; then
    echo "❌ RPiPlay exited unexpectedly"
    echo ""
    echo "Error output:"
    cat /tmp/rpiplay_init.log | tail -10
    exit 1
fi

echo "✓ RPiPlay is running"

# Wait a bit more for full initialization
sleep 4

# Stop RPiPlay
echo "Stopping RPiPlay..."
kill $rpiplay_pid 2>/dev/null
wait $rpiplay_pid 2>/dev/null

echo ""
echo "=============================================="
echo "ANALYZING INITIALIZATION OUTPUT:"
echo "=============================================="
echo ""

# Check initialization messages
if grep -q "Touch input enabled" /tmp/rpiplay_init.log; then
    echo "✅ Touch handler initialized successfully"
    touch_init_line=$(grep "Touch input enabled" /tmp/rpiplay_init.log)
    echo "   $touch_init_line"
    TOUCH_INIT_OK=true
else
    echo "❌ Touch handler NOT initialized"
    TOUCH_INIT_OK=false
fi

if grep -q "ESP32 communication enabled" /tmp/rpiplay_init.log; then
    echo "✅ ESP32 handler initialized successfully"
    esp32_init_line=$(grep "ESP32 communication enabled" /tmp/rpiplay_init.log)
    echo "   $esp32_init_line"
    ESP32_INIT_OK=true
else
    echo "❌ ESP32 handler NOT initialized"
    ESP32_INIT_OK=false
fi

if grep -q "Coordinate mapping set" /tmp/rpiplay_init.log; then
    echo "✅ Coordinate mapping configured"
    mapping_line=$(grep "Coordinate mapping set" /tmp/rpiplay_init.log)
    echo "   $mapping_line"
    MAPPING_OK=true
else
    echo "⚠ Coordinate mapping not found in logs"
    MAPPING_OK=false
fi

echo ""
echo "Full initialization log:"
echo "----------------------------------------"
cat /tmp/rpiplay_init.log | head -20
echo "----------------------------------------"

echo ""
echo "=============================================="
echo "RESULTS:"
echo "=============================================="

if [ "$TOUCH_INIT_OK" = true ] && [ "$ESP32_INIT_OK" = true ]; then
    echo "✅ SUCCESS: RPiPlay initialization WORKING!"
    echo ""
    echo "✓ Touch handler: OK"
    echo "✓ ESP32 handler: OK"
    [ "$MAPPING_OK" = true ] && echo "✓ Coordinate mapping: OK" || echo "⚠ Coordinate mapping: Not confirmed"
    echo ""
    echo "RPiPlay is ready for touch control!"
    echo ""
    echo "✅ RESULT: Initialization SUCCESS!"
    echo "Proceed to test6_test_full_system.sh"
    
elif [ "$TOUCH_INIT_OK" = false ]; then
    echo "❌ FAILED: Touch handler initialization failed"
    echo ""
    echo "TROUBLESHOOTING:"
    echo "1. Check touch device permissions: ls -la $TOUCH_DEVICE"
    echo "2. Try different touch device: ls /dev/input/event*"
    echo "3. Check user groups: groups | grep input"
    echo "4. Test raw touch: sudo cat $TOUCH_DEVICE"
    echo ""
    echo "❌ RESULT: Touch initialization FAILED!"
    
elif [ "$ESP32_INIT_OK" = false ]; then
    echo "❌ FAILED: ESP32 handler initialization failed"
    echo ""
    echo "TROUBLESHOOTING:"
    echo "1. Check ESP32 device permissions: ls -la $ESP32_DEVICE"
    echo "2. Check user groups: groups | grep dialout"
    echo "3. Test ESP32 communication: echo 'STATUS' > $ESP32_DEVICE"
    echo ""
    echo "❌ RESULT: ESP32 initialization FAILED!"
    
else
    echo "❌ FAILED: Unknown initialization issue"
    echo ""
    echo "Check the full log:"
    echo "cat /tmp/rpiplay_init.log"
fi

echo ""
echo "Log saved to: /tmp/rpiplay_init.log"
echo "==============================================" 