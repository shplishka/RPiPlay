#!/bin/bash

# TEST 6: Test complete touch control system
# Copy this script to Raspberry Pi and run: bash test6_test_full_system.sh

echo "=============================================="
echo "  TEST 6: Complete Touch Control System Test"
echo "=============================================="
echo ""

ESP32_DEVICE="/dev/ttyUSB0"
TOUCH_DEVICE="/dev/input/event4"

echo "Testing complete touch control system:"
echo "ESP32: $ESP32_DEVICE"
echo "Touch: $TOUCH_DEVICE"
echo ""

# Pre-flight checks
echo "Pre-flight checks..."

if ! command -v rpiplay >/dev/null || ! rpiplay -h | grep -q "touch"; then
    echo "❌ RPiPlay not ready - run previous tests first"
    exit 1
fi

if [ ! -e "$ESP32_DEVICE" ] || [ ! -w "$ESP32_DEVICE" ]; then
    echo "❌ ESP32 not ready - run test4_test_esp32.sh first"
    exit 1
fi

if [ ! -e "$TOUCH_DEVICE" ] || [ ! -r "$TOUCH_DEVICE" ]; then
    echo "❌ Touch device not ready - run test3_test_touch_raw.sh first"
    exit 1
fi

echo "✓ All systems ready"
echo ""

echo "=============================================="
echo "FULL SYSTEM TEST"
echo "=============================================="
echo ""
echo "This test will:"
echo "1. Start RPiPlay with touch and ESP32 support"
echo "2. Monitor for touch events"
echo "3. Verify ESP32 commands are sent"
echo "4. Run for 60 seconds"
echo ""
echo "INSTRUCTIONS:"
echo "- Touch the screen repeatedly during the test"
echo "- Try different gestures (tap, vertical swipe for scroll)"
echo "- Watch for debug messages"
echo "- Press Ctrl+C to stop early if needed"
echo ""

read -p "Press Enter to start the full system test..."

echo ""
echo "Starting RPiPlay with full debug output..."
echo "=============================================="

# Start RPiPlay with comprehensive logging
timeout 60 rpiplay -d \
    -esp32 "$ESP32_DEVICE" \
    -touch "$TOUCH_DEVICE" \
    -iphone 390x844 \
    -rpi 800x480 \
    -n "Touch Control Test" \
    2>&1 | tee /tmp/rpiplay_full_test.log

echo ""
echo "=============================================="
echo "TEST COMPLETED - ANALYZING RESULTS"
echo "=============================================="
echo ""

# Analyze the log for touch events
touch_events=$(grep -c "Touch.*at" /tmp/rpiplay_full_test.log)
esp32_commands=$(grep -c "Sent to ESP32" /tmp/rpiplay_full_test.log)
initialization_ok=$(grep -c "Touch input enabled\|ESP32 communication enabled" /tmp/rpiplay_full_test.log)

echo "Results Analysis:"
echo "- Initialization messages: $initialization_ok"
echo "- Touch events detected: $touch_events"
echo "- ESP32 commands sent: $esp32_commands"
echo ""

# Show sample events
if [ "$touch_events" -gt 0 ]; then
    echo "Sample touch events:"
    grep "Touch.*at" /tmp/rpiplay_full_test.log | head -5
    echo ""
fi

if [ "$esp32_commands" -gt 0 ]; then
    echo "Sample ESP32 commands:"
    grep "Sent to ESP32" /tmp/rpiplay_full_test.log | head -5
    echo ""
fi

# Determine test result
echo "=============================================="
echo "FINAL RESULTS:"
echo "=============================================="

if [ "$initialization_ok" -ge 2 ] && [ "$touch_events" -gt 0 ] && [ "$esp32_commands" -gt 0 ]; then
    echo "🎉 SUCCESS: Complete touch control system WORKING!"
    echo ""
    echo "✅ System initialized correctly"
    echo "✅ Touch events detected ($touch_events events)"
    echo "✅ ESP32 commands sent ($esp32_commands commands)"
    echo ""
    
    # Calculate efficiency
    if [ "$touch_events" -gt 0 ]; then
        efficiency=$(( esp32_commands * 100 / touch_events ))
        echo "Command efficiency: $efficiency% (ESP32 commands / touch events)"
    fi
    
    echo ""
    echo "🏆 FINAL RESULT: COMPLETE SUCCESS!"
    echo ""
    echo "Your touch control system is working!"
    echo "You can now use:"
    echo "  rpiplay -esp32 $ESP32_DEVICE -touch $TOUCH_DEVICE -n 'RPi Touch'"
    echo ""
    
    # Create final launch script
    cat > ~/launch_rpiplay_touch.sh <<EOF
#!/bin/bash
echo "🚀 Starting RPiPlay Touch Control System"
echo "ESP32: $ESP32_DEVICE"
echo "Touch: $TOUCH_DEVICE"
echo ""
echo "Make sure:"
echo "1. ESP32 is connected and programmed"
echo "2. iPhone is paired with ESP32 Bluetooth ('iPhone Remote')"
echo "3. ESP32 LED is on when iPhone connected"
echo ""
echo "Press Ctrl+C to stop"
echo ""
rpiplay -esp32 "$ESP32_DEVICE" -touch "$TOUCH_DEVICE" -iphone 390x844 -rpi 800x480 -n "RPi Touch Control"
EOF
    chmod +x ~/launch_rpiplay_touch.sh
    echo "✅ Created launch script: ~/launch_rpiplay_touch.sh"
    
elif [ "$initialization_ok" -lt 2 ]; then
    echo "❌ FAILED: System initialization failed"
    echo ""
    echo "Issues found:"
    [ "$initialization_ok" -eq 0 ] && echo "- No initialization messages found"
    [ "$initialization_ok" -eq 1 ] && echo "- Only partial initialization (touch OR ESP32, not both)"
    echo ""
    echo "Run previous tests to fix initialization issues"
    
elif [ "$touch_events" -eq 0 ]; then
    echo "❌ FAILED: No touch events detected"
    echo ""
    echo "Touch system is not working. Check:"
    echo "1. Touch device permissions and groups"
    echo "2. Touch device is correct ($TOUCH_DEVICE)"
    echo "3. Touchscreen hardware is working"
    echo "4. Run test3_test_touch_raw.sh again"
    
elif [ "$esp32_commands" -eq 0 ]; then
    echo "❌ FAILED: No ESP32 commands sent"
    echo ""
    echo "ESP32 communication is not working. Check:"
    echo "1. ESP32 device permissions and groups"
    echo "2. ESP32 is connected and responsive"
    echo "3. Run test4_test_esp32.sh again"
    
else
    echo "⚠️ PARTIAL: System partially working"
    echo ""
    echo "Some components work but system is not fully functional"
    echo "Check the full log for details:"
    echo "cat /tmp/rpiplay_full_test.log"
fi

echo ""
echo "=============================================="
echo "DEBUG INFORMATION:"
echo "=============================================="
echo ""
echo "Complete test log saved to: /tmp/rpiplay_full_test.log"
echo ""
echo "To view the log:"
echo "  cat /tmp/rpiplay_full_test.log"
echo ""
echo "To test manually:"
echo "  rpiplay -d -esp32 $ESP32_DEVICE -touch $TOUCH_DEVICE -n 'Manual Test'"
echo ""
echo "=============================================="
echo "TEST SEQUENCE COMPLETE!"
echo "==============================================" 