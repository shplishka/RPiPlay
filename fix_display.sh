#!/bin/bash

# Fix Raspberry Pi Display Issues
# Fixes resolution, colors, and alpha transparency issues

echo "=============================================="
echo "  Fixing Raspberry Pi Display Issues"
echo "=============================================="
echo ""

# Backup current config
sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)
echo "✓ Backed up current config"

echo "Current display info:"
echo "Resolution: $(fbset | grep geometry | awk '{print $2"x"$3}')"
echo "Color depth: $(fbset | grep geometry | awk '{print $6}') bits"
echo ""

echo "Applying display fixes..."

# Remove conflicting settings
sudo sed -i '/^dtoverlay=vc4-/d' /boot/config.txt
sudo sed -i '/^gpu_mem=/d' /boot/config.txt
sudo sed -i '/^hdmi_/d' /boot/config.txt
sudo sed -i '/^framebuffer_/d' /boot/config.txt
sudo sed -i '/^display_/d' /boot/config.txt

# Add optimized display settings
sudo tee -a /boot/config.txt > /dev/null <<EOF

# Display fixes for RPiPlay Touch Control
# Added $(date)

# GPU memory for video processing
gpu_mem=128

# Force HDMI output and disable overscan
hdmi_force_hotplug=1
disable_overscan=1

# Set specific resolution (adjust as needed)
hdmi_group=2
hdmi_mode=82
# Mode 82 = 1920x1080 60Hz
# Mode 16 = 1024x768 60Hz (for smaller screens)

# Color depth and pixel format
framebuffer_depth=32
framebuffer_ignore_alpha=1

# Reduce alpha blending issues
avoid_warnings=1

# Display timing
hdmi_pixel_freq_limit=400000000

# For touchscreen displays, use these instead:
# display_auto_detect=1
# lcd_rotate=2  # 180 degree rotation if needed

EOF

echo "✓ Applied display configuration"

# For official RPi touchscreen, add specific settings
read -p "Are you using the official Raspberry Pi 7-inch touchscreen? (y/n): " official_screen

if [ "$official_screen" = "y" ]; then
    echo ""
    echo "Applying official touchscreen settings..."
    
    sudo tee -a /boot/config.txt > /dev/null <<EOF

# Official RPi 7-inch touchscreen settings
display_auto_detect=1
lcd_rotate=2
ignore_lcd=0

# Touchscreen calibration
dtoverlay=rpi-display,rotate=90

EOF
    echo "✓ Added official touchscreen settings"
fi

# Fix color profile issues
echo ""
echo "Fixing color profiles..."

# Create better color settings
sudo tee /etc/X11/xorg.conf.d/99-rpiplay-display.conf > /dev/null <<EOF
Section "Device"
    Identifier "Raspberry Pi Display"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
    Option "SwapbuffersWait" "true"
EndSection

Section "Screen"
    Identifier "Default Screen"
    Device "Raspberry Pi Display"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080" "1024x768" "800x600"
    EndSubSection
EndSection
EOF

echo "✓ Created X11 display configuration"

# Set better console font
sudo dpkg-reconfigure console-setup --frontend=noninteractive 2>/dev/null || true

echo ""
echo "=============================================="
echo "DISPLAY FIX SUMMARY:"
echo "=============================================="
echo ""
echo "Applied fixes:"
echo "✓ Set GPU memory to 128MB"
echo "✓ Forced HDMI output with proper resolution"
echo "✓ Set 32-bit color depth"
echo "✓ Disabled alpha transparency issues"
echo "✓ Added display timing optimizations"
if [ "$official_screen" = "y" ]; then
    echo "✓ Added official touchscreen settings"
fi
echo "✓ Created X11 color profile"
echo ""

echo "REBOOT REQUIRED for changes to take effect!"
echo ""
echo "After reboot, check display with:"
echo "  fbset  # Shows current resolution and color depth"
echo "  vcgencmd get_mem gpu  # Should show gpu=128M"
echo ""

read -p "Reboot now to apply display fixes? (y/n): " reboot_now

if [ "$reboot_now" = "y" ]; then
    echo "Rebooting in 5 seconds..."
    sleep 5
    sudo reboot
else
    echo ""
    echo "Remember to reboot before testing:"
    echo "  sudo reboot"
    echo ""
    echo "Then test display quality and run:"
    echo "  bash fix_rotation.sh  # Next step"
fi

echo "==============================================" 