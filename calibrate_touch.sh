#!/bin/bash

# Touch Calibration for RPiPlay
# Interactive calibration to fix coordinate mapping between RPi and iPhone

echo "=============================================="
echo "  Touch Coordinate Calibration"
echo "=============================================="
echo ""

ESP32_DEVICE="/dev/ttyUSB0"
TOUCH_DEVICE="/dev/input/event4"

echo "This tool will help calibrate touch coordinates between"
echo "the Raspberry Pi screen and iPhone screen."
echo ""

# Check prerequisites
if ! command -v rpiplay >/dev/null || ! rpiplay -h | grep -q "touch"; then
    echo "❌ RPiPlay with touch support required"
    exit 1
fi

if [ ! -e "$ESP32_DEVICE" ] || [ ! -w "$ESP32_DEVICE" ]; then
    echo "❌ ESP32 not available at $ESP32_DEVICE"
    exit 1
fi

if [ ! -e "$TOUCH_DEVICE" ] || [ ! -r "$TOUCH_DEVICE" ]; then
    echo "❌ Touch device not available at $TOUCH_DEVICE"
    exit 1
fi

echo "✓ All devices ready"
echo ""

# Get current screen resolution
echo "Detecting screen resolution..."
CURRENT_RES=$(fbset | grep geometry | awk '{print $2"x"$3}')
echo "Current screen resolution: $CURRENT_RES"

# Ask for iPhone model for better defaults
echo ""
echo "Select your iPhone model for optimal calibration:"
echo "1. iPhone 14 Pro Max (430x932)"
echo "2. iPhone 14 Pro (393x852)" 
echo "3. iPhone 14/13/12 (390x844)"
echo "4. iPhone SE 3rd gen (375x667)"
echo "5. Custom resolution"

read -p "Select iPhone model (1-5): " iphone_choice

case $iphone_choice in
    1) IPHONE_WIDTH=430; IPHONE_HEIGHT=932; IPHONE_MODEL="iPhone 14 Pro Max" ;;
    2) IPHONE_WIDTH=393; IPHONE_HEIGHT=852; IPHONE_MODEL="iPhone 14 Pro" ;;
    3) IPHONE_WIDTH=390; IPHONE_HEIGHT=844; IPHONE_MODEL="iPhone 14/13/12" ;;
    4) IPHONE_WIDTH=375; IPHONE_HEIGHT=667; IPHONE_MODEL="iPhone SE 3rd gen" ;;
    5) 
        read -p "Enter iPhone width: " IPHONE_WIDTH
        read -p "Enter iPhone height: " IPHONE_HEIGHT
        IPHONE_MODEL="Custom"
        ;;
    *) 
        IPHONE_WIDTH=390; IPHONE_HEIGHT=844; IPHONE_MODEL="iPhone 14 (default)"
        ;;
esac

echo "Selected: $IPHONE_MODEL (${IPHONE_WIDTH}x${IPHONE_HEIGHT})"

# Ask for RPi screen resolution
echo ""
echo "Enter your Raspberry Pi screen resolution:"
read -p "RPi width [800]: " RPI_WIDTH
read -p "RPi height [480]: " RPI_HEIGHT

RPI_WIDTH=${RPI_WIDTH:-800}
RPI_HEIGHT=${RPI_HEIGHT:-480}

echo "RPi resolution: ${RPI_WIDTH}x${RPI_HEIGHT}"

echo ""
echo "=============================================="
echo "CALIBRATION TEST"  
echo "=============================================="
echo ""
echo "Starting calibration test..."
echo ""
echo "INSTRUCTIONS:"
echo "1. RPiPlay will start with current settings"
echo "2. Connect your iPhone to RPiPlay (AirPlay mirroring)"
echo "3. Touch different areas of the RPi screen"
echo "4. Watch where the cursor appears on the iPhone"
echo "5. Note any offset or scaling issues"
echo "6. Press Ctrl+C to stop and adjust settings"
echo ""

read -p "Ready to start calibration test? Press Enter..."

echo ""
echo "Starting RPiPlay for calibration..."
echo "Touch the RPi screen and observe iPhone cursor position"
echo ""

# Start RPiPlay with current settings
timeout 60 rpiplay -d \
    -esp32 "$ESP32_DEVICE" \
    -touch "$TOUCH_DEVICE" \
    -iphone "${IPHONE_WIDTH}x${IPHONE_HEIGHT}" \
    -rpi "${RPI_WIDTH}x${RPI_HEIGHT}" \
    -n "Calibration Test" \
    2>&1 | grep -E "Touch|ESP32|Click" &

rpiplay_pid=$!

echo "RPiPlay running (PID: $rpiplay_pid)"
echo "Touch different corners and areas of the screen..."
echo "Press Ctrl+C when done testing"

# Wait for user to stop
wait $rpiplay_pid 2>/dev/null

echo ""
echo "=============================================="
echo "CALIBRATION ADJUSTMENT"
echo "=============================================="
echo ""

echo "Based on your test, what adjustments are needed?"
echo ""

# Ask about scaling issues
echo "1. SCALING ISSUES:"
echo "   - Touch moves too much on iPhone? Screen might be too small"
echo "   - Touch moves too little on iPhone? Screen might be too large"
echo ""

read -p "Does touch move too much (M), too little (L), or about right (R)? " scaling_issue

case $scaling_issue in
    [Mm]*)
        echo "Reducing sensitivity..."
        SCALE_FACTOR=0.8
        ;;
    [Ll]*)
        echo "Increasing sensitivity..."
        SCALE_FACTOR=1.2
        ;;
    *)
        echo "Keeping current scaling"
        SCALE_FACTOR=1.0
        ;;
esac

# Ask about offset issues
echo ""
echo "2. POSITION OFFSET:"
echo "   - Touch appears too far left/right?"
echo "   - Touch appears too far up/down?"
echo ""

read -p "Horizontal offset needed? Left (-), Right (+), None (0): " h_offset
read -p "Vertical offset needed? Up (-), Down (+), None (0): " v_offset

case $h_offset in
    -*) H_OFFSET=-50 ;;
    +*) H_OFFSET=50 ;;
    *) H_OFFSET=0 ;;
esac

case $v_offset in
    -*) V_OFFSET=-50 ;;
    +*) V_OFFSET=50 ;;
    *) V_OFFSET=0 ;;
esac

# Calculate adjusted resolution
ADJUSTED_WIDTH=$(echo "$RPI_WIDTH * $SCALE_FACTOR" | bc -l | cut -d. -f1)
ADJUSTED_HEIGHT=$(echo "$RPI_HEIGHT * $SCALE_FACTOR" | bc -l | cut -d. -f1)

echo ""
echo "Calculated adjustments:"
echo "Original RPi resolution: ${RPI_WIDTH}x${RPI_HEIGHT}"
echo "Adjusted RPi resolution: ${ADJUSTED_WIDTH}x${ADJUSTED_HEIGHT}"
echo "Horizontal offset: $H_OFFSET"
echo "Vertical offset: $V_OFFSET"

# Create calibrated launch script
echo ""
echo "Creating calibrated launch script..."

cat > ~/launch_rpiplay_calibrated.sh <<EOF
#!/bin/bash

# RPiPlay Touch Control - Calibrated
# Generated by calibration tool

echo "🎯 Starting RPiPlay Touch Control (Calibrated)"
echo "iPhone: $IPHONE_MODEL (${IPHONE_WIDTH}x${IPHONE_HEIGHT})"
echo "RPi (adjusted): ${ADJUSTED_WIDTH}x${ADJUSTED_HEIGHT}"
echo "Offsets: H=$H_OFFSET, V=$V_OFFSET"
echo ""

echo "Make sure:"
echo "1. ESP32 is connected and programmed"
echo "2. iPhone is paired with ESP32 Bluetooth ('iPhone Remote')"
echo "3. ESP32 LED is on when iPhone connected"
echo ""
echo "Press Ctrl+C to stop"
echo ""

rpiplay \\
    -esp32 "$ESP32_DEVICE" \\
    -touch "$TOUCH_DEVICE" \\
    -iphone "${IPHONE_WIDTH}x${IPHONE_HEIGHT}" \\
    -rpi "${ADJUSTED_WIDTH}x${ADJUSTED_HEIGHT}" \\
    -n "RPi Touch (Calibrated)" \\
    "\$@"
EOF

chmod +x ~/launch_rpiplay_calibrated.sh
echo "✓ Created ~/launch_rpiplay_calibrated.sh"

# Create fine-tuning script for further adjustments
cat > ~/fine_tune_touch.sh <<EOF
#!/bin/bash

# Fine-tune touch calibration
echo "Current settings:"
echo "iPhone: ${IPHONE_WIDTH}x${IPHONE_HEIGHT}"
echo "RPi: ${ADJUSTED_WIDTH}x${ADJUSTED_HEIGHT}"
echo ""

echo "Adjust RPi resolution for better mapping:"
read -p "New RPi width [$ADJUSTED_WIDTH]: " new_width
read -p "New RPi height [$ADJUSTED_HEIGHT]: " new_height

new_width=\${new_width:-$ADJUSTED_WIDTH}
new_height=\${new_height:-$ADJUSTED_HEIGHT}

echo "Testing with \${new_width}x\${new_height}..."

rpiplay \\
    -esp32 "$ESP32_DEVICE" \\
    -touch "$TOUCH_DEVICE" \\
    -iphone "${IPHONE_WIDTH}x${IPHONE_HEIGHT}" \\
    -rpi "\${new_width}x\${new_height}" \\
    -n "Fine Tune Test"
EOF

chmod +x ~/fine_tune_touch.sh
echo "✓ Created ~/fine_tune_touch.sh for fine-tuning"

echo ""
echo "=============================================="
echo "CALIBRATION COMPLETE"
echo "=============================================="
echo ""
echo "Test your calibrated settings:"
echo "  ~/launch_rpiplay_calibrated.sh"
echo ""
echo "If still not perfect, fine-tune with:"
echo "  ~/fine_tune_touch.sh"
echo ""
echo "Common calibration tips:"
echo "• If touch is too sensitive: increase RPi resolution values"
echo "• If touch is not sensitive enough: decrease RPi resolution values" 
echo "• If touch is offset: adjust the resolution ratio"
echo ""
echo "Example resolutions to try:"
echo "• More sensitive: 1000x600 (makes iPhone cursor move less)"
echo "• Less sensitive: 600x360 (makes iPhone cursor move more)"
echo "• For rotation: swap width/height values"
echo ""

read -p "Test calibrated settings now? (y/n): " test_now

if [ "$test_now" = "y" ]; then
    echo ""
    echo "Starting calibrated test..."
    ~/launch_rpiplay_calibrated.sh
fi

echo "==============================================" 