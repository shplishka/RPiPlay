#!/bin/bash

# RPiPlay Touch Control - Complete Installation Script
# This script installs and configures RPiPlay with ESP32 touch control on Raspberry Pi
# Run with: bash install_rpiplay_touch.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
INSTALL_DIR="$HOME/RPiPlay"
ESP32_DEVICE="/dev/ttyUSB0"
TOUCH_DEVICE="/dev/input/event4"
IPHONE_RESOLUTION="390x844"
RPI_RESOLUTION="800x480"
GPU_MEMORY="128"

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}  RPiPlay Touch Control Installation${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_step() {
    echo -e "\n${GREEN}[STEP]${NC} $1\n"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_raspberry_pi() {
    print_step "Checking if running on Raspberry Pi"
    
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_error "This script is designed for Raspberry Pi only!"
        exit 1
    fi
    
    PI_MODEL=$(grep "Revision" /proc/cpuinfo | awk '{print $3}')
    print_info "Detected Raspberry Pi (Revision: $PI_MODEL)"
}

update_system() {
    print_step "Updating system packages"
    
    sudo apt update -y
    sudo apt upgrade -y
    
    print_success "System updated"
}

install_dependencies() {
    print_step "Installing build dependencies"
    
    # Essential build tools
    sudo apt install -y \
        cmake \
        build-essential \
        git \
        pkg-config \
        screen \
        nano
    
    # OpenSSL and networking
    sudo apt install -y \
        libssl-dev \
        libavahi-compat-libdnssd-dev
    
    # plist library for Apple protocols
    sudo apt install -y libplist-dev
    
    print_success "Build dependencies installed"
}

install_videocore() {
    print_step "Installing VideoCore/OpenMAX libraries"
    
    # Install VideoCore libraries
    sudo apt install -y \
        libraspberrypi-dev \
        libraspberrypi0 \
        libraspberrypi-bin
    
    # Install GStreamer as fallback
    sudo apt install -y \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev \
        libgstreamer-plugins-bad1.0-dev \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav \
        gstreamer1.0-tools \
        gstreamer1.0-x \
        gstreamer1.0-alsa \
        gstreamer1.0-gl \
        gstreamer1.0-gtk3 \
        gstreamer1.0-qt5 \
        gstreamer1.0-pulseaudio
    
    print_success "VideoCore libraries installed"
}

configure_gpu_memory() {
    print_step "Configuring GPU memory split"
    
    CURRENT_GPU_MEM=$(vcgencmd get_mem gpu | cut -d'=' -f2 | cut -d'M' -f1)
    print_info "Current GPU memory: ${CURRENT_GPU_MEM}MB"
    
    if [ "$CURRENT_GPU_MEM" -lt "$GPU_MEMORY" ]; then
        print_info "Setting GPU memory to ${GPU_MEMORY}MB"
        
        # Backup original config
        sudo cp /boot/config.txt /boot/config.txt.backup
        
        # Remove any existing gpu_mem lines
        sudo sed -i '/^gpu_mem=/d' /boot/config.txt
        
        # Add new gpu_mem setting
        echo "gpu_mem=$GPU_MEMORY" | sudo tee -a /boot/config.txt > /dev/null
        
        print_info "GPU memory configuration updated (reboot required)"
        REBOOT_REQUIRED=true
    else
        print_success "GPU memory already sufficient: ${CURRENT_GPU_MEM}MB"
    fi
}

setup_permissions() {
    print_step "Setting up user permissions"
    
    # Add user to input group for touch access
    sudo usermod -a -G input $USER
    print_info "Added $USER to input group"
    
    # Add user to dialout group for serial access
    sudo usermod -a -G dialout $USER  
    print_info "Added $USER to dialout group"
    
    # Create udev rule for input devices
    sudo tee /etc/udev/rules.d/99-input.rules > /dev/null <<EOF
SUBSYSTEM=="input", GROUP="input", MODE="0664"
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", GROUP="dialout", MODE="0664"
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", GROUP="dialout", MODE="0664"
EOF
    print_info "Created udev rules for input and serial devices"
    
    print_success "Permissions configured"
}

clone_and_build() {
    print_step "Cloning and building RPiPlay"
    
    # Remove existing directory if present
    if [ -d "$INSTALL_DIR" ]; then
        print_info "Removing existing RPiPlay directory"
        rm -rf "$INSTALL_DIR"
    fi
    
    # Clone repository
    git clone https://github.com/FD-/RPiPlay.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Create build directory
    mkdir -p build
    cd build
    
    # Configure build
    print_info "Configuring build with CMake..."
    cmake .. 2>&1 | tee cmake_output.log
    
    # Check if OpenMAX was found
    if grep -q "Found OpenMAX libraries for Raspberry Pi" cmake_output.log; then
        print_success "OpenMAX libraries detected - hardware acceleration enabled!"
    else
        print_info "OpenMAX not found - using GStreamer fallback"
    fi
    
    # Build
    print_info "Building RPiPlay (this may take several minutes)..."
    make -j$(nproc)
    
    # Install
    sudo make install
    
    print_success "RPiPlay built and installed successfully"
}

detect_devices() {
    print_step "Detecting input and serial devices"
    
    # Detect touch input devices
    print_info "Available input devices:"
    for device in /dev/input/event*; do
        if [ -e "$device" ]; then
            echo "  $device"
        fi
    done
    
    # Try to detect touch device
    DETECTED_TOUCH=""
    for device in /dev/input/event*; do
        if [ -e "$device" ]; then
            # Check if device has absolute coordinates (touchscreen)
            if timeout 1 cat "$device" >/dev/null 2>&1; then
                DETECTED_TOUCH="$device"
                break
            fi
        fi
    done
    
    if [ -n "$DETECTED_TOUCH" ]; then
        TOUCH_DEVICE="$DETECTED_TOUCH"
        print_success "Detected touch device: $TOUCH_DEVICE"
    else
        print_info "Could not auto-detect touch device, using default: $TOUCH_DEVICE"
    fi
    
    # Detect ESP32 serial devices
    print_info "Available serial devices:"
    for device in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -e "$device" ]; then
            echo "  $device"
        fi
    done
    
    # Try to detect ESP32
    DETECTED_ESP32=""
    for device in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -e "$device" ]; then
            DETECTED_ESP32="$device"
            break
        fi
    done
    
    if [ -n "$DETECTED_ESP32" ]; then
        ESP32_DEVICE="$DETECTED_ESP32"
        print_success "Detected serial device: $ESP32_DEVICE"
    else
        print_info "No ESP32 detected, using default: $ESP32_DEVICE"
    fi
}

create_launcher_script() {
    print_step "Creating launcher script"
    
    cat > "$HOME/start_rpiplay_touch.sh" <<EOF
#!/bin/bash

# RPiPlay Touch Control Launcher
# Generated by install script

ESP32_DEVICE="$ESP32_DEVICE"
TOUCH_DEVICE="$TOUCH_DEVICE"
IPHONE_RESOLUTION="$IPHONE_RESOLUTION"
RPI_RESOLUTION="$RPI_RESOLUTION"

echo "=========================================="
echo "  RPiPlay Touch Control"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  ESP32 Device: \$ESP32_DEVICE"
echo "  Touch Device: \$TOUCH_DEVICE"
echo "  iPhone Resolution: \$IPHONE_RESOLUTION"
echo "  RPi Resolution: \$RPI_RESOLUTION"
echo ""

# Check if devices exist
if [ ! -e "\$ESP32_DEVICE" ]; then
    echo "WARNING: ESP32 device \$ESP32_DEVICE not found"
    echo "Available serial devices:"
    ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "  None found"
    echo ""
fi

if [ ! -e "\$TOUCH_DEVICE" ]; then
    echo "WARNING: Touch device \$TOUCH_DEVICE not found"
    echo "Available input devices:"
    ls /dev/input/event* 2>/dev/null || echo "  None found"
    echo ""
fi

echo "Starting RPiPlay with touch control..."
echo "Press Ctrl+C to stop"
echo ""

# Start RPiPlay with touch control
exec rpiplay \\
    -esp32 "\$ESP32_DEVICE" \\
    -touch "\$TOUCH_DEVICE" \\
    -iphone "\$IPHONE_RESOLUTION" \\
    -rpi "\$RPI_RESOLUTION" \\
    -n "RPiPlay Touch" \\
    "\$@"
EOF

    chmod +x "$HOME/start_rpiplay_touch.sh"
    print_success "Launcher script created: $HOME/start_rpiplay_touch.sh"
}

create_systemd_service() {
    print_step "Creating systemd service"
    
    sudo tee /etc/systemd/system/rpiplay-touch.service > /dev/null <<EOF
[Unit]
Description=RPiPlay Touch Control Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$HOME
ExecStart=$HOME/start_rpiplay_touch.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    print_success "Systemd service created (not enabled by default)"
    print_info "To enable auto-start: sudo systemctl enable rpiplay-touch.service"
}

run_tests() {
    print_step "Running basic tests"
    
    # Test rpiplay installation
    if command -v rpiplay >/dev/null 2>&1; then
        print_success "rpiplay command available"
        rpiplay -h | head -3
    else
        print_error "rpiplay command not found!"
        return 1
    fi
    
    # Test device permissions
    if [ -r "$TOUCH_DEVICE" ]; then
        print_success "Touch device readable"
    else
        print_info "Touch device not readable (may need reboot)"
    fi
    
    if [ -r "$ESP32_DEVICE" ]; then
        print_success "ESP32 device readable"
    else
        print_info "ESP32 device not found or not readable"
    fi
}

show_next_steps() {
    print_step "Installation Complete!"
    
    echo -e "${GREEN}✓ RPiPlay with touch control installed successfully!${NC}\n"
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "1. ${YELLOW}Program your ESP32${NC} with the code from esp/main.ino"
    echo -e "2. ${YELLOW}Connect ESP32${NC} to RPi via USB"
    echo -e "3. ${YELLOW}Pair iPhone${NC} with ESP32 Bluetooth (device name: 'iPhone Remote')"
    
    if [ "$REBOOT_REQUIRED" = true ]; then
        echo -e "4. ${RED}REBOOT REQUIRED${NC} for GPU memory changes to take effect"
        echo -e "   Run: ${YELLOW}sudo reboot${NC}"
    fi
    
    echo -e "\n${BLUE}Usage:${NC}"
    echo -e "• Start manually: ${YELLOW}$HOME/start_rpiplay_touch.sh${NC}"
    echo -e "• Test without touch: ${YELLOW}rpiplay -n 'My RPi'${NC}"
    echo -e "• Enable auto-start: ${YELLOW}sudo systemctl enable rpiplay-touch.service${NC}"
    
    echo -e "\n${BLUE}Files Created:${NC}"
    echo -e "• Launcher script: $HOME/start_rpiplay_touch.sh"
    echo -e "• Service file: /etc/systemd/system/rpiplay-touch.service"
    echo -e "• Source code: $INSTALL_DIR"
    
    echo -e "\n${BLUE}Troubleshooting:${NC}"
    echo -e "• Check devices: ${YELLOW}ls /dev/ttyUSB* /dev/input/event*${NC}"
    echo -e "• Test ESP32: ${YELLOW}screen $ESP32_DEVICE 115200${NC}"
    echo -e "• Test touch: ${YELLOW}sudo cat $TOUCH_DEVICE${NC}"
    echo -e "• View logs: ${YELLOW}journalctl -u rpiplay-touch.service -f${NC}"
    
    echo -e "\n${GREEN}Ready to mirror your iPhone and control it with touch!${NC}\n"
}

# Main installation flow
main() {
    print_header
    
    check_raspberry_pi
    update_system
    install_dependencies
    install_videocore
    configure_gpu_memory
    setup_permissions
    clone_and_build
    detect_devices
    create_launcher_script
    create_systemd_service
    run_tests
    show_next_steps
    
    if [ "$REBOOT_REQUIRED" = true ]; then
        echo -e "\n${RED}REBOOT REQUIRED!${NC}"
        echo -e "Run: ${YELLOW}sudo reboot${NC}"
        echo -e "Then run: ${YELLOW}$HOME/start_rpiplay_touch.sh${NC}"
    else
        echo -e "\n${GREEN}Installation complete! You can now run:${NC}"
        echo -e "${YELLOW}$HOME/start_rpiplay_touch.sh${NC}"
    fi
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root!"
    print_info "Run as regular user: bash install_rpiplay_touch.sh"
    exit 1
fi

# Run main installation
main "$@" 