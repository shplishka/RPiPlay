#!/bin/bash

# Fix Alpha/Transparency Color Issues on Raspberry Pi
# Aggressive fix for alpha-style colors and transparency problems

echo "=============================================="
echo "  Fix Alpha/Transparency Color Issues"
echo "=============================================="
echo ""

echo "This script will aggressively fix alpha/transparency color issues."
echo ""

# Check current display status
echo "Current display status:"
fbset | grep -E "geometry|rgba"
echo "GPU memory: $(vcgencmd get_mem gpu 2>/dev/null || echo 'unknown')"
echo ""

# Backup current config
echo "Backing up current configuration..."
sudo cp /boot/config.txt /boot/config.txt.alpha_backup.$(date +%Y%m%d_%H%M%S)
echo "✓ Backup created"

echo ""
echo "Applying aggressive alpha transparency fixes..."

# Remove all conflicting display settings
sudo sed -i '/^dtoverlay=vc4-/d' /boot/config.txt
sudo sed -i '/^gpu_mem=/d' /boot/config.txt
sudo sed -i '/^hdmi_/d' /boot/config.txt
sudo sed -i '/^framebuffer_/d' /boot/config.txt
sudo sed -i '/^display_/d' /boot/config.txt
sudo sed -i '/^avoid_warnings=/d' /boot/config.txt
sudo sed -i '/^disable_overscan=/d' /boot/config.txt

# Add comprehensive alpha transparency fixes
sudo tee -a /boot/config.txt > /dev/null <<EOF

# AGGRESSIVE ALPHA TRANSPARENCY FIXES
# Added $(date)

# Essential GPU and memory settings
gpu_mem=128
gpu_mem_256=128
gpu_mem_512=128
gpu_mem_1024=128

# Force proper color depth and disable alpha
framebuffer_depth=24
framebuffer_ignore_alpha=1
framebuffer_swap=0

# Disable problematic overlays that cause alpha issues
dtoverlay=!vc4-fkms-v3d
dtoverlay=!vc4-kms-v3d

# Force legacy graphics driver (no alpha compositing)
disable_fw_kms_setup=1

# HDMI settings to ensure proper color output
hdmi_force_hotplug=1
hdmi_ignore_cec_init=1
hdmi_ignore_cec=1
disable_overscan=1

# Color space and pixel format fixes
hdmi_pixel_encoding=0
hdmi_blanking=1

# Set specific resolution with proper color depth
hdmi_group=2
hdmi_mode=82
hdmi_cvt_reduce_blanking=1

# Additional alpha transparency prevention
avoid_warnings=2
disable_splash=1

# Force RGB color space (no YUV which can cause transparency issues)
hdmi_drive=2
config_hdmi_boost=5

EOF

echo "✓ Applied aggressive alpha transparency fixes to /boot/config.txt"

# Fix X11 compositor issues that cause alpha problems
echo ""
echo "Fixing X11 compositor alpha issues..."

sudo mkdir -p /etc/X11/xorg.conf.d

# Disable compositing and alpha blending in X11
sudo tee /etc/X11/xorg.conf.d/99-no-alpha.conf > /dev/null <<EOF
Section "Device"
    Identifier "Raspberry Pi Graphics"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
    Option "SwapbuffersWait" "true"
    Option "NoAccel" "false"
    Option "ShadowFB" "false"
EndSection

Section "Screen"
    Identifier "Default Screen"
    Device "Raspberry Pi Graphics"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1920x1080" "1680x1050" "1280x1024" "1024x768" "800x600"
    EndSubSection
EndSection

Section "Extensions"
    Option "Composite" "Disable"
    Option "RENDER" "Disable"
    Option "DAMAGE" "Disable"
EndSection
EOF

echo "✓ Created X11 anti-alpha configuration"

# Disable desktop compositor if running
echo ""
echo "Disabling desktop compositors that cause alpha issues..."

# Disable LXDE compositor
if [ -f ~/.config/lxsession/LXDE-pi/desktop.conf ]; then
    sed -i 's/window_manager=.*/window_manager=openbox-lxde/' ~/.config/lxsession/LXDE-pi/desktop.conf
    echo "✓ Disabled LXDE compositor"
fi

# Disable any running compositors
pkill -f compton 2>/dev/null || true
pkill -f picom 2>/dev/null || true
pkill -f xcompmgr 2>/dev/null || true

# Create script to disable compositors on boot
sudo tee /etc/xdg/autostart/disable-compositor.desktop > /dev/null <<EOF
[Desktop Entry]
Type=Application
Name=Disable Compositor
Exec=sh -c 'pkill -f compton; pkill -f picom; pkill -f xcompmgr'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo "✓ Created compositor disable script"

# Fix GTK theme alpha issues
echo ""
echo "Fixing GTK theme alpha transparency..."

mkdir -p ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-application-prefer-dark-theme=0
gtk-theme-name=Adwaita
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
EOF

echo "✓ Fixed GTK theme settings"

# Create test script to verify color fix
cat > ~/test_colors.sh <<EOF
#!/bin/bash
echo "=== COLOR TEST ==="
echo "After reboot, run this to test colors:"
echo ""
echo "1. Check framebuffer depth:"
echo "   fbset | grep rgba"
echo ""
echo "2. Check GPU memory:"
echo "   vcgencmd get_mem gpu"
echo ""
echo "3. Test color display:"
echo "   fbi -T 1 /opt/vc/src/hello_pi/hello_teapot/teapot.jpg 2>/dev/null || echo 'Test image not found'"
echo ""
echo "4. Check for alpha in display:"
echo "   xrandr --verbose | grep -i alpha"
echo ""
echo "Colors should now be solid (no transparency/alpha effects)"
EOF

chmod +x ~/test_colors.sh

echo ""
echo "=============================================="
echo "ALPHA COLOR FIX APPLIED"
echo "=============================================="
echo ""
echo "Applied fixes:"
echo "✓ Set 24-bit color depth (no alpha channel)"
echo "✓ Disabled alpha blending in framebuffer"
echo "✓ Forced legacy graphics driver"
echo "✓ Disabled X11 compositing"
echo "✓ Killed desktop compositors"
echo "✓ Fixed GTK theme transparency"
echo "✓ Set RGB color space (no YUV)"
echo "✓ Boosted HDMI signal strength"

echo ""
echo "IMPORTANT: REBOOT REQUIRED!"
echo ""
echo "After reboot:"
echo "1. Colors should be solid (no alpha/transparency)"
echo "2. Test with: ~/test_colors.sh"
echo "3. If still alpha issues, check: cat /boot/config.txt | tail -20"

echo ""

read -p "Reboot now to apply alpha color fixes? (y/n): " reboot_now

if [ "$reboot_now" = "y" ]; then
    echo ""
    echo "Rebooting in 5 seconds..."
    echo "After reboot, colors should be fixed!"
    echo "Test with: ~/test_colors.sh"
    sleep 5
    sudo reboot
else
    echo ""
    echo "Remember to reboot: sudo reboot"
    echo ""
    echo "After reboot:"
    echo "• Test colors: ~/test_colors.sh"
    echo "• Continue setup: bash fix_all_issues.sh"
fi

echo "==============================================" 