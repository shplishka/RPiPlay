#!/bin/bash

# Complete RPiPlay Touch Control Auto-Fix
# Fixes alpha colors, rotation, and calibration automatically
# Handles reboots and resumes automatically

STATE_FILE="$HOME/.rpiplay_fix_state"
LOG_FILE="$HOME/rpiplay_fix.log"

# Function to log messages
log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Function to set state
set_state() {
    echo "$1" > "$STATE_FILE"
    log_message "State set to: $1"
}

# Function to get current state
get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "start"
    fi
}

# Add this script to run after reboot
setup_autorun() {
    # Create systemd service to auto-resume after reboot
    sudo tee /etc/systemd/system/rpiplay-fix.service > /dev/null <<EOF
[Unit]
Description=RPiPlay Fix Auto-Resume
After=graphical.target

[Service]
Type=oneshot
User=$USER
ExecStart=$PWD/fix_everything_auto.sh
WorkingDirectory=$PWD
Environment=HOME=$HOME
Environment=USER=$USER

[Install]
WantedBy=graphical.target
EOF

    sudo systemctl enable rpiplay-fix.service
    log_message "Auto-resume service enabled"
}

# Remove autorun service
cleanup_autorun() {
    sudo systemctl disable rpiplay-fix.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/rpiplay-fix.service
    log_message "Auto-resume service removed"
}

# Main script logic
main() {
    local current_state=$(get_state)
    
    echo "=============================================="
    echo "  RPiPlay Complete Auto-Fix System"
    echo "=============================================="
    echo ""
    
    log_message "Starting auto-fix, current state: $current_state"
    
    case $current_state in
        "start")
            echo "🚀 Starting complete RPiPlay touch control setup..."
            echo ""
            echo "This will automatically:"
            echo "1. Fix alpha/transparency colors → reboot"
            echo "2. Fix screen rotation → reboot"  
            echo "3. Calibrate touch coordinates"
            echo "4. Create final calibrated system"
            echo ""
            
            read -p "Continue with automatic setup? (y/n): " confirm
            if [ "$confirm" != "y" ]; then
                echo "Setup cancelled"
                exit 0
            fi
            
            # Setup auto-resume
            setup_autorun
            
            # Start with alpha color fix
            set_state "alpha_colors"
            exec bash "$0"  # Restart script with new state
            ;;
            
        "alpha_colors")
            echo "=============================================="
            echo "STEP 1: FIXING ALPHA/TRANSPARENCY COLORS"
            echo "=============================================="
            echo ""
            
            log_message "Starting alpha color fix"
            
            # Apply alpha color fixes
            sudo cp /boot/config.txt /boot/config.txt.auto_backup.$(date +%Y%m%d_%H%M%S)
            
            # Remove conflicting settings
            sudo sed -i '/^dtoverlay=vc4-/d' /boot/config.txt
            sudo sed -i '/^gpu_mem=/d' /boot/config.txt
            sudo sed -i '/^hdmi_/d' /boot/config.txt
            sudo sed -i '/^framebuffer_/d' /boot/config.txt
            sudo sed -i '/^display_/d' /boot/config.txt
            sudo sed -i '/^avoid_warnings=/d' /boot/config.txt
            
            # Add comprehensive fixes
            sudo tee -a /boot/config.txt > /dev/null <<EOF

# COMPLETE AUTO-FIX - Alpha Colors
# Added $(date)

# GPU and memory
gpu_mem=128
gpu_mem_256=128
gpu_mem_512=128
gpu_mem_1024=128

# Alpha transparency fixes
framebuffer_depth=24
framebuffer_ignore_alpha=1
framebuffer_swap=0

# Disable problematic overlays
dtoverlay=!vc4-fkms-v3d
dtoverlay=!vc4-kms-v3d
disable_fw_kms_setup=1

# HDMI and color fixes
hdmi_force_hotplug=1
hdmi_ignore_cec_init=1
disable_overscan=1
hdmi_pixel_encoding=0
hdmi_group=2
hdmi_mode=82
hdmi_drive=2
config_hdmi_boost=5
avoid_warnings=2
disable_splash=1

EOF

            # Fix X11 compositing
            sudo mkdir -p /etc/X11/xorg.conf.d
            sudo tee /etc/X11/xorg.conf.d/99-no-alpha.conf > /dev/null <<EOF
Section "Extensions"
    Option "Composite" "Disable"
    Option "RENDER" "Disable"
EndSection
EOF

            # Kill compositors
            pkill -f compton 2>/dev/null || true
            pkill -f picom 2>/dev/null || true
            
            echo "✅ Alpha color fixes applied"
            log_message "Alpha color fixes completed"
            
            # Set next state and reboot
            set_state "rotation"
            echo ""
            echo "⏰ Rebooting in 5 seconds to apply color fixes..."
            echo "Will auto-resume with rotation fix..."
            sleep 5
            sudo reboot
            ;;
            
        "rotation")
            echo "=============================================="
            echo "STEP 2: FIXING SCREEN ROTATION"  
            echo "=============================================="
            echo ""
            
            log_message "Starting rotation fix"
            
            echo "Colors should now be fixed! ✅"
            echo ""
            echo "Choose screen rotation:"
            echo "1. No rotation (0°)"
            echo "2. 90° clockwise (recommended for full screen)"
            echo "3. 180° upside down"
            echo "4. 270° counter-clockwise"
            echo ""
            
            read -p "Select rotation (1-4) [default: 2 for 90°]: " rotation_choice
            rotation_choice=${rotation_choice:-2}
            
            case $rotation_choice in
                1) ROTATION=0; ROTATION_NAME="No rotation"; RPI_W=800; RPI_H=480 ;;
                2) ROTATION=1; ROTATION_NAME="90° clockwise"; RPI_W=480; RPI_H=800 ;;
                3) ROTATION=2; ROTATION_NAME="180°"; RPI_W=800; RPI_H=480 ;;
                4) ROTATION=3; ROTATION_NAME="270°"; RPI_W=480; RPI_H=800 ;;
                *) ROTATION=1; ROTATION_NAME="90° clockwise"; RPI_W=480; RPI_H=800 ;;
            esac
            
            echo "Applying $ROTATION_NAME..."
            log_message "Applying rotation: $ROTATION_NAME"
            
            # Save rotation settings for calibration step
            echo "$ROTATION" > "$HOME/.rpiplay_rotation"
            echo "$RPI_W" > "$HOME/.rpiplay_width" 
            echo "$RPI_H" > "$HOME/.rpiplay_height"
            
            # Apply rotation
            sudo sed -i '/^display_rotate=/d' /boot/config.txt
            sudo sed -i '/^lcd_rotate=/d' /boot/config.txt
            
            sudo tee -a /boot/config.txt > /dev/null <<EOF

# Screen rotation
display_rotate=$ROTATION
lcd_rotate=$ROTATION

EOF

            # X11 touch transformation
            case $ROTATION in
                0) TRANSFORM="1 0 0 0 1 0 0 0 1" ;;
                1) TRANSFORM="0 1 0 -1 0 1 0 0 1" ;;
                2) TRANSFORM="-1 0 1 0 -1 1 0 0 1" ;;
                3) TRANSFORM="0 -1 1 1 0 0 0 0 1" ;;
            esac
            
            sudo tee /etc/X11/xorg.conf.d/99-touch-rotation.conf > /dev/null <<EOF
Section "InputClass"
    Identifier "Touch Rotation"
    MatchIsTouchscreen "on"
    Option "TransformationMatrix" "$TRANSFORM"
EndSection
EOF

            echo "✅ Rotation settings applied"
            log_message "Rotation fix completed"
            
            # Set next state and reboot
            set_state "calibration"
            echo ""
            echo "⏰ Rebooting in 5 seconds to apply rotation..."
            echo "Will auto-resume with touch calibration..."
            sleep 5
            sudo reboot
            ;;
            
        "calibration")
            echo "=============================================="
            echo "STEP 3: TOUCH CALIBRATION"
            echo "=============================================="
            echo ""
            
            log_message "Starting calibration"
            
            echo "Screen should now be rotated correctly! ✅"
            echo ""
            
            # Load saved settings
            ROTATION=$(cat "$HOME/.rpiplay_rotation" 2>/dev/null || echo "1")
            RPI_WIDTH=$(cat "$HOME/.rpiplay_width" 2>/dev/null || echo "480")
            RPI_HEIGHT=$(cat "$HOME/.rpiplay_height" 2>/dev/null || echo "800")
            
            echo "Current settings:"
            echo "• Rotation applied"
            echo "• RPi resolution: ${RPI_WIDTH}x${RPI_HEIGHT}"
            echo ""
            
            echo "Select iPhone model for calibration:"
            echo "1. iPhone 14 Pro Max (430x932)"
            echo "2. iPhone 14 Pro (393x852)"
            echo "3. iPhone 14/13/12 (390x844) - Most common"
            echo "4. iPhone SE (375x667)"
            echo "5. Custom"
            echo ""
            
            read -p "Select iPhone (1-5) [default: 3]: " iphone_choice
            iphone_choice=${iphone_choice:-3}
            
            case $iphone_choice in
                1) IPHONE_W=430; IPHONE_H=932; MODEL="iPhone 14 Pro Max" ;;
                2) IPHONE_W=393; IPHONE_H=852; MODEL="iPhone 14 Pro" ;;
                3) IPHONE_W=390; IPHONE_H=844; MODEL="iPhone 14/13/12" ;;
                4) IPHONE_W=375; IPHONE_H=667; MODEL="iPhone SE" ;;
                5) 
                    read -p "iPhone width: " IPHONE_W
                    read -p "iPhone height: " IPHONE_H
                    MODEL="Custom"
                    ;;
                *) IPHONE_W=390; IPHONE_H=844; MODEL="iPhone 14 (default)" ;;
            esac
            
            echo "Using: $MODEL (${IPHONE_W}x${IPHONE_H})"
            log_message "Calibration settings: $MODEL, RPi: ${RPI_WIDTH}x${RPI_HEIGHT}"
            
            # Create final calibrated launch script
            cat > ~/launch_rpiplay_calibrated.sh <<EOF
#!/bin/bash

# RPiPlay Touch Control - Fully Calibrated System
# Auto-generated by complete setup

echo "🎯 Starting RPiPlay Touch Control (Complete Setup)"
echo "✅ Alpha colors fixed"
echo "✅ Rotation applied"  
echo "✅ Touch calibrated"
echo ""
echo "Configuration:"
echo "• iPhone: $MODEL (${IPHONE_W}x${IPHONE_H})"
echo "• RPi: ${RPI_WIDTH}x${RPI_HEIGHT}"
echo "• ESP32: /dev/ttyUSB0"
echo "• Touch: /dev/input/event4"
echo ""

echo "Make sure:"
echo "1. ESP32 connected and programmed"
echo "2. iPhone paired with ESP32 ('iPhone Remote')"
echo "3. ESP32 LED on when iPhone connected"
echo ""
echo "Press Ctrl+C to stop"
echo ""

rpiplay \\
    -esp32 /dev/ttyUSB0 \\
    -touch /dev/input/event4 \\
    -iphone ${IPHONE_W}x${IPHONE_H} \\
    -rpi ${RPI_WIDTH}x${RPI_HEIGHT} \\
    -n "RPi Complete Setup" \\
    "\$@"
EOF
            
            chmod +x ~/launch_rpiplay_calibrated.sh
            
            # Create fine-tuning script
            cat > ~/fine_tune_calibrated.sh <<EOF
#!/bin/bash
echo "Fine-tune touch calibration:"
echo "Current: RPi ${RPI_WIDTH}x${RPI_HEIGHT}, iPhone ${IPHONE_W}x${IPHONE_H}"
echo ""
echo "Adjust RPi resolution for better touch mapping:"
read -p "New RPi width [$RPI_WIDTH]: " new_w
read -p "New RPi height [$RPI_HEIGHT]: " new_h
new_w=\${new_w:-$RPI_WIDTH}
new_h=\${new_h:-$RPI_HEIGHT}
echo "Testing \${new_w}x\${new_h}..."
rpiplay -esp32 /dev/ttyUSB0 -touch /dev/input/event4 -iphone ${IPHONE_W}x${IPHONE_H} -rpi "\${new_w}x\${new_h}" -n "Fine Tune"
EOF
            
            chmod +x ~/fine_tune_calibrated.sh
            
            echo "✅ Calibrated launch scripts created"
            
            # Cleanup
            cleanup_autorun
            set_state "complete"
            rm -f "$HOME/.rpiplay_rotation" "$HOME/.rpiplay_width" "$HOME/.rpiplay_height"
            
            echo ""
            echo "=============================================="
            echo "🎉 COMPLETE SETUP FINISHED!"
            echo "=============================================="
            echo ""
            echo "✅ Alpha/transparency colors fixed"
            echo "✅ Screen rotation applied"
            echo "✅ Touch coordinates calibrated"
            echo "✅ Final system ready!"
            echo ""
            echo "🚀 START YOUR SYSTEM:"
            echo "   ~/launch_rpiplay_calibrated.sh"
            echo ""
            echo "🔧 Fine-tune if needed:"
            echo "   ~/fine_tune_calibrated.sh"
            echo ""
            echo "📋 What to do now:"
            echo "1. Connect iPhone to RPiPlay (AirPlay)"
            echo "2. Touch RPi screen → controls iPhone!"
            echo "3. Enjoy your complete touch control system!"
            echo ""
            
            log_message "Complete setup finished successfully!"
            
            read -p "Test the calibrated system now? (y/n): " test_now
            if [ "$test_now" = "y" ]; then
                echo ""
                echo "Starting calibrated system..."
                ~/launch_rpiplay_calibrated.sh
            fi
            ;;
            
        "complete")
            echo "=============================================="
            echo "✅ Setup already complete!"
            echo "=============================================="
            echo ""
            echo "Your calibrated system is ready:"
            echo "  ~/launch_rpiplay_calibrated.sh"
            echo ""
            echo "Fine-tune if needed:"
            echo "  ~/fine_tune_calibrated.sh"
            echo ""
            
            read -p "Start the system now? (y/n): " start_now
            if [ "$start_now" = "y" ]; then
                ~/launch_rpiplay_calibrated.sh
            fi
            ;;
    esac
}

# Run main function
main "$@" 