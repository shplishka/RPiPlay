#!/bin/bash

# TEST 4 SAFE: Test ESP32 communication WITHOUT triggering mouse movements
# Copy this script to Raspberry Pi and run: bash test4_test_esp32_safe.sh

echo "=============================================="
echo "  TEST 4 SAFE: Testing ESP32 Communication"
echo "=============================================="
echo ""
echo "⚠️  This version only tests communication"
echo "⚠️  No mouse movements will be triggered"
echo "⚠️  Bluetooth connection should remain stable"
echo ""

ESP32_DEVICE="/dev/ttyUSB0"

echo "Testing ESP32 communication on: $ESP32_DEVICE"
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
            echo "  Use $dev instead of $ESP32_DEVICE"
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

# Send SAFE test commands (no mouse movements)
echo "Sending SAFE test commands to ESP32..."
echo "These commands will NOT trigger mouse movements"
echo ""

# Send STATUS command (always safe)
echo "Sending: STATUS"
echo "STATUS" > "$ESP32_DEVICE"
sleep 1

# Send RESET command (safe - no actual movements in this version)
echo "Sending: RESET"
echo "RESET" > "$ESP32_DEVICE"
sleep 1

# Send SCREEN command (safe - just sets resolution)
echo "Sending: SCREEN,1170,2532"
echo "SCREEN,1170,2532" > "$ESP32_DEVICE"
sleep 1

# Send another STATUS to verify ESP32 is still responding
echo "Sending: STATUS (verification)"
echo "STATUS" > "$ESP32_DEVICE"
sleep 1

echo ""
echo "Safe commands sent successfully!"
echo ""

# Instructions for checking ESP32 response
echo "=============================================="
echo "CHECK ESP32 SERIAL OUTPUT:"
echo "=============================================="
echo ""
echo "Open ESP32 serial monitor at 115200 baud to see responses:"
echo "1. Using screen: screen $ESP32_DEVICE 115200"
echo "   (Press Ctrl+A then K to exit)"
echo ""
echo "2. Using minicom: minicom -D $ESP32_DEVICE -b 115200"
echo ""
echo "3. Using Arduino IDE serial monitor"
echo ""

echo "Expected ESP32 responses:"
echo "📥 Command: STATUS"
echo "📊 === STATUS ==="
echo "Connection: ✅ Connected OR ❌ Disconnected"
echo "Base Screen: 1170x2532"
echo "================="
echo ""
echo "📥 Command: RESET"
echo "🔄 Reset command received (no position tracking in this version)"
echo ""
echo "📥 Command: SCREEN,1170,2532"
echo "📱 Base screen set to: 1170x2532"
echo "📱 ESP32 receives pre-scaled coordinates from Python"
echo ""

echo "=============================================="
echo "MANUAL VERIFICATION:"
echo "=============================================="
echo ""
echo "Please check the ESP32 serial monitor and answer:"
echo ""

read -p "Did ESP32 respond to first STATUS command? (y/n): " status1_response
read -p "Did ESP32 respond to RESET command? (y/n): " reset_response  
read -p "Did ESP32 respond to SCREEN command? (y/n): " screen_response
read -p "Did ESP32 respond to second STATUS command? (y/n): " status2_response
read -p "Is iPhone still connected to ESP32 Bluetooth? (y/n): " bluetooth_response

echo ""

# Count successful responses
success_count=0
if [ "$status1_response" = "y" ]; then ((success_count++)); fi
if [ "$reset_response" = "y" ]; then ((success_count++)); fi
if [ "$screen_response" = "y" ]; then ((success_count++)); fi
if [ "$status2_response" = "y" ]; then ((success_count++)); fi

if [ $success_count -eq 4 ] && [ "$bluetooth_response" = "y" ]; then
    echo "✅ SUCCESS: ESP32 communication WORKING!"
    echo "✅ Bluetooth connection STABLE!"
    echo ""
    echo "ESP32 setup checklist:"
    echo "✓ ESP32 receives serial commands"
    echo "✓ ESP32 programmed with main.ino code"
    echo "✓ iPhone paired with ESP32 Bluetooth ('ESP32 Mouse')"
    echo "✓ ESP32 LED on when iPhone connected"
    echo "✓ Bluetooth connection remains stable during testing"
    echo ""
    echo "✅ RESULT: ESP32 communication OK!"
    echo "Proceed to test5_test_rpiplay_init.sh"
    
elif [ $success_count -ge 3 ] && [ "$bluetooth_response" = "y" ]; then
    echo "⚠ MOSTLY WORKING: ESP32 mostly responding"
    echo "✅ Bluetooth connection STABLE!"
    echo ""
    echo "ESP32 responds to most commands. Minor issues may exist."
    echo "✅ RESULT: ESP32 communication MOSTLY OK"
    echo "Can proceed to test5_test_rpiplay_init.sh"
    
elif [ $success_count -ge 2 ] && [ "$bluetooth_response" = "n" ]; then
    echo "⚠ BLUETOOTH ISSUE: ESP32 responding but Bluetooth disconnected"
    echo ""
    echo "ESP32 serial communication works, but Bluetooth is unstable."
    echo "This suggests the issue is with BLE mouse movements, not serial communication."
    echo ""
    echo "SOLUTIONS:"
    echo "1. Keep iPhone closer to ESP32"
    echo "2. Check iPhone Bluetooth settings"
    echo "3. Restart ESP32 and re-pair"
    echo "4. Avoid sending CLICK/MOVE commands during testing"
    echo ""
    echo "⚠ RESULT: Communication OK, but Bluetooth unstable"
    
elif [ "$bluetooth_response" = "n" ]; then
    echo "❌ BLUETOOTH DISCONNECTED during test"
    echo ""
    echo "This confirms the issue: certain commands cause Bluetooth disconnection"
    echo ""
    echo "TROUBLESHOOTING:"
    echo "1. Re-pair iPhone with ESP32"
    echo "2. Use only this SAFE test version"
    echo "3. Avoid the original test4_test_esp32.sh"
    echo "4. Check if CLICK/MOVE commands are being sent elsewhere"
    echo ""
    echo "❌ RESULT: Bluetooth connection unstable"
    
else
    echo "❌ FAILED: ESP32 not responding to commands"
    echo ""
    echo "TROUBLESHOOTING:"
    echo "1. Check ESP32 is powered and running"
    echo "2. Verify main.ino code is uploaded to ESP32"
    echo "3. Check serial connection:"
    echo "   screen $ESP32_DEVICE 115200"
    echo "4. Check for correct ESP32 device:"
    for dev in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -e "$dev" ]; then
            echo "   Try: $dev"
        fi
    done
    echo "5. Check ESP32 is not in bootloader mode"
    echo "6. Try different USB cable/port"
    echo ""
    echo "❌ RESULT: ESP32 communication FAILED!"
fi

echo ""
echo "=============================================="
echo "NEXT STEPS:"
echo "=============================================="
echo ""
echo "If this SAFE test works but the original test4 fails:"
echo "  → The issue is confirmed: CLICK/MOVE commands cause disconnection"
echo "  → Use this safe version for testing communication"
echo "  → Only test actual mouse movements when iPhone is ready"
echo ""
echo "If both tests fail:"
echo "  → Check ESP32 hardware and code upload"
echo "  → Verify serial connection and permissions"
echo ""
echo "If Bluetooth keeps disconnecting:"
echo "  → Keep devices closer together"
echo "  → Check iPhone power management settings"
echo "  → Consider BLE connection parameters in ESP32 code"
echo "=============================================="
