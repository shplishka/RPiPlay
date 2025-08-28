#!/bin/bash

# TEST 4 MINIMAL: Test ESP32 serial communication ONLY
# This version uses ONLY STATUS and RESET commands - absolutely no BLE activity
# Copy this script to Raspberry Pi and run: bash test4_test_esp32_minimal.sh

echo "=============================================="
echo "  TEST 4 MINIMAL: ESP32 Serial Communication"
echo "=============================================="
echo ""
echo "🔒 ULTRA-SAFE MODE: Only STATUS and RESET commands"
echo "🔒 ZERO BLE mouse activity - Bluetooth should stay connected"
echo "🔒 Testing pure serial communication only"
echo ""

ESP32_DEVICE="/dev/ttyUSB0"

echo "Testing ESP32 serial communication on: $ESP32_DEVICE"
echo ""

# Check if device exists and is writable
if [ ! -e "$ESP32_DEVICE" ]; then
    echo "❌ ESP32 device $ESP32_DEVICE not found!"
    echo ""
    echo "Available serial devices:"
    ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "None found"
    echo ""
    echo "If ESP32 is connected, try:"
    for dev in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -e "$dev" ]; then
            echo "  Edit this script and change ESP32_DEVICE to: $dev"
        fi
    done
    exit 1
fi

if [ ! -w "$ESP32_DEVICE" ]; then
    echo "❌ Cannot write to ESP32 device"
    echo "Fixing permissions..."
    sudo chmod 666 "$ESP32_DEVICE"
    
    if [ ! -w "$ESP32_DEVICE" ]; then
        echo "❌ Still cannot write to ESP32"
        echo "Try: sudo usermod -a -G dialout $USER && reboot"
        exit 1
    fi
fi

echo "✓ ESP32 device is writable"
echo ""

# Send ONLY the safest commands
echo "Sending MINIMAL test commands to ESP32..."
echo "Commands used: STATUS, RESET (absolutely no BLE activity)"
echo ""

# Test 1: STATUS command
echo "Test 1/4: Sending STATUS command..."
echo "STATUS" > "$ESP32_DEVICE"
sleep 2

# Test 2: RESET command  
echo "Test 2/4: Sending RESET command..."
echo "RESET" > "$ESP32_DEVICE"
sleep 2

# Test 3: Another STATUS to verify ESP32 still responding
echo "Test 3/4: Sending STATUS again..."
echo "STATUS" > "$ESP32_DEVICE"
sleep 2

# Test 4: Final RESET
echo "Test 4/4: Sending final RESET..."
echo "RESET" > "$ESP32_DEVICE"
sleep 2

echo ""
echo "✅ All minimal commands sent successfully!"
echo ""

# Instructions for checking ESP32 response
echo "=============================================="
echo "CHECK ESP32 SERIAL OUTPUT:"
echo "=============================================="
echo ""
echo "Open ESP32 serial monitor at 115200 baud:"
echo "  screen $ESP32_DEVICE 115200"
echo "  (Press Ctrl+A then K to exit)"
echo ""

echo "Expected ESP32 responses (should see 4 responses):"
echo ""
echo "Response 1:"
echo "📥 Command: STATUS"
echo "📊 === STATUS ==="
echo "🔗 Connection: ✅ Connected OR ❌ Disconnected"
echo "📱 Base Screen: 1170x2532"
echo "================="
echo ""
echo "Response 2:"
echo "📥 Command: RESET"
echo "🔄 Reset command received (no position tracking in this version)"
echo ""
echo "Response 3: (Same as Response 1)"
echo "Response 4: (Same as Response 2)"
echo ""

echo "=============================================="
echo "CRITICAL TEST:"
echo "=============================================="
echo ""
echo "The key test is whether iPhone Bluetooth stays connected"
echo "throughout this entire process."
echo ""

read -p "BEFORE we started: Was iPhone connected to ESP32? (y/n): " before_connected
read -p "Did ESP32 respond to STATUS commands? (y/n): " status_working
read -p "Did ESP32 respond to RESET commands? (y/n): " reset_working
read -p "RIGHT NOW: Is iPhone still connected to ESP32? (y/n): " still_connected

echo ""

if [ "$before_connected" = "y" ] && [ "$still_connected" = "y" ] && [ "$status_working" = "y" ] && [ "$reset_working" = "y" ]; then
    echo "🎉 SUCCESS: MINIMAL ESP32 communication WORKING!"
    echo "✅ Serial communication: WORKING"
    echo "✅ Bluetooth connection: STABLE"
    echo "✅ ESP32 responds to safe commands"
    echo ""
    echo "DIAGNOSIS: The disconnection issue is caused by:"
    echo "  → CLICK commands (trigger mouse movements)"
    echo "  → MOVE commands (trigger mouse movements)" 
    echo "  → SCROLL commands (trigger mouse wheel)"
    echo "  → Possibly SCREEN commands (might affect BLE state)"
    echo ""
    echo "✅ RESULT: ESP32 serial communication OK!"
    echo "✅ Use only STATUS/RESET for testing communication"
    
elif [ "$before_connected" = "y" ] && [ "$still_connected" = "n" ]; then
    echo "❌ BLUETOOTH STILL DISCONNECTED"
    echo ""
    echo "Even with minimal commands, Bluetooth disconnected."
    echo "This suggests a deeper issue:"
    echo ""
    echo "POSSIBLE CAUSES:"
    echo "1. iPhone power management disconnecting 'idle' devices"
    echo "2. ESP32 BLE connection parameters too aggressive"
    echo "3. Interference from serial communication itself"
    echo "4. iPhone Bluetooth stack issue"
    echo "5. Distance/signal strength issue"
    echo ""
    echo "SOLUTIONS TO TRY:"
    echo "1. Keep iPhone very close to ESP32 (< 1 meter)"
    echo "2. Don't run ANY tests while iPhone is connected"
    echo "3. Check iPhone Settings > Bluetooth > ESP32 Mouse > Forget Device, then re-pair"
    echo "4. Restart ESP32 completely"
    echo "5. Check ESP32 BLE connection parameters in code"
    echo ""
    echo "❌ RESULT: Deeper Bluetooth stability issue"
    
elif [ "$before_connected" = "n" ]; then
    echo "⚠️  iPhone was not connected before test"
    echo ""
    if [ "$status_working" = "y" ] && [ "$reset_working" = "y" ]; then
        echo "✅ Serial communication: WORKING"
        echo "❌ Bluetooth pairing: NOT ESTABLISHED"
        echo ""
        echo "NEXT STEPS:"
        echo "1. Pair iPhone with ESP32 via Bluetooth"
        echo "2. Look for 'ESP32 Mouse' in iPhone Bluetooth settings"
        echo "3. Re-run this test after pairing"
        echo ""
        echo "⚠️  RESULT: Serial OK, need Bluetooth pairing"
    else
        echo "❌ Serial communication: FAILED"
        echo "❌ ESP32 not responding to commands"
        echo ""
        echo "❌ RESULT: ESP32 serial communication failed"
    fi
    
else
    echo "❌ SERIAL COMMUNICATION FAILED"
    echo ""
    echo "ESP32 not responding to STATUS/RESET commands"
    echo ""
    echo "TROUBLESHOOTING:"
    echo "1. Check ESP32 is powered and running"
    echo "2. Verify main.ino uploaded correctly"
    echo "3. Check serial connection: screen $ESP32_DEVICE 115200"
    echo "4. Try different USB cable/port"
    echo "5. Check ESP32 is not in bootloader mode"
    echo "6. Verify baud rate is 115200"
    echo ""
    echo "❌ RESULT: ESP32 hardware/firmware issue"
fi

echo ""
echo "=============================================="
echo "SUMMARY & NEXT STEPS:"
echo "=============================================="
echo ""
if [ "$before_connected" = "y" ] && [ "$still_connected" = "y" ] && [ "$status_working" = "y" ]; then
    echo "✅ This test proves ESP32 serial communication works"
    echo "✅ This test proves Bluetooth can stay stable"
    echo "⚠️  The original test4 fails because CLICK/MOVE commands cause disconnection"
    echo ""
    echo "RECOMMENDATIONS:"
    echo "1. Use this minimal test for communication verification"
    echo "2. Only test mouse movements when absolutely necessary"
    echo "3. Consider modifying ESP32 code to have a 'test mode' that doesn't move mouse"
    echo "4. For full system testing, accept that Bluetooth may disconnect"
else
    echo "❌ Issues found - fix these before proceeding:"
    [ "$status_working" = "n" ] && echo "  - ESP32 not responding to serial commands"
    [ "$before_connected" = "n" ] && echo "  - iPhone not paired with ESP32"
    [ "$still_connected" = "n" ] && [ "$before_connected" = "y" ] && echo "  - Bluetooth connection unstable"
fi

echo "=============================================="
