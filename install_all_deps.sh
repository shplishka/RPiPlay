#!/bin/bash

# RPiPlay - Complete Dependencies Installation Script for Raspberry Pi
# This script installs ALL dependencies required to build and run RPiPlay on Raspberry Pi
# Run with: bash install_all_deps.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
GPU_MEMORY_MIN=128
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/rpiplay_install.log"

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}  RPiPlay - Complete Dependencies Install${NC}"
    echo -e "${BLUE}============================================${NC}\n"
    echo -e "${CYAN}This script will install ALL dependencies required for RPiPlay${NC}"
    echo -e "${CYAN}including build tools, multimedia libraries, and system configs${NC}\n"
}

print_step() {
    echo -e "\n${GREEN}[STEP]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STEP: $1" >> "$LOG_FILE"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

check_system() {
    print_step "Checking system requirements"
    
    # Check if running on Raspberry Pi
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        print_error "This script is designed for Raspberry Pi only!"
        print_info "Detected system: $(uname -m)"
        exit 1
    fi
    
    # Get Pi model info
    PI_MODEL=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)
    PI_REVISION=$(grep "Revision" /proc/cpuinfo | awk '{print $3}')
    MEMORY=$(grep "MemTotal" /proc/meminfo | awk '{print int($2/1024)" MB"}')
    
    print_info "Raspberry Pi Model: $PI_MODEL"
    print_info "Revision: $PI_REVISION"
    print_info "Total Memory: $MEMORY"
    
    # Check OS version
    if [ -f /etc/os-release ]; then
        OS_NAME=$(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
        print_info "Operating System: $OS_NAME"
    fi
    
    # Check available disk space (need at least 2GB)
    AVAILABLE_SPACE=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
    if [ "$AVAILABLE_SPACE" -lt 2 ]; then
        print_warning "Low disk space: ${AVAILABLE_SPACE}GB available (2GB+ recommended)"
    else
        print_info "Available disk space: ${AVAILABLE_SPACE}GB"
    fi
    
    print_success "System check completed"
}

update_system() {
    print_step "Updating system packages"
    
    print_info "Updating package lists..."
    sudo apt update -y >> "$LOG_FILE" 2>&1
    
    print_info "Upgrading existing packages..."
    sudo apt upgrade -y >> "$LOG_FILE" 2>&1
    
    print_success "System packages updated"
}

install_build_tools() {
    print_step "Installing build tools and essential packages"
    
    print_info "Installing core build tools..."
    sudo apt install -y \
        build-essential \
        cmake \
        git \
        pkg-config \
        gcc \
        g++ \
        make \
        autoconf \
        automake \
        libtool \
        curl \
        wget \
        unzip \
        nano \
        screen \
        htop \
        >> "$LOG_FILE" 2>&1
    
    # Check GCC version
    GCC_VERSION=$(gcc --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    print_info "GCC Version: $GCC_VERSION"
    
    if [ "$(echo "$GCC_VERSION < 5.0" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
        print_warning "GCC version is less than 5.0 - may cause compilation issues"
    fi
    
    print_success "Build tools installed"
}

install_system_libraries() {
    print_step "Installing system libraries and development headers"
    
    print_info "Installing SSL and security libraries..."
    sudo apt install -y \
        libssl-dev \
        libcrypto++-dev \
        >> "$LOG_FILE" 2>&1
    
    print_info "Installing networking libraries..."
    sudo apt install -y \
        libavahi-compat-libdnssd-dev \
        libavahi-client-dev \
        libavahi-core-dev \
        avahi-daemon \
        >> "$LOG_FILE" 2>&1
    
    print_info "Installing Apple protocol libraries..."
    sudo apt install -y \
        libplist-dev \
        libplist3 \
        >> "$LOG_FILE" 2>&1
    
    print_info "Installing multimedia base libraries..."
    sudo apt install -y \
        libasound2-dev \
        libpulse-dev \
        libx11-dev \
        libxext-dev \
        libxrandr-dev \
        libxi-dev \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        >> "$LOG_FILE" 2>&1
    
    print_success "System libraries installed"
}

install_raspberry_pi_libraries() {
    print_step "Installing Raspberry Pi specific libraries"
    
    print_info "Installing VideoCore/OpenMAX libraries..."
    sudo apt install -y \
        libraspberrypi-dev \
        libraspberrypi0 \
        libraspberrypi-bin \
        >> "$LOG_FILE" 2>&1
    
    # Check if VideoCore libraries are properly installed
    if [ -d "/opt/vc/lib" ]; then
        print_info "VideoCore directory found at /opt/vc/"
        
        # List key OpenMAX libraries
        OPENMAX_LIBS=(
            "libopenmaxil.so"
            "libbcm_host.so"
            "libvcos.so"
            "libvchiq_arm.so"
            "libbrcmGLESv2.so"
            "libbrcmEGL.so"
        )
        
        MISSING_LIBS=0
        for lib in "${OPENMAX_LIBS[@]}"; do
            if [ -f "/opt/vc/lib/$lib" ]; then
                print_info "✓ Found: $lib"
            else
                print_warning "✗ Missing: $lib"
                MISSING_LIBS=$((MISSING_LIBS + 1))
            fi
        done
        
        if [ $MISSING_LIBS -eq 0 ]; then
            print_success "All OpenMAX libraries found - hardware acceleration available!"
        else
            print_warning "$MISSING_LIBS OpenMAX libraries missing - may need legacy GPU driver"
        fi
    else
        print_warning "VideoCore directory not found - OpenMAX may not be available"
        print_info "You may need to enable legacy GPU driver via raspi-config"
    fi
    
    print_success "Raspberry Pi libraries installed"
}

install_gstreamer() {
    print_step "Installing GStreamer multimedia framework"
    
    print_info "Installing GStreamer core..."
    sudo apt install -y \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev \
        libgstreamer-plugins-bad1.0-dev \
        libgstreamer-plugins-good1.0-dev \
        >> "$LOG_FILE" 2>&1
    
    print_info "Installing GStreamer plugins..."
    sudo apt install -y \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav \
        gstreamer1.0-tools \
        >> "$LOG_FILE" 2>&1
    
    print_info "Installing GStreamer output modules..."
    sudo apt install -y \
        gstreamer1.0-x \
        gstreamer1.0-alsa \
        gstreamer1.0-pulseaudio \
        gstreamer1.0-gl \
        gstreamer1.0-gtk3 \
        gstreamer1.0-qt5 \
        gstreamer1.0-vaapi \
        >> "$LOG_FILE" 2>&1
    
    # Verify GStreamer installation
    if command -v gst-launch-1.0 >/dev/null 2>&1; then
        GST_VERSION=$(gst-launch-1.0 --version | head -1 | awk '{print $4}')
        print_info "GStreamer version: $GST_VERSION"
        print_success "GStreamer installed and working"
    else
        print_error "GStreamer installation failed"
        return 1
    fi
    
    print_success "GStreamer multimedia framework installed"
}

install_audio_libraries() {
    print_step "Installing audio processing libraries"
    
    print_info "Installing ALSA libraries..."
    sudo apt install -y \
        libasound2-dev \
        alsa-utils \
        alsa-tools \
        >> "$LOG_FILE" 2>&1
    
    print_info "Installing PulseAudio libraries..."
    sudo apt install -y \
        libpulse-dev \
        pulseaudio \
        pulseaudio-utils \
        >> "$LOG_FILE" 2>&1
    
    print_info "Installing additional audio codecs..."
    sudo apt install -y \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libswresample-dev \
        >> "$LOG_FILE" 2>&1
    
    print_success "Audio libraries installed"
}

configure_gpu_memory() {
    print_step "Configuring GPU memory split"
    
    # Get current GPU memory
    CURRENT_GPU_MEM=$(vcgencmd get_mem gpu 2>/dev/null | cut -d'=' -f2 | cut -d'M' -f1 || echo "0")
    print_info "Current GPU memory: ${CURRENT_GPU_MEM}MB"
    
    if [ "$CURRENT_GPU_MEM" -lt "$GPU_MEMORY_MIN" ]; then
        print_info "Increasing GPU memory to ${GPU_MEMORY_MIN}MB for better performance"
        
        # Backup config
        sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)
        
        # Remove existing gpu_mem lines
        sudo sed -i '/^gpu_mem=/d' /boot/config.txt
        
        # Add new gpu_mem setting
        echo "gpu_mem=$GPU_MEMORY_MIN" | sudo tee -a /boot/config.txt > /dev/null
        
        print_info "GPU memory configuration updated"
        REBOOT_REQUIRED=true
    else
        print_success "GPU memory is already sufficient: ${CURRENT_GPU_MEM}MB"
    fi
}

setup_system_optimizations() {
    print_step "Applying system optimizations for media playback"
    
    print_info "Configuring system limits..."
    
    # Increase file descriptor limits
    sudo tee -a /etc/security/limits.conf > /dev/null <<EOF

# RPiPlay optimizations
* soft nofile 65536
* hard nofile 65536
EOF
    
    print_info "Configuring network optimizations..."
    
    # Network buffer optimizations
    sudo tee -a /etc/sysctl.conf > /dev/null <<EOF

# RPiPlay network optimizations
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF
    
    print_success "System optimizations applied"
}

setup_permissions() {
    print_step "Setting up user permissions and groups"
    
    # Add user to necessary groups
    GROUPS_TO_ADD=("audio" "video" "input" "dialout" "gpio" "spi" "i2c")
    
    for group in "${GROUPS_TO_ADD[@]}"; do
        if getent group "$group" >/dev/null; then
            sudo usermod -a -G "$group" "$USER"
            print_info "Added $USER to $group group"
        else
            print_info "Group $group does not exist, skipping"
        fi
    done
    
    # Create udev rules for device access
    print_info "Creating udev rules for device access..."
    sudo tee /etc/udev/rules.d/99-rpiplay.rules > /dev/null <<EOF
# RPiPlay device access rules
SUBSYSTEM=="input", GROUP="input", MODE="0664"
SUBSYSTEM=="video4linux", GROUP="video", MODE="0664"
SUBSYSTEM=="sound", GROUP="audio", MODE="0664"
# ESP32 serial devices
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", GROUP="dialout", MODE="0664"
SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", GROUP="dialout", MODE="0664"
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", GROUP="dialout", MODE="0664"
EOF
    
    print_success "User permissions configured"
}

install_optional_tools() {
    print_step "Installing optional development and debugging tools"
    
    print_info "Installing debugging tools..."
    sudo apt install -y \
        gdb \
        valgrind \
        strace \
        lsof \
        netstat \
        >> "$LOG_FILE" 2>&1
    
    print_info "Installing network tools..."
    sudo apt install -y \
        avahi-utils \
        nmap \
        tcpdump \
        wireshark-common \
        >> "$LOG_FILE" 2>&1
    
    print_info "Installing media inspection tools..."
    sudo apt install -y \
        ffmpeg \
        mediainfo \
        v4l-utils \
        >> "$LOG_FILE" 2>&1
    
    print_success "Optional tools installed"
}

verify_installation() {
    print_step "Verifying installation and dependencies"
    
    print_info "Checking build tools..."
    TOOLS_CHECK=(
        "gcc:GCC Compiler"
        "g++:G++ Compiler"
        "cmake:CMake Build System"
        "make:Make Build Tool"
        "git:Git Version Control"
        "pkg-config:Package Config"
    )
    
    for tool_info in "${TOOLS_CHECK[@]}"; do
        tool=$(echo "$tool_info" | cut -d: -f1)
        desc=$(echo "$tool_info" | cut -d: -f2)
        if command -v "$tool" >/dev/null 2>&1; then
            version=$($tool --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+[0-9.]*' | head -1 || echo "unknown")
            print_info "✓ $desc: $version"
        else
            print_error "✗ $desc: NOT FOUND"
        fi
    done
    
    print_info "Checking system libraries..."
    LIBS_CHECK=(
        "/usr/lib/*/libssl.so*:OpenSSL"
        "/usr/lib/*/libavahi-compat-libdns_sd.so*:Avahi DNS-SD"
        "/usr/lib/*/libplist.so*:libplist"
        "/usr/lib/*/libasound.so*:ALSA"
    )
    
    for lib_info in "${LIBS_CHECK[@]}"; do
        lib_pattern=$(echo "$lib_info" | cut -d: -f1)
        desc=$(echo "$lib_info" | cut -d: -f2)
        if ls $lib_pattern >/dev/null 2>&1; then
            print_info "✓ $desc: Found"
        else
            print_warning "✗ $desc: Not found"
        fi
    done
    
    print_info "Checking Raspberry Pi libraries..."
    if [ -d "/opt/vc/lib" ]; then
        OPENMAX_COUNT=$(ls /opt/vc/lib/lib*.so 2>/dev/null | wc -l)
        print_info "✓ VideoCore libraries: $OPENMAX_COUNT files found"
        
        if [ -f "/opt/vc/lib/libopenmaxil.so" ]; then
            print_success "✓ OpenMAX IL: Hardware acceleration available"
        else
            print_warning "✗ OpenMAX IL: Hardware acceleration may not work"
        fi
    else
        print_warning "✗ VideoCore directory not found"
    fi
    
    print_info "Checking GStreamer..."
    if command -v gst-launch-1.0 >/dev/null 2>&1; then
        GST_PLUGINS=$(gst-inspect-1.0 2>/dev/null | wc -l)
        print_info "✓ GStreamer: $GST_PLUGINS plugins available"
    else
        print_error "✗ GStreamer: Not found"
    fi
    
    print_success "Installation verification completed"
}

create_build_script() {
    print_step "Creating build script for RPiPlay"
    
    cat > "$SCRIPT_DIR/build_rpiplay.sh" <<'EOF'
#!/bin/bash

# RPiPlay Build Script
# Generated by install_all_deps.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

echo "========================================"
echo "  Building RPiPlay"
echo "========================================"
echo ""

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure build
echo "Configuring build with CMake..."
cmake .. -DCMAKE_BUILD_TYPE=Release

# Check configuration results
echo ""
echo "Build configuration:"
if grep -q "Found OpenMAX libraries for Raspberry Pi" CMakeFiles/CMakeOutput.log 2>/dev/null; then
    echo "✓ OpenMAX hardware acceleration: ENABLED"
else
    echo "⚠ OpenMAX hardware acceleration: DISABLED (using GStreamer fallback)"
fi

if grep -q "GST_FOUND" CMakeFiles/CMakeOutput.log 2>/dev/null; then
    echo "✓ GStreamer renderer: ENABLED"
else
    echo "⚠ GStreamer renderer: DISABLED"
fi

echo ""

# Build
echo "Building RPiPlay..."
make -j$(nproc)

echo ""
echo "Build completed successfully!"
echo "To install system-wide, run: sudo make install"
echo "To test locally, run: ./rpiplay -h"
EOF
    
    chmod +x "$SCRIPT_DIR/build_rpiplay.sh"
    print_success "Build script created: $SCRIPT_DIR/build_rpiplay.sh"
}

show_summary() {
    print_step "Installation Summary"
    
    echo -e "\n${GREEN}🎉 All dependencies installed successfully!${NC}\n"
    
    echo -e "${BLUE}What was installed:${NC}"
    echo -e "• Build tools (GCC, CMake, Git, etc.)"
    echo -e "• System libraries (OpenSSL, Avahi, libplist)"
    echo -e "• Raspberry Pi libraries (VideoCore/OpenMAX)"
    echo -e "• GStreamer multimedia framework"
    echo -e "• Audio libraries (ALSA, PulseAudio)"
    echo -e "• Development and debugging tools"
    echo -e "• System optimizations and permissions"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "1. ${YELLOW}Build RPiPlay:${NC}"
    echo -e "   cd $(pwd)"
    echo -e "   ./build_rpiplay.sh"
    echo -e ""
    echo -e "2. ${YELLOW}Install system-wide (optional):${NC}"
    echo -e "   cd build && sudo make install"
    echo -e ""
    echo -e "3. ${YELLOW}Test the installation:${NC}"
    echo -e "   ./build/rpiplay -h"
    
    if [ "$REBOOT_REQUIRED" = true ]; then
        echo -e "\n${RED}⚠️  REBOOT REQUIRED${NC}"
        echo -e "GPU memory configuration was changed. Please reboot before building:"
        echo -e "${YELLOW}sudo reboot${NC}"
    fi
    
    echo -e "\n${BLUE}Files created:${NC}"
    echo -e "• Build script: $SCRIPT_DIR/build_rpiplay.sh"
    echo -e "• Installation log: $LOG_FILE"
    echo -e "• Config backup: /boot/config.txt.backup.*"
    
    echo -e "\n${BLUE}For ESP32 touch control:${NC}"
    echo -e "• Use the existing install_rpiplay_touch.sh script"
    echo -e "• Program ESP32 with esp/main.ino"
    echo -e "• Connect ESP32 via USB"
    
    echo -e "\n${GREEN}Ready to build RPiPlay! 🚀${NC}\n"
}

# Main installation flow
main() {
    # Initialize log file
    echo "RPiPlay Dependencies Installation Log - $(date)" > "$LOG_FILE"
    
    print_header
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root!"
        print_info "Run as regular user: bash install_all_deps.sh"
        exit 1
    fi
    
    check_system
    update_system
    install_build_tools
    install_system_libraries
    install_raspberry_pi_libraries
    install_gstreamer
    install_audio_libraries
    configure_gpu_memory
    setup_system_optimizations
    setup_permissions
    install_optional_tools
    verify_installation
    create_build_script
    show_summary
    
    print_success "Installation completed successfully!"
    print_info "Log file saved to: $LOG_FILE"
}

# Run main installation
main "$@"
