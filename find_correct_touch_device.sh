#!/bin/bash

# Find the correct touch device that supports absolute positioning
# This script will identify which /dev/input/eventX device is your touchscreen

echo "=========================================="
echo "  Finding Touch Device with Absolute Positioning"
echo "=========================================="
echo ""

# Check if evtest is available
if ! command -v evtest >/dev/null 2>&1; then
    echo "Installing evtest for device testing..."
    sudo apt update && sudo apt install -y evtest
fi

echo "Scanning all input devices for touch capabilities..."
echo ""

touch_devices=()

for device in /dev/input/event*; do
    if [ -e "$device" ]; then
        echo "Testing $device..."
        
        # Get device info with timeout
        device_info=$(timeout 3 evtest "$device" 2>/dev/null | head -20 || true)
        
        if [ -n "$device_info" ]; then
            device_name=$(echo "$device_info" | grep "Input device name" | cut -d'"' -f2)
            echo "  Device name: $device_name"
            
            # Check for absolute positioning capabilities
            has_abs_x=$(echo "$device_info" | grep -c "ABS_X" || true)
            has_abs_y=$(echo "$device_info" | grep -c "ABS_Y" || true)
            has_btn_touch=$(echo "$device_info" | grep -c "BTN_TOUCH\|BTN_LEFT" || true)
            
            # Check for touch-related keywords in device name
            is_touch_name=$(echo "$device_name" | grep -ic "touch\|finger\|screen\|tablet" || true)
            
            echo "    ABS_X support: $has_abs_x"
            echo "    ABS_Y support: $has_abs_y" 
            echo "    Touch button: $has_btn_touch"
            echo "    Touch-related name: $is_touch_name"
            
            # Score the device
            score=$((has_abs_x + has_abs_y + has_btn_touch + is_touch_name))
            
            if [ $has_abs_x -gt 0 ] && [ $has_abs_y -gt 0 ]; then
                echo "  ✅ POTENTIAL TOUCH DEVICE (score: $score)"
                touch_devices+=("$device:$score:$device_name")
            else
                echo "  ❌ Not a touch device (no absolute positioning)"
            fi
        else
            echo "  ❌ Cannot access device (permission issue?)"
        fi
        echo ""
    fi
done

echo "=========================================="
echo "  Results"
echo "=========================================="

if [ ${#touch_devices[@]} -eq 0 ]; then
    echo "❌ No touch devices found with absolute positioning support!"
    echo ""
    echo "Possible solutions:"
    echo "1. Check if touchscreen is properly connected"
    echo "2. Check device permissions: sudo chmod 666 /dev/input/event*"
    echo "3. Add user to input group: sudo usermod -a -G input \$USER"
    echo "4. Reboot system to apply changes"
    exit 1
fi

echo "Found ${#touch_devices[@]} potential touch device(s):"
echo ""

# Sort by score (highest first)
IFS=$'\n' sorted_devices=($(printf '%s\n' "${touch_devices[@]}" | sort -t: -k2 -nr))

best_device=""
best_score=0

for device_info in "${sorted_devices[@]}"; do
    device=$(echo "$device_info" | cut -d: -f1)
    score=$(echo "$device_info" | cut -d: -f2)
    name=$(echo "$device_info" | cut -d: -f3-)
    
    echo "  $device (score: $score) - $name"
    
    if [ $score -gt $best_score ]; then
        best_device="$device"
        best_score=$score
    fi
done

echo ""
echo "=========================================="
echo "  Recommendation"
echo "=========================================="
echo ""
echo "Best touch device: $best_device"
echo ""

# Test the best device
if [ -n "$best_device" ]; then
    echo "Testing $best_device for 5 seconds..."
    echo "Touch the screen now to see if it generates events:"
    echo ""
    
    timeout 5 evtest "$best_device" 2>/dev/null | grep -E "EV_ABS|EV_KEY|ABS_X|ABS_Y|BTN_TOUCH" | head -10 || {
        echo "No events detected. Try touching the screen or check device permissions."
    }
    
    echo ""
    echo "=========================================="
    echo "  Updated Command"
    echo "=========================================="
    echo ""
    echo "Use this device in your RPiPlay command:"
    echo "rpiplay -esp32 /dev/ttyUSB0 -touch $best_device -iphone 390x844 -rpi 800x480"
    echo ""
    
    # Update the debug scripts
    echo "Updating debug scripts to use $best_device..."
    
    # Update debug_touch_step_by_step.sh
    if [ -f "debug_touch_step_by_step.sh" ]; then
        sed -i "s|TOUCH_DEVICE=\"/dev/input/event[0-9]*\"|TOUCH_DEVICE=\"$best_device\"|" debug_touch_step_by_step.sh
        echo "✅ Updated debug_touch_step_by_step.sh"
    fi
    
    # Update rebuild_rpiplay.sh
    if [ -f "rebuild_rpiplay.sh" ]; then
        sed -i "s|/dev/input/event[0-9]*|$best_device|g" rebuild_rpiplay.sh
        echo "✅ Updated rebuild_rpiplay.sh"
    fi
    
    # Update fix_touch_debug.sh
    if [ -f "fix_touch_debug.sh" ]; then
        sed -i "s|TOUCH_DEVICE=\"/dev/input/event[0-9]*\"|TOUCH_DEVICE=\"$best_device\"|" fix_touch_debug.sh
        echo "✅ Updated fix_touch_debug.sh"
    fi
    
    echo ""
    echo "✅ Scripts updated! You can now run:"
    echo "   ./fix_touch_debug.sh"
    echo ""
fi
