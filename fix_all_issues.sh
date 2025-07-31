#!/bin/bash

# Fix All RPiPlay Touch Control Issues
# Master script to fix display, rotation, and touch calibration

echo "=============================================="
echo "  RPiPlay Touch Control - Fix All Issues"
echo "=============================================="
echo ""

echo "🎉 Congratulations! Your touch control system is working!"
echo ""
echo "Now let's fix the remaining issues you mentioned:"
echo "1. Bad resolution and alpha-style colors"
echo "2. Screen needs 90° rotation for full screen"
echo "3. Touch positions don't match iPhone positions"
echo ""

echo "We'll fix these issues in order:"
echo ""
echo "STEP 1: Fix display resolution and colors"
echo "STEP 2: Fix screen rotation"  
echo "STEP 3: Calibrate touch coordinates"
echo ""

read -p "Ready to start fixing issues? Press Enter..."

echo ""
echo "=============================================="
echo "STEP 1: FIXING DISPLAY ISSUES"
echo "=============================================="
echo ""
echo "This will fix:"
echo "✓ Bad resolution"
echo "✓ Alpha-style colors/transparency issues"
echo "✓ Color depth problems"
echo "✓ GPU memory allocation"
echo ""

read -p "Fix display issues now? (y/n): " fix_display

if [ "$fix_display" = "y" ]; then
    if [ -f "fix_display.sh" ]; then
        echo "Running display fix..."
        bash fix_display.sh
        
        echo ""
        echo "Display fix completed!"
        echo "The system will reboot to apply changes."
        echo ""
        echo "After reboot, run this script again to continue:"
        echo "  bash fix_all_issues.sh"
        echo ""
        exit 0
    else
        echo "❌ fix_display.sh not found!"
        echo "Make sure all fix scripts are in the same directory."
        exit 1
    fi
else
    echo "Skipping display fix..."
fi

echo ""
echo "=============================================="
echo "STEP 2: FIXING SCREEN ROTATION"
echo "=============================================="
echo ""
echo "This will fix:"
echo "✓ 90° rotation to capture full screen"
echo "✓ Proper orientation for touch input"
echo "✓ Coordinate transformation for rotation"
echo ""

read -p "Fix screen rotation now? (y/n): " fix_rotation

if [ "$fix_rotation" = "y" ]; then
    if [ -f "fix_rotation.sh" ]; then
        echo "Running rotation fix..."
        bash fix_rotation.sh
        
        echo ""  
        echo "Rotation fix completed!"
        echo "The system will reboot to apply changes."
        echo ""
        echo "After reboot, run this script again to continue:"
        echo "  bash fix_all_issues.sh"
        echo ""
        exit 0
    else
        echo "❌ fix_rotation.sh not found!"
        echo "Make sure all fix scripts are in the same directory."
        exit 1
    fi
else
    echo "Skipping rotation fix..."
fi

echo ""
echo "=============================================="
echo "STEP 3: CALIBRATING TOUCH COORDINATES"
echo "=============================================="
echo ""
echo "This will fix:"
echo "✓ Touch positions not matching iPhone positions"
echo "✓ Coordinate mapping between RPi and iPhone"
echo "✓ Scaling and offset issues"
echo ""

read -p "Calibrate touch coordinates now? (y/n): " calibrate_touch

if [ "$calibrate_touch" = "y" ]; then
    if [ -f "calibrate_touch.sh" ]; then
        echo "Running touch calibration..."
        bash calibrate_touch.sh
    else
        echo "❌ calibrate_touch.sh not found!"
        echo "Make sure all fix scripts are in the same directory."
        exit 1
    fi
else
    echo "Skipping touch calibration..."
fi

echo ""
echo "=============================================="
echo "ALL FIXES COMPLETED!"
echo "=============================================="
echo ""

# Check what scripts were created
echo "Available launch scripts:"
if [ -f ~/launch_rpiplay_calibrated.sh ]; then
    echo "✓ ~/launch_rpiplay_calibrated.sh (recommended - fully calibrated)"
fi

if [ -f ~/launch_rpiplay_rotated.sh ]; then
    echo "✓ ~/launch_rpiplay_rotated.sh (with rotation support)"
fi

if [ -f ~/launch_rpiplay_touch.sh ]; then
    echo "✓ ~/launch_rpiplay_touch.sh (basic touch control)"
fi

echo ""
echo "USAGE:"
if [ -f ~/launch_rpiplay_calibrated.sh ]; then
    echo "Use the calibrated version for best results:"
    echo "  ~/launch_rpiplay_calibrated.sh"
else
    echo "Use the basic touch control:"
    echo "  ~/launch_rpiplay_touch.sh"
fi

echo ""
echo "TROUBLESHOOTING:"
echo ""
echo "If display still has issues:"
echo "• Check resolution: fbset"
echo "• Check GPU memory: vcgencmd get_mem gpu"
echo "• Try different HDMI modes in /boot/config.txt"
echo ""
echo "If rotation is wrong:"
echo "• Run: bash fix_rotation.sh again"
echo "• Try different rotation options (0°, 90°, 180°, 270°)"
echo ""
echo "If touch is still not accurate:"
echo "• Run: bash calibrate_touch.sh again"
echo "• Use: ~/fine_tune_touch.sh for precise adjustments"
echo "• Try different RPi resolution values"
echo ""

echo "FINE-TUNING TIPS:"
echo ""
echo "Touch too sensitive (cursor moves too much)?"
echo "• Increase RPi resolution values"
echo "• Example: -rpi 1000x600 instead of 800x480"
echo ""
echo "Touch not sensitive enough (cursor moves too little)?"
echo "• Decrease RPi resolution values"  
echo "• Example: -rpi 600x360 instead of 800x480"
echo ""
echo "Touch offset in one direction?"
echo "• Adjust the ratio between width and height"
echo "• Example: -rpi 850x480 to shift horizontally"
echo ""

echo "=============================================="
echo "SETUP COMPLETE! 🎉"
echo ""
echo "Your RPiPlay touch control system should now have:"
echo "✓ Clear, proper resolution display"
echo "✓ Correct screen orientation"  
echo "✓ Accurate touch coordinate mapping"
echo ""
echo "Enjoy controlling your iPhone with the Raspberry Pi!"
echo "==============================================" 