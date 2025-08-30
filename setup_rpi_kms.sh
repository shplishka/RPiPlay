#!/bin/bash

# Raspberry Pi KMS/DRM Setup Script for RPiPlay
# This script configures the Raspberry Pi for optimal hardware-accelerated video playback using KMS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}  Raspberry Pi KMS/DRM Setup for RPiPlay${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_step() {
    echo -e "\n${GREEN}[STEP]${NC} $1\n"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# Check if running on Raspberry Pi
check_raspberry_pi() {
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_error "This script is designed for Raspberry Pi only!"
        exit 1
    fi
    
    # Detect Pi model
    pi_model=$(grep "Revision" /proc/cpuinfo | awk '{print $3}' | tail -1)
    print_success "Running on Raspberry Pi (Revision: $pi_model)"
}

# Backup current boot config
backup_boot_config() {
    print_step "Backing up boot configuration"
    
    if [ -f /boot/config.txt ]; then
        BOOT_CONFIG="/boot/config.txt"
    elif [ -f /boot/firmware/config.txt ]; then
        BOOT_CONFIG="/boot/firmware/config.txt"
    else
        print_error "Cannot find boot config file!"
        exit 1
    fi
    
    if [ ! -f "${BOOT_CONFIG}.backup" ]; then
        sudo cp "$BOOT_CONFIG" "${BOOT_CONFIG}.backup"
        print_success "Boot config backed up to ${BOOT_CONFIG}.backup"
    else
        print_info "Boot config backup already exists"
    fi
}

# Configure KMS in boot config
configure_kms() {
    print_step "Configuring KMS/DRM in boot configuration"
    
    # Remove conflicting settings
    print_info "Removing conflicting display settings..."
    sudo sed -i '/^dtoverlay=vc4-fkms-v3d/d' "$BOOT_CONFIG"
    sudo sed -i '/^dtoverlay=vc4-kms-v3d-pi4/d' "$BOOT_CONFIG"
    sudo sed -i '/^gpu_mem=/d' "$BOOT_CONFIG"
    sudo sed -i '/^disable_overscan=/d' "$BOOT_CONFIG"
    
    # Add KMS configuration
    print_info "Adding KMS configuration..."
    
    # Check if we already have the KMS section
    if ! grep -q "# RPiPlay KMS Configuration" "$BOOT_CONFIG"; then
        cat >> /tmp/kms_config <<EOF

# RPiPlay KMS Configuration
# Enable KMS (Kernel Mode Setting) for hardware acceleration
dtoverlay=vc4-kms-v3d
gpu_mem=128
disable_overscan=1

# Enable DRM (Direct Rendering Manager)
# This allows kmssink to access the display hardware directly
max_framebuffers=2
EOF
        
        sudo bash -c "cat /tmp/kms_config >> '$BOOT_CONFIG'"
        rm /tmp/kms_config
        print_success "KMS configuration added to boot config"
    else
        print_info "KMS configuration already exists in boot config"
    fi
}

# Install required packages
install_packages() {
    print_step "Installing required packages for KMS support"
    
    print_info "Updating package lists..."
    sudo apt update
    
    # Required packages for KMS and GStreamer
    packages=(
        "gstreamer1.0-plugins-bad"    # Contains kmssink
        "gstreamer1.0-plugins-good"   # Additional GStreamer plugins
        "gstreamer1.0-plugins-base"   # Base GStreamer plugins
        "gstreamer1.0-plugins-ugly"   # Ugly but useful plugins
        "gstreamer1.0-libav"          # FFmpeg integration
        "libdrm2"                     # Direct Rendering Manager
        "libdrm-dev"                  # DRM development headers
        "libkms1"                     # Kernel Mode Setting library
        "mesa-utils"                  # Mesa utilities for testing
        "libgl1-mesa-dri"             # Mesa DRI drivers
        "libgles2-mesa"               # OpenGL ES support
        "libegl1-mesa"                # EGL support
    )
    
    print_info "Installing packages: ${packages[*]}"
    
    if sudo apt install -y "${packages[@]}"; then
        print_success "All packages installed successfully"
    else
        print_error "Failed to install some packages"
        exit 1
    fi
}

# Configure user permissions
configure_permissions() {
    print_step "Configuring user permissions for hardware access"
    
    # Add user to video group for GPU access
    if ! groups "$USER" | grep -q video; then
        sudo usermod -a -G video "$USER"
        print_success "Added user '$USER' to video group"
    else
        print_info "User '$USER' already in video group"
    fi
    
    # Add user to render group for modern GPU access
    if ! groups "$USER" | grep -q render; then
        sudo usermod -a -G render "$USER"
        print_success "Added user '$USER' to render group"
    else
        print_info "User '$USER' already in render group"
    fi
    
    # Set up udev rules for DRM devices
    print_info "Setting up udev rules for DRM device access..."
    
    cat > /tmp/99-drm.rules <<EOF
# Allow users in video group to access DRM devices
KERNEL=="card[0-9]*", GROUP="video", MODE="0664"
KERNEL=="renderD[0-9]*", GROUP="render", MODE="0664"
KERNEL=="controlD[0-9]*", GROUP="video", MODE="0664"
EOF
    
    sudo mv /tmp/99-drm.rules /etc/udev/rules.d/
    print_success "DRM udev rules configured"
}

# Test KMS functionality
test_kms() {
    print_step "Testing KMS/DRM functionality"
    
    # Check for DRM devices
    print_info "Checking for DRM devices..."
    if ls /dev/dri/card* >/dev/null 2>&1; then
        for device in /dev/dri/card*; do
            print_success "Found DRM device: $device"
        done
    else
        print_warning "No DRM devices found - KMS may not be enabled yet"
        print_info "This is normal if you haven't rebooted since configuration"
    fi
    
    # Test GStreamer kmssink availability
    print_info "Testing GStreamer kmssink plugin..."
    if gst-inspect-1.0 kmssink >/dev/null 2>&1; then
        print_success "kmssink plugin is available"
    else
        print_error "kmssink plugin not found!"
        print_info "Try: sudo apt install gstreamer1.0-plugins-bad"
    fi
    
    # Test basic GStreamer pipeline
    print_info "Testing basic GStreamer pipeline with kmssink..."
    if timeout 3 gst-launch-1.0 videotestsrc num-buffers=10 ! kmssink >/dev/null 2>&1; then
        print_success "Basic kmssink pipeline test passed"
    else
        print_warning "Basic kmssink test failed - may work after reboot"
    fi
}

# Create optimized RPiPlay launcher
create_launcher() {
    print_step "Creating optimized RPiPlay launcher script"
    
    cat > rpiplay_kms.sh <<'EOF'
#!/bin/bash

# RPiPlay KMS Launcher
# Optimized for hardware-accelerated video playback on Raspberry Pi

# Set environment variables for optimal performance
export GST_DEBUG=2
export GST_PLUGIN_PATH=/usr/lib/arm-linux-gnueabihf/gstreamer-1.0
export DISPLAY=:0

# DRM/KMS specific environment
export GST_GL_PLATFORM=egl
export GST_GL_API=gles2
export GST_GL_WINDOW=drm

# Default devices - modify as needed
ESP32_DEVICE="/dev/ttyUSB0"
TOUCH_DEVICE="/dev/input/event0"  # Update this based on your touch device

# Default screen resolutions
IPHONE_RES="390x844"  # iPhone 14
RPI_RES="1920x1080"   # Full HD - adjust for your display

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -esp32)
            ESP32_DEVICE="$2"
            shift 2
            ;;
        -touch)
            TOUCH_DEVICE="$2"
            shift 2
            ;;
        -iphone)
            IPHONE_RES="$2"
            shift 2
            ;;
        -rpi)
            RPI_RES="$2"
            shift 2
            ;;
        -h|--help)
            echo "RPiPlay KMS Launcher"
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -esp32 DEVICE    ESP32 serial device (default: $ESP32_DEVICE)"
            echo "  -touch DEVICE    Touch input device (default: $TOUCH_DEVICE)"
            echo "  -iphone WxH      iPhone resolution (default: $IPHONE_RES)"
            echo "  -rpi WxH         RPi display resolution (default: $RPI_RES)"
            echo "  -h, --help       Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 -esp32 /dev/ttyUSB0 -touch /dev/input/event4"
            echo "  $0 -iphone 430x932 -rpi 1920x1080"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "  RPiPlay KMS Hardware Accelerated"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  ESP32 Device: $ESP32_DEVICE"
echo "  Touch Device: $TOUCH_DEVICE"
echo "  iPhone Resolution: $IPHONE_RES"
echo "  RPi Resolution: $RPI_RES"
echo ""

# Check devices exist
if [ ! -e "$ESP32_DEVICE" ]; then
    echo "WARNING: ESP32 device $ESP32_DEVICE not found"
fi

if [ ! -e "$TOUCH_DEVICE" ]; then
    echo "WARNING: Touch device $TOUCH_DEVICE not found"
fi

echo "Starting RPiPlay with KMS hardware acceleration..."
echo "Press Ctrl+C to stop."
echo ""

# Launch RPiPlay with optimized settings
exec rpiplay \
    -vr gstreamer \
    -ar gstreamer \
    -esp32 "$ESP32_DEVICE" \
    -touch "$TOUCH_DEVICE" \
    -iphone "$IPHONE_RES" \
    -rpi "$RPI_RES" \
    -n "RPi KMS Touch" \
    "$@"
EOF
    
    chmod +x rpiplay_kms.sh
    print_success "Created optimized launcher: rpiplay_kms.sh"
}

# Update existing scripts for KMS
update_existing_scripts() {
    print_step "Updating existing scripts for KMS compatibility"
    
    # Update rebuild_rpiplay.sh to use KMS-optimized settings
    if [ -f "rebuild_rpiplay.sh" ]; then
        if ! grep -q "KMS" rebuild_rpiplay.sh; then
            sed -i 's/rpiplay -d/rpiplay -d -vr gstreamer -ar gstreamer/g' rebuild_rpiplay.sh
            print_success "Updated rebuild_rpiplay.sh for KMS"
        fi
    fi
    
    # Update fix_touch_debug.sh
    if [ -f "fix_touch_debug.sh" ]; then
        if ! grep -q "gstreamer" fix_touch_debug.sh; then
            sed -i 's/exec rpiplay -d/exec rpiplay -d -vr gstreamer -ar gstreamer/g' fix_touch_debug.sh
            print_success "Updated fix_touch_debug.sh for KMS"
        fi
    fi
}

# Main execution
main() {
    print_header
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Don't run this script as root! Run as regular user."
        exit 1
    fi
    
    check_raspberry_pi
    backup_boot_config
    configure_kms
    install_packages
    configure_permissions
    test_kms
    create_launcher
    update_existing_scripts
    
    print_step "Setup Complete!"
    
    echo -e "${BLUE}What was configured:${NC}"
    echo "✅ KMS/DRM enabled in boot configuration"
    echo "✅ Required GStreamer plugins installed"
    echo "✅ User permissions configured for hardware access"
    echo "✅ Optimized RPiPlay launcher created"
    echo "✅ Existing scripts updated for KMS compatibility"
    echo ""
    
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. ${YELLOW}REBOOT${NC} your Raspberry Pi to enable KMS:"
    echo "   ${CYAN}sudo reboot${NC}"
    echo ""
    echo "2. After reboot, test the setup:"
    echo "   ${CYAN}./rpiplay_kms.sh${NC}"
    echo ""
    echo "3. Or use with specific devices:"
    echo "   ${CYAN}./rpiplay_kms.sh -esp32 /dev/ttyUSB0 -touch /dev/input/event4${NC}"
    echo ""
    
    echo -e "${BLUE}Benefits of KMS setup:${NC}"
    echo "• Hardware-accelerated video decoding and rendering"
    echo "• Lower CPU usage and better performance"
    echo "• Reduced latency for AirPlay mirroring"
    echo "• Better integration with Raspberry Pi GPU"
    echo ""
    
    print_warning "IMPORTANT: You must reboot for KMS changes to take effect!"
}

# Run main function
main "$@"
