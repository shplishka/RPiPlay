#!/bin/bash

# TEST 2: Check devices and permissions
# Copy this script to Raspberry Pi and run: bash test2_check_devices.sh

echo "=============================================="
echo "  TEST 2: Checking Devices and Permissions"
echo "=============================================="
echo ""

# Check ESP32 device
ESP32_DEVICE="/dev/ttyUSB0"
echo "Checking ESP32 device: $ESP32_DEVICE"

if [ -e "$ESP32_DEVICE" ]; then
    echo "✓ ESP32 device exists"
    
    if [ -w "$ESP32_DEVICE" ]; then
        echo "✓ ESP32 device writable"
        ESP32_OK=true
    else
        echo "❌ ESP32 device not writable"
        echo "Fixing permissions..."
        sudo chmod 666 "$ESP32_DEVICE"
        if [ -w "$ESP32_DEVICE" ]; then
            echo "✓ ESP32 permissions fixed"
            ESP32_OK=true
        else
            echo "❌ Still cannot write to ESP32"
            ESP32_OK=false
        fi
    fi
else
    echo "❌ ESP32 device not found"
    echo "Available serial devices:"
    ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "None found"
    ESP32_OK=false
fi

echo ""

# Check touch input devices
echo "Checking touch input devices:"
echo "Available input devices:"
ls /dev/input/event* 2>/dev/null || echo "No input devices found"

echo ""
echo "Testing touch devices for readability:"
for device in /dev/input/event*; do
    if [ -e "$device" ]; then
        if [ -r "$device" ]; then
            echo "✓ $device readable"
        else
            echo "❌ $device not readable"
            echo "Fixing permissions for $device..."
            sudo chmod 666 "$device"
        fi
    fi
done

echo ""

# Check user groups
echo "User groups: $(groups)"
if groups | grep -q "input"; then
    echo "✓ User in 'input' group"
else
    echo "❌ User NOT in 'input' group"
    echo "Adding to input group..."
    sudo usermod -a -G input $USER
    echo "⚠  Reboot required after group change"
fi

if groups | grep -q "dialout"; then
    echo "✓ User in 'dialout' group"
else
    echo "❌ User NOT in 'dialout' group"
    echo "Adding to dialout group..."
    sudo usermod -a -G dialout $USER
    echo "⚠  Reboot required after group change"
fi

echo ""

# Test specific devices we plan to use
TOUCH_DEVICE="/dev/input/event4"
echo "Testing our target devices:"
echo "ESP32: $ESP32_DEVICE"
echo "Touch: $TOUCH_DEVICE"

echo ""
if [ -e "$TOUCH_DEVICE" ] && [ -r "$TOUCH_DEVICE" ]; then
    echo "✓ Touch device $TOUCH_DEVICE ready"
    TOUCH_OK=true
else
    echo "❌ Touch device $TOUCH_DEVICE not ready"
    echo "Try other devices:"
    for dev in /dev/input/event*; do
        if [ -e "$dev" ] && [ -r "$dev" ]; then
            echo "  Alternative: $dev"
        fi
    done
    TOUCH_OK=false
fi

echo ""
echo "=============================================="
if [ "$ESP32_OK" = true ] && [ "$TOUCH_OK" = true ]; then
    echo "✅ RESULT: Devices and permissions OK!"
    echo "Proceed to test3_test_touch_raw.sh"
else
    echo "❌ RESULT: Device or permission issues found"
    echo ""
    echo "SOLUTIONS:"
    echo "1. Fix permissions: sudo chmod 666 /dev/input/event* /dev/ttyUSB*"
    echo "2. Add to groups: sudo usermod -a -G input,dialout $USER"
    echo "3. Reboot after group changes: sudo reboot"
    echo "4. Check device connections"
fi
echo "==============================================" 