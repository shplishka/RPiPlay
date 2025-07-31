#!/bin/bash

# TEST 3: Test raw touch input
# Copy this script to Raspberry Pi and run: bash test3_test_touch_raw.sh

echo "=============================================="
echo "  TEST 3: Testing Raw Touch Input"
echo "=============================================="
echo ""

echo "This test will check if touch devices produce data when touched."
echo "You need to touch the screen when prompted."
echo ""

# Test each input device
for device in /dev/input/event*; do
    if [ -e "$device" ] && [ -r "$device" ]; then
        echo "Testing $device..."
        echo "Touch the screen NOW for 3 seconds..."
        
        # Capture touch data
        touch_data=$(timeout 3 cat "$device" | hexdump -C 2>/dev/null)
        
        if [ -n "$touch_data" ]; then
            echo "✅ SUCCESS: $device produces data when touched!"
            echo "Sample data:"
            echo "$touch_data" | head -3
            echo ""
            
            # Check if it looks like touch events
            if echo "$touch_data" | grep -q "03.*01\|03.*00"; then
                echo "✓ Data contains touch events (EV_ABS)"
                WORKING_DEVICES="$WORKING_DEVICES $device"
            else
                echo "⚠ Data doesn't look like standard touch events"
            fi
            
        else
            echo "❌ No data from $device"
        fi
        
        echo ""
        echo "Press Enter to test next device..."
        read -r dummy
        echo "----------------------------------------"
    fi
done

echo ""
echo "=============================================="
echo "SUMMARY:"
echo "=============================================="

if [ -n "$WORKING_DEVICES" ]; then
    echo "✅ Working touch devices found:"
    for dev in $WORKING_DEVICES; do
        echo "  $dev"
    done
    
    echo ""
    echo "RECOMMENDATION:"
    echo "Use one of these devices for touch input:"
    for dev in $WORKING_DEVICES; do
        echo "  rpiplay -touch $dev ..."
    done
    
    echo ""
    echo "✅ RESULT: Raw touch input WORKING!"
    echo "Proceed to test4_test_esp32.sh"
    
else
    echo "❌ No working touch devices found!"
    echo ""
    echo "TROUBLESHOOTING:"
    echo "1. Check if touchscreen is connected and working"
    echo "2. Try different input devices:"
    for dev in /dev/input/event*; do
        if [ -e "$dev" ]; then
            echo "   sudo cat $dev  # Touch screen while running"
        fi
    done
    echo "3. Check touchscreen driver: dmesg | grep -i touch"
    echo "4. Install evtest: sudo apt install evtest && sudo evtest"
    echo "5. Reboot and try again"
    
    echo ""
    echo "❌ RESULT: Raw touch input FAILED!"
    echo "Fix touch input before proceeding"
fi

echo "==============================================" 