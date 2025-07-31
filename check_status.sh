#!/bin/bash

# Check RPiPlay Touch Control Setup Status
# Shows current status and guides next steps

echo "=============================================="
echo "  RPiPlay Touch Control - Status Check"
echo "=============================================="
echo ""

echo "Checking your current setup..."
echo ""

# Check if RPiPlay has touch support
echo "1. RPIPLAY STATUS:"
if command -v rpiplay >/dev/null; then
    if rpiplay -h 2>/dev/null | grep -q "touch"; then
        echo "✅ RPiPlay with touch support installed"
        RPIPLAY_OK=true
    else
        echo "❌ RPiPlay found but no touch support"
        echo "   Need to rebuild with: bash rebuild_rpiplay.sh"
        RPIPLAY_OK=false
    fi
else
    echo "❌ RPiPlay not found"
    echo "   Need to install first"
    RPIPLAY_OK=false
fi

echo ""

# Check ESP32 device
echo "2. ESP32 CONNECTION:"
if [ -e "/dev/ttyUSB0" ]; then
    if [ -w "/dev/ttyUSB0" ]; then
        echo "✅ ESP32 connected and writable at /dev/ttyUSB0"
        ESP32_OK=true
    else
        echo "⚠️  ESP32 found but no write permission"
        echo "   Run: sudo chmod 666 /dev/ttyUSB0"
        ESP32_OK=false
    fi
else
    echo "❌ ESP32 not found at /dev/ttyUSB0"
    echo "   Check USB connection and ESP32 programming"
    ESP32_OK=false
fi

echo ""

# Check touch device
echo "3. TOUCH DEVICE:"
TOUCH_DEVICES=$(ls /dev/input/event* 2>/dev/null | head -5)
if [ -n "$TOUCH_DEVICES" ]; then
    echo "✅ Touch input devices found:"
    for device in $TOUCH_DEVICES; do
        if [ -r "$device" ]; then
            echo "   $device (readable ✅)"
        else
            echo "   $device (not readable ❌)"
        fi
    done
    TOUCH_OK=true
else
    echo "❌ No touch input devices found"
    TOUCH_OK=false
fi

echo ""

# Check existing launch scripts
echo "4. LAUNCH SCRIPTS:"
echo ""

if [ -f ~/launch_rpiplay_calibrated.sh ]; then
    echo "✅ ~/launch_rpiplay_calibrated.sh (FULLY CALIBRATED - READY TO USE!)"
    CALIBRATED=true
elif [ -f ~/launch_rpiplay_rotated.sh ]; then
    echo "✅ ~/launch_rpiplay_rotated.sh (has rotation support)"
    echo "❌ ~/launch_rpiplay_calibrated.sh (not created yet - need calibration)"
    CALIBRATED=false
elif [ -f ~/launch_rpiplay_touch.sh ]; then
    echo "✅ ~/launch_rpiplay_touch.sh (basic touch support)"
    echo "❌ ~/launch_rpiplay_calibrated.sh (not created yet - need calibration)"
    CALIBRATED=false
else
    echo "❌ No launch scripts found"
    CALIBRATED=false
fi

# Check display issues
echo ""
echo "5. DISPLAY STATUS:"
CURRENT_RES=$(fbset 2>/dev/null | grep geometry | awk '{print $2"x"$3}' || echo "unknown")
GPU_MEM=$(vcgencmd get_mem gpu 2>/dev/null | cut -d= -f2 || echo "unknown")
echo "Resolution: $CURRENT_RES"
echo "GPU Memory: $GPU_MEM"

echo ""
echo "=============================================="
echo "STATUS SUMMARY:"
echo "=============================================="
echo ""

if [ "$RPIPLAY_OK" = true ] && [ "$ESP32_OK" = true ] && [ "$TOUCH_OK" = true ]; then
    echo "🎉 GOOD NEWS: All hardware is working!"
    echo ""
    
    if [ "$CALIBRATED" = true ]; then
        echo "🎯 PERFECT! You have the fully calibrated system!"
        echo ""
        echo "START YOUR CALIBRATED SYSTEM:"
        echo "  ~/launch_rpiplay_calibrated.sh"
        echo ""
    else
        echo "📋 NEXT STEPS: You need to run the calibration process"
        echo ""
        echo "OPTION 1 - Complete setup (recommended):"
        echo "  bash fix_all_issues.sh"
        echo ""
        echo "OPTION 2 - Just calibration:"
        echo "  bash calibrate_touch.sh"
        echo ""
        echo "This will create ~/launch_rpiplay_calibrated.sh"
    fi
    
else
    echo "⚠️  ISSUES FOUND - Need to fix first:"
    echo ""
    
    if [ "$RPIPLAY_OK" = false ]; then
        echo "• Fix RPiPlay: bash rebuild_rpiplay.sh"
    fi
    
    if [ "$ESP32_OK" = false ]; then
        echo "• Fix ESP32 connection and permissions"
    fi
    
    if [ "$TOUCH_OK" = false ]; then   
        echo "• Fix touch device permissions"
    fi
    
    echo ""
    echo "Then run: bash fix_all_issues.sh"
fi

echo ""
echo "=============================================="
echo "QUICK START GUIDE:"
echo "=============================================="
echo ""

if [ "$CALIBRATED" = true ]; then
    echo "🚀 YOU'RE READY! Just run:"
    echo "   ~/launch_rpiplay_calibrated.sh"
    echo ""
    echo "This will start your perfectly calibrated touch control!"
    
elif [ "$RPIPLAY_OK" = true ] && [ "$ESP32_OK" = true ] && [ "$TOUCH_OK" = true ]; then
    echo "🔧 ALMOST READY! Run the setup process:"
    echo ""
    echo "   bash fix_all_issues.sh"
    echo ""
    echo "This will:"
    echo "1. Fix display issues (reboot required)"
    echo "2. Fix rotation (reboot required)"  
    echo "3. Calibrate touch coordinates"
    echo "4. Create ~/launch_rpiplay_calibrated.sh"
    echo ""
    echo "After setup, use:"
    echo "   ~/launch_rpiplay_calibrated.sh"
    
else
    echo "🛠️  NEED FIXES FIRST:"
    echo ""
    echo "1. Make sure RPiPlay has touch support:"
    echo "   bash rebuild_rpiplay.sh"
    echo ""
    echo "2. Fix hardware connections"
    echo ""
    echo "3. Then run complete setup:"
    echo "   bash fix_all_issues.sh"
fi

echo ""
echo "=============================================="

# Offer quick actions
echo ""
read -p "What would you like to do now? (1=Check launch scripts, 2=Run calibration, 3=Complete setup, Enter=Exit): " action

case $action in
    1)
        echo ""
        echo "Available launch scripts:"
        ls -la ~/*rpiplay*.sh 2>/dev/null || echo "No launch scripts found"
        ;;
    2)
        if [ "$RPIPLAY_OK" = true ] && [ "$ESP32_OK" = true ] && [ "$TOUCH_OK" = true ]; then
            echo ""
            echo "Starting calibration..."
            bash calibrate_touch.sh
        else
            echo ""
            echo "❌ Cannot calibrate - fix hardware issues first"
        fi
        ;;
    3)
        echo ""
        echo "Starting complete setup..."
        bash fix_all_issues.sh
        ;;
    *)
        echo ""
        echo "Run this script anytime to check status:"
        echo "  bash check_status.sh"
        ;;
esac 