#!/bin/bash

# Fix Screen Rotation for RPiPlay Touch Control
# Handles 90-degree rotation and touch coordinate adjustment

echo "=============================================="
echo "  Fixing Screen Rotation"
echo "=============================================="
echo ""

echo "Current display orientation:"
fbset | grep geometry
echo ""

echo "Choose rotation option:"
echo "1. No rotation (0°)"
echo "2. 90° clockwise" 
echo "3. 180° upside down"
echo "4. 270° counter-clockwise (90° counter)"
echo ""

read -p "Select rotation (1-4): " rotation_choice

case $rotation_choice in
    1) 
        ROTATION=0
        ROTATION_NAME="No rotation"
        ;;
    2) 
        ROTATION=1
        ROTATION_NAME="90° clockwise"
        ;;
    3) 
        ROTATION=2  
        ROTATION_NAME="180° upside down"
        ;;
    4) 
        ROTATION=3
        ROTATION_NAME="270° counter-clockwise"
        ;;
    *)
        echo "Invalid choice, using 90° clockwise"
        ROTATION=1
        ROTATION_NAME="90° clockwise"
        ;;
esac

echo ""
echo "Applying $ROTATION_NAME..."

# Backup config
sudo cp /boot/config.txt /boot/config.txt.rotation_backup

# Remove existing rotation settings
sudo sed -i '/^lcd_rotate=/d' /boot/config.txt
sudo sed -i '/^display_rotate=/d' /boot/config.txt
sudo sed -i '/^dtoverlay=.*rotate/d' /boot/config.txt

# Add new rotation setting
echo ""
echo "Adding rotation to /boot/config.txt..."
sudo tee -a /boot/config.txt > /dev/null <<EOF

# Screen rotation for RPiPlay Touch Control
# Added $(date)
display_rotate=$ROTATION

EOF

echo "✓ Added display_rotate=$ROTATION to config"

# Also set LCD rotation for touchscreens
if [ "$ROTATION" != "0" ]; then
    echo "lcd_rotate=$ROTATION" | sudo tee -a /boot/config.txt > /dev/null
    echo "✓ Added lcd_rotate=$ROTATION for touchscreen"
fi

# Create updated RPiPlay launch script with rotation compensation
echo ""
echo "Creating rotation-aware launch script..."

# Determine coordinate transformation based on rotation
case $ROTATION in
    0) # No rotation
        COORD_TRANSFORM="# No coordinate transformation needed"
        RPI_WIDTH=800
        RPI_HEIGHT=480
        ;;
    1) # 90° clockwise  
        COORD_TRANSFORM="# 90° rotation: swap width/height, adjust coordinates"
        RPI_WIDTH=480
        RPI_HEIGHT=800
        ;;
    2) # 180°
        COORD_TRANSFORM="# 180° rotation: flip coordinates"
        RPI_WIDTH=800
        RPI_HEIGHT=480
        ;;
    3) # 270° counter-clockwise
        COORD_TRANSFORM="# 270° rotation: swap width/height, adjust coordinates"
        RPI_WIDTH=480
        RPI_HEIGHT=800
        ;;
esac

cat > ~/launch_rpiplay_rotated.sh <<EOF
#!/bin/bash

# RPiPlay Touch Control with Rotation Support
# Rotation: $ROTATION_NAME

echo "🚀 Starting RPiPlay Touch Control (Rotated)"
echo "Screen rotation: $ROTATION_NAME"
echo "RPi resolution: ${RPI_WIDTH}x${RPI_HEIGHT}"
echo "iPhone resolution: 390x844"
echo ""

# $COORD_TRANSFORM

echo "Make sure:"
echo "1. ESP32 is connected and programmed"
echo "2. iPhone is paired with ESP32 Bluetooth ('iPhone Remote')"
echo "3. ESP32 LED is on when iPhone connected"
echo ""
echo "Press Ctrl+C to stop"
echo ""

rpiplay \\
    -esp32 /dev/ttyUSB0 \\
    -touch /dev/input/event4 \\
    -iphone 390x844 \\
    -rpi ${RPI_WIDTH}x${RPI_HEIGHT} \\
    -n "RPi Touch (Rotated)" \\
    "\$@"
EOF

chmod +x ~/launch_rpiplay_rotated.sh
echo "✓ Created ~/launch_rpiplay_rotated.sh"

# Create X11 rotation settings
echo ""
echo "Setting up X11 rotation..."

sudo mkdir -p /etc/X11/xorg.conf.d

# X11 transformation matrix for touch input
case $ROTATION in
    0) TRANSFORM="1 0 0 0 1 0 0 0 1" ;;           # No rotation
    1) TRANSFORM="0 1 0 -1 0 1 0 0 1" ;;          # 90° clockwise
    2) TRANSFORM="-1 0 1 0 -1 1 0 0 1" ;;         # 180°
    3) TRANSFORM="0 -1 1 1 0 0 0 0 1" ;;          # 270° counter-clockwise
esac

sudo tee /etc/X11/xorg.conf.d/99-touch-rotation.conf > /dev/null <<EOF
Section "InputClass"
    Identifier "Touch Rotation"
    MatchIsTouchscreen "on"
    Option "TransformationMatrix" "$TRANSFORM"
EndSection
EOF

echo "✓ Created X11 touch transformation"

echo ""
echo "=============================================="
echo "ROTATION SETUP COMPLETE"
echo "=============================================="
echo ""
echo "Applied settings:"
echo "✓ Display rotation: $ROTATION_NAME"
echo "✓ RPi resolution adjusted: ${RPI_WIDTH}x${RPI_HEIGHT}"  
echo "✓ Created rotation-aware launch script"
echo "✓ Set up X11 touch transformation"
echo ""

echo "REBOOT REQUIRED for rotation to take effect!"
echo ""

read -p "Reboot now to apply rotation? (y/n): " reboot_now

if [ "$reboot_now" = "y" ]; then
    echo ""
    echo "After reboot:"
    echo "1. Check if screen orientation looks correct"
    echo "2. Test with: ~/launch_rpiplay_rotated.sh"
    echo "3. If touch positions still wrong, run: bash calibrate_touch.sh"
    echo ""
    echo "Rebooting in 5 seconds..."
    sleep 5
    sudo reboot
else
    echo ""
    echo "Remember to reboot: sudo reboot"
    echo ""
    echo "After reboot, test with:"
    echo "  ~/launch_rpiplay_rotated.sh"
    echo ""
    echo "If touch positions still don't match, run:"
    echo "  bash calibrate_touch.sh"
fi

echo "==============================================" 