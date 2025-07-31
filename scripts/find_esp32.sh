#!/bin/bash

# Script to find ESP32 USB device path
# Usage: ./find_esp32.sh

echo "🔍 Searching for ESP32 USB device..."

# Common ESP32 USB-to-Serial chip vendor IDs
ESP32_VENDOR_IDS=(
    "10c4"  # Silicon Labs CP210x (CP2102, CP2104)
    "1a86"  # QinHeng Electronics CH340/CH341
    "0403"  # FTDI FT232
    "067b"  # Prolific PL2303
)

# Function to check if a device is likely an ESP32
check_esp32_device() {
    local device=$1
    
    # Try to get device info
    if command -v udevadm >/dev/null 2>&1; then
        local info=$(udevadm info -a -n "$device" 2>/dev/null)
        
        # Check for common ESP32 identifiers
        if echo "$info" | grep -i -E "(cp210|ch340|ft232|esp|silicon labs)" >/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Look for USB serial devices
ESP32_DEVICES=()

for device in /dev/ttyUSB* /dev/ttyACM*; do
    if [ -e "$device" ]; then
        if check_esp32_device "$device"; then
            ESP32_DEVICES+=("$device")
            echo "✅ Found potential ESP32 device: $device"
        else
            echo "ℹ️  Found serial device: $device (unknown type)"
        fi
    fi
done

# If no devices found by vendor ID, list all available serial devices
if [ ${#ESP32_DEVICES[@]} -eq 0 ]; then
    echo ""
    echo "⚠️  No ESP32-like devices detected by vendor ID."
    echo "📋 Available serial devices:"
    
    for device in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -e "$device" ]; then
            echo "   $device"
            ESP32_DEVICES+=("$device")
        fi
    done
fi

echo ""
echo "🎯 ESP32 Detection Results:"
echo "=========================="

if [ ${#ESP32_DEVICES[@]} -eq 0 ]; then
    echo "❌ No USB serial devices found!"
    echo ""
    echo "💡 Troubleshooting steps:"
    echo "   1. Make sure ESP32 is connected via USB"
    echo "   2. Check if USB cable supports data (not just power)"
    echo "   3. Try a different USB port"
    echo "   4. Run: dmesg | tail -10"
    exit 1
    
elif [ ${#ESP32_DEVICES[@]} -eq 1 ]; then
    echo "✅ Single device found: ${ESP32_DEVICES[0]}"
    echo ""
    echo "🚀 Use this command:"
    echo "   rpiplay -esp32 ${ESP32_DEVICES[0]} -touch /dev/input/event0"
    
else
    echo "⚠️  Multiple devices found:"
    for i in "${!ESP32_DEVICES[@]}"; do
        echo "   $((i+1)). ${ESP32_DEVICES[i]}"
    done
    echo ""
    echo "💡 To identify your ESP32:"
    echo "   1. Unplug ESP32"
    echo "   2. Run: ls /dev/ttyUSB* /dev/ttyACM*"
    echo "   3. Plug in ESP32"
    echo "   4. Run: ls /dev/ttyUSB* /dev/ttyACM*"
    echo "   5. The new device is your ESP32"
    echo ""
    echo "🚀 Try each device:"
    for device in "${ESP32_DEVICES[@]}"; do
        echo "   rpiplay -esp32 $device -touch /dev/input/event0"
    done
fi

echo ""
echo "🔧 Additional Info:"
echo "=================="
echo "📊 USB devices (lsusb):"
lsusb | grep -i -E "(cp210|ch340|ft232|silicon|prolific|qinheng)" || echo "   (No obvious ESP32 USB chips found)"

echo ""
echo "📝 Recent USB activity (dmesg):"
dmesg | tail -5 | grep -i -E "(usb|tty)" || echo "   (No recent USB activity)" 