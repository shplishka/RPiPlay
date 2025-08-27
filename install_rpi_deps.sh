#!/bin/bash

# RPiPlay Dependencies Installation Script for Raspberry Pi
# Based on README.md requirements
# Run with: bash install_rpi_deps.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}  RPiPlay Dependencies Installation${NC}"
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
    
    PI_MODEL=$(grep "Model" /proc/cpuinfo | cut -d ':' -f2 | xargs)
    print_info "Detected: $PI_MODEL"
}

update_system() {
    print_step "Updating system packages"
    
    sudo apt update -y
    sudo apt upgrade -y
    
    print_success "System updated"
}

install_gstreamer() {
    print_step "Installing GStreamer packages (as specified in README)"
    
    # GStreamer packages from README.md line 37
    sudo apt-get install -y \
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
    
    print_success "GStreamer packages installed"
}

install_build_tools() {
    print_step "Installing build tools and dependencies"
    
    # Essential packages from README.md lines 40-44
    sudo apt-get install -y cmake
    sudo apt-get install -y libavahi-compat-libdnssd-dev
    sudo apt-get install -y libplist-dev
    sudo apt-get install -y libssl-dev
    sudo apt-get install -y git
    
    # Additional essential build tools
    sudo apt-get install -y \
        build-essential \
        pkg-config \
        gcc \
        g++
    
    print_success "Build tools and dependencies installed"
}

install_raspberry_pi_libs() {
    print_step "Installing Raspberry Pi specific libraries"
    
    # VideoCore libraries for hardware acceleration
    sudo apt-get install -y \
        libraspberrypi-dev \
        libraspberrypi0 \
        libraspberrypi-bin
    
    print_success "Raspberry Pi libraries installed"
}

configure_gpu_memory() {
    print_step "Configuring GPU memory split"
    
    # Check current GPU memory
    CURRENT_GPU_MEM=$(vcgencmd get_mem gpu | cut -d'=' -f2 | cut -d'M' -f1)
    print_info "Current GPU memory: ${CURRENT_GPU_MEM}MB"
    
    # Recommend at least 128MB for Pi 4/5, 64MB for others
    RECOMMENDED_GPU_MEM=128
    if grep -q "Pi Zero" /proc/cpuinfo; then
        RECOMMENDED_GPU_MEM=64
    fi
    
    if [ "$CURRENT_GPU_MEM" -lt "$RECOMMENDED_GPU_MEM" ]; then
        print_info "Setting GPU memory to ${RECOMMENDED_GPU_MEM}MB (recommended for RPiPlay)"
        
        # Backup original config
        sudo cp /boot/config.txt /boot/config.txt.backup.$(date +%Y%m%d_%H%M%S)
        
        # Remove any existing gpu_mem lines
        sudo sed -i '/^gpu_mem=/d' /boot/config.txt
        
        # Add new gpu_mem setting
        echo "gpu_mem=$RECOMMENDED_GPU_MEM" | sudo tee -a /boot/config.txt > /dev/null
        
        print_info "GPU memory configuration updated"
        REBOOT_REQUIRED=true
    else
        print_success "GPU memory already sufficient: ${CURRENT_GPU_MEM}MB"
    fi
}

verify_installation() {
    print_step "Verifying installation"
    
    # Check if essential commands are available
    MISSING_DEPS=()
    
    if ! command -v cmake >/dev/null 2>&1; then
        MISSING_DEPS+=("cmake")
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        MISSING_DEPS+=("git")
    fi
    
    if ! pkg-config --exists gstreamer-1.0; then
        MISSING_DEPS+=("gstreamer-1.0")
    fi
    
    if ! pkg-config --exists openssl; then
        MISSING_DEPS+=("openssl")
    fi
    
    if ! pkg-config --exists libplist-2.0; then
        MISSING_DEPS+=("libplist")
    fi
    
    if ! pkg-config --exists avahi-compat-libdns_sd; then
        MISSING_DEPS+=("avahi")
    fi
    
    if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
        print_success "All dependencies verified successfully!"
    else
        print_error "Missing dependencies: ${MISSING_DEPS[*]}"
        return 1
    fi
    
    # Check VideoCore libraries
    if [ -f "/opt/vc/lib/libopenmaxil.so" ]; then
        print_success "VideoCore/OpenMAX libraries found"
    else
        print_info "VideoCore libraries not found - will use GStreamer fallback"
    fi
}

show_build_instructions() {
    print_step "Next Steps - Building RPiPlay"
    
    echo -e "${BLUE}Now you can build RPiPlay:${NC}\n"
    
    echo -e "${YELLOW}1. Clone the repository:${NC}"
    echo -e "   git clone https://github.com/FD-/RPiPlay.git"
    echo -e "   cd RPiPlay"
    echo ""
    
    echo -e "${YELLOW}2. Build with CMake:${NC}"
    echo -e "   mkdir build"
    echo -e "   cd build"
    echo -e "   cmake .."
    echo -e "   make -j\$(nproc)"
    echo ""
    
    echo -e "${YELLOW}3. Install (optional):${NC}"
    echo -e "   sudo make install"
    echo ""
    
    if [ "$REBOOT_REQUIRED" = true ]; then
        echo -e "${RED}4. REBOOT REQUIRED${NC} for GPU memory changes:"
        echo -e "   sudo reboot"
        echo ""
    fi
    
    echo -e "${BLUE}Performance Tips (from README):${NC}"
    echo -e "• Use wired network connection"
    echo -e "• Compile with optimization: cmake -DCMAKE_CXX_FLAGS=\"-O3\" -DCMAKE_C_FLAGS=\"-O3\" .."
    echo -e "• Don't use debug flags in production"
    echo -e "• Ensure no demanding tasks are running (especially on Pi Zero)"
    echo ""
    
    echo -e "${BLUE}Usage:${NC}"
    echo -e "• Basic: ${YELLOW}./rpiplay${NC}"
    echo -e "• With name: ${YELLOW}./rpiplay -n \"My RPi\"${NC}"
    echo -e "• Audio output: ${YELLOW}./rpiplay -a hdmi${NC} or ${YELLOW}./rpiplay -a analog${NC}"
    echo -e "• Rotation: ${YELLOW}./rpiplay -r 90${NC}"
    echo ""
}

show_summary() {
    print_step "Installation Summary"
    
    echo -e "${GREEN}✓ System updated${NC}"
    echo -e "${GREEN}✓ GStreamer packages installed${NC}"
    echo -e "${GREEN}✓ Build tools installed (cmake, git, gcc, etc.)${NC}"
    echo -e "${GREEN}✓ RPi libraries installed (VideoCore/OpenMAX)${NC}"
    echo -e "${GREEN}✓ Network libraries installed (Avahi, OpenSSL)${NC}"
    echo -e "${GREEN}✓ Apple protocol library installed (libplist)${NC}"
    
    if [ "$REBOOT_REQUIRED" = true ]; then
        echo -e "${YELLOW}! GPU memory configuration updated (reboot needed)${NC}"
    else
        echo -e "${GREEN}✓ GPU memory configuration OK${NC}"
    fi
    
    echo -e "\n${GREEN}All RPiPlay dependencies installed successfully!${NC}"
}

# Main installation flow
main() {
    print_header
    
    check_raspberry_pi
    update_system
    install_gstreamer
    install_build_tools
    install_raspberry_pi_libs
    configure_gpu_memory
    verify_installation
    show_summary
    show_build_instructions
    
    if [ "$REBOOT_REQUIRED" = true ]; then
        echo -e "\n${RED}IMPORTANT: Reboot required for GPU memory changes!${NC}"
        echo -e "Run: ${YELLOW}sudo reboot${NC}"
    else
        echo -e "\n${GREEN}Ready to build RPiPlay!${NC}"
    fi
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root!"
    print_info "Run as regular user: bash install_rpi_deps.sh"
    exit 1
fi

# Run main installation
main "$@"
