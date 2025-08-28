#!/bin/bash

# TEST 4: Test ESP32 communication
# Copy this script to Raspberry Pi and run: bash test4_test_esp32.sh

echo "=============================================="
echo "  TEST 4: Testing ESP32 Communication"
echo "=============================================="
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

# Send test commands
echo "Sending test commands to ESP32..."
echo "You should monitor ESP32 serial output (115200 baud) to see responses"
echo ""

# Send STATUS command
echo "Sending: STATUS"
echo "STATUS" > "$ESP32_DEVICE"
sleep 1

# Send RESET command  
echo "Sending: RESET"
echo "RESET" > "$ESP32_DEVICE"
sleep 1

# Send test click command
echo "Sending: CLICK,100,200"
echo "CLICK,100,200" > "$ESP32_DEVICE"
sleep 1

# Send test scroll command
echo "Sending: SCROLL,1,3"
echo "SCROLL,1,3" > "$ESP32_DEVICE"
sleep 1

echo ""
echo "Commands sent successfully!"
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
echo "Current Position: (x,y)"
echo "Target Position: (x,y)"
echo "================="
echo ""
echo "📥 Command: RESET"
echo "🔄 Reset command received (no position tracking in this version)"
echo ""
echo "📥 Command: CLICK,100,200"
echo "👆 Click at (100,200)"
echo ""

echo "=============================================="
echo "MANUAL VERIFICATION:"
echo "=============================================="
echo ""
echo "Please check the ESP32 serial monitor and answer:"
echo ""

read -p "Did ESP32 respond to STATUS command? (y/n): " status_response
read -p "Did ESP32 respond to RESET command? (y/n): " reset_response  
read -p "Did ESP32 respond to CLICK command? (y/n): " click_response

echo ""

if [ "$status_response" = "y" ] && [ "$reset_response" = "y" ] && [ "$click_response" = "y" ]; then
    echo "✅ SUCCESS: ESP32 communication WORKING!"
    echo ""
    echo "ESP32 setup checklist:"
    echo "✓ ESP32 receives serial commands"
    echo "□ ESP32 programmed with main.ino code"
    echo "□ iPhone paired with ESP32 Bluetooth ('iPhone Remote')"
    echo "□ ESP32 LED on when iPhone connected"
    echo ""
    echo "✅ RESULT: ESP32 communication OK!"
    echo "Proceed to test5_test_rpiplay_init.sh"
    
elif [ "$status_response" = "y" ] || [ "$reset_response" = "y" ] || [ "$click_response" = "y" ]; then
    echo "⚠ PARTIAL: ESP32 partially responding"
    echo ""
    echo "Some commands work, others don't. Check:"
    echo "1. ESP32 code (main.ino) uploaded correctly"
    echo "2. Serial connection stable"
    echo "3. ESP32 not resetting/crashing"
    echo ""
    echo "⚠ RESULT: ESP32 communication PARTIAL"
    echo "Fix issues before proceeding"
    
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
    echo "Fix ESP32 before proceeding"
fi

echo "==============================================" 