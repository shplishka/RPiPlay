#!/bin/bash

# TEST 4 STATUS ONLY: Test ESP32 with ONLY STATUS command
# STATUS is the ONLY command that doesn't call bleMouse.isConnected()
# Copy this script to Raspberry Pi and run: bash test4_test_esp32_status_only.sh

echo "=============================================="
echo "  TEST 4 STATUS ONLY: ESP32 Pure Serial Test"
echo "=============================================="
echo ""
echo "🔒 ULTRA-MINIMAL: Only STATUS command"
echo "🔒 STATUS bypasses ALL BLE connection checks"
echo "🔒 This should NOT cause any Bluetooth disconnection"
echo ""

ESP32_DEVICE="/dev/ttyUSB0"

echo "Testing ESP32 with STATUS command only on: $ESP32_DEVICE"
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

echo "=============================================="
echo "CRITICAL TEST: STATUS COMMAND ONLY"
echo "=============================================="
echo ""
echo "STATUS is the ONLY command that bypasses BLE connection checks."
echo "If this causes disconnection, the issue is deeper than command processing."
echo ""

# Send ONLY STATUS commands with delays
echo "Test 1/3: Sending first STATUS command..."
echo "STATUS" > "$ESP32_DEVICE"
sleep 3

echo "Test 2/3: Sending second STATUS command..."
echo "STATUS" > "$ESP32_DEVICE"
sleep 3

echo "Test 3/3: Sending third STATUS command..."
echo "STATUS" > "$ESP32_DEVICE"
sleep 3

echo ""
echo "✅ All STATUS commands sent!"
echo ""

# Instructions
echo "=============================================="
echo "CHECK ESP32 SERIAL OUTPUT:"
echo "=============================================="
echo ""
echo "Open ESP32 serial monitor at 115200 baud:"
echo "  screen $ESP32_DEVICE 115200"
echo "  (Press Ctrl+A then K to exit)"
echo ""

echo "Expected ESP32 responses (should see 3 identical responses):"
echo ""
echo "📥 Command: STATUS"
echo "📊 === STATUS ==="
echo "🔗 Connection: ✅ Connected OR ❌ Disconnected"
echo "📱 Base Screen: 1170x2532"
echo "📱 Actual BLE: 1170x2532"
echo "📏 ESP32 Scale: 1.0 (coordinates pre-scaled by Python)"
echo "🔋 Free Heap: XXXXX bytes"
echo "💡 Note: This version uses home-based absolute positioning"
echo "💡 No position tracking - each move starts from (0,0)"
echo "================="
echo ""

echo "=============================================="
echo "BLUETOOTH CONNECTION TEST:"
echo "=============================================="
echo ""

read -p "BEFORE test: Was iPhone connected to ESP32 Bluetooth? (y/n): " before_connected
read -p "Did ESP32 respond to all 3 STATUS commands? (y/n): " status_working
read -p "RIGHT NOW: Is iPhone still connected to ESP32 Bluetooth? (y/n): " still_connected

echo ""

if [ "$before_connected" = "y" ] && [ "$still_connected" = "y" ] && [ "$status_working" = "y" ]; then
    echo "🎉 PERFECT! STATUS-only test PASSED!"
    echo "✅ Serial communication: WORKING"
    echo "✅ Bluetooth connection: STABLE"
    echo "✅ ESP32 responds to STATUS commands"
    echo ""
    echo "🔍 DIAGNOSIS CONFIRMED:"
    echo "  ✅ STATUS command is safe (bypasses BLE checks)"
    echo "  ❌ RESET command causes disconnection (calls bleMouse.isConnected())"
    echo "  ❌ All other commands cause disconnection (call bleMouse.isConnected())"
    echo ""
    echo "🔧 ROOT CAUSE:"
    echo "  The bleMouse.isConnected() call in handleCommand() is interfering"
    echo "  with the BLE connection stability."
    echo ""
    echo "✅ RESULT: Pure serial communication works perfectly!"
    
elif [ "$before_connected" = "y" ] && [ "$still_connected" = "n" ]; then
    echo "❌ CRITICAL: Even STATUS command caused disconnection!"
    echo ""
    echo "This is a deeper issue than command processing."
    echo ""
    echo "POSSIBLE CAUSES:"
    echo "1. Serial communication itself interferes with BLE"
    echo "2. ESP32 BLE stack has stability issues"
    echo "3. iPhone aggressively disconnects during any activity"
    echo "4. Hardware interference between USB serial and BLE radio"
    echo "5. Power supply issues affecting ESP32 stability"
    echo ""
    echo "ADVANCED TROUBLESHOOTING:"
    echo "1. Try with ESP32 powered from external supply (not USB)"
    echo "2. Use different ESP32 board"
    echo "3. Check BLE connection parameters in ESP32 code"
    echo "4. Try shorter delays between commands"
    echo "5. Monitor ESP32 with oscilloscope for power issues"
    echo ""
    echo "❌ RESULT: Fundamental BLE stability issue"
    
elif [ "$status_working" = "y" ] && [ "$before_connected" = "n" ]; then
    echo "⚠️  Serial communication works, but no Bluetooth pairing"
    echo "✅ Serial communication: WORKING"
    echo "❌ Bluetooth pairing: NOT ESTABLISHED"
    echo ""
    echo "NEXT STEPS:"
    echo "1. Pair iPhone with ESP32 via Bluetooth"
    echo "2. Look for 'ESP32 Mouse' in iPhone Settings > Bluetooth"
    echo "3. Re-run this test after successful pairing"
    echo ""
    echo "⚠️  RESULT: Need to establish Bluetooth pairing first"
    
else
    echo "❌ ESP32 not responding to STATUS commands"
    echo ""
    echo "BASIC TROUBLESHOOTING:"
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
echo "TECHNICAL ANALYSIS:"
echo "=============================================="
echo ""
echo "ESP32 Code Analysis:"
echo "• STATUS command: Safe (lines 206-209, bypasses BLE checks)"
echo "• RESET command: Unsafe (lines 274-277, calls bleMouse.isConnected())"
echo "• All other commands: Unsafe (line 212-215, call bleMouse.isConnected())"
echo ""
echo "The bleMouse.isConnected() function call appears to interfere"
echo "with BLE connection stability, causing iPhone to disconnect."
echo ""
echo "SOLUTION OPTIONS:"
echo "1. Modify ESP32 code to remove BLE connection checks"
echo "2. Use only STATUS command for communication testing"
echo "3. Accept that mouse commands will cause disconnection"
echo "4. Implement a 'test mode' that disables BLE checks"
echo ""
echo "=============================================="
