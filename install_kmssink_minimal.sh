#!/bin/bash

# Minimal KMS Setup for RPiPlay
# This script installs only the essential packages needed for kmssink to work

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

echo "=========================================="
echo "  Minimal KMS Setup for RPiPlay"
echo "=========================================="
echo ""

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    print_error "This script is designed for Raspberry Pi only!"
    exit 1
fi

print_info "Updating package lists..."
sudo apt update

print_info "Installing essential GStreamer packages for kmssink..."

# Core packages needed for kmssink
essential_packages=(
    "gstreamer1.0-plugins-bad"     # Contains kmssink plugin
    "gstreamer1.0-plugins-base"    # Base plugins
    "gstreamer1.0-plugins-good"    # Good plugins
    "libdrm2"                      # Direct Rendering Manager library
)

failed_packages=()

for package in "${essential_packages[@]}"; do
    print_info "Installing $package..."
    if sudo apt install -y "$package"; then
        print_success "✓ $package installed"
    else
        print_error "✗ Failed to install $package"
        failed_packages+=("$package")
    fi
done

echo ""
echo "=========================================="
echo "  Installation Summary"
echo "=========================================="

if [ ${#failed_packages[@]} -eq 0 ]; then
    print_success "All essential packages installed successfully!"
    echo ""
    
    # Test if kmssink is available
    print_info "Testing kmssink availability..."
    if gst-inspect-1.0 kmssink >/dev/null 2>&1; then
        print_success "✓ kmssink plugin is available and ready to use"
    else
        print_error "✗ kmssink plugin not found after installation"
        echo "Try running: sudo apt install --reinstall gstreamer1.0-plugins-bad"
    fi
    
else
    print_error "Failed to install these packages:"
    for package in "${failed_packages[@]}"; do
        echo "  - $package"
    done
    echo ""
    echo "Try installing them manually:"
    echo "sudo apt install ${failed_packages[*]}"
fi

echo ""
echo "=========================================="
echo "  Next Steps"
echo "=========================================="
echo ""
echo "1. Enable KMS in your boot config:"
echo "   Add these lines to /boot/config.txt (or /boot/firmware/config.txt):"
echo ""
echo "   # Enable KMS for hardware acceleration"
echo "   dtoverlay=vc4-kms-v3d"
echo "   gpu_mem=128"
echo ""
echo "2. Reboot your Raspberry Pi"
echo ""
echo "3. Rebuild RPiPlay with the updated kmssink renderer:"
echo "   ./rebuild_rpiplay.sh"
echo ""
echo "4. Test with:"
echo "   rpiplay -vr gstreamer"
echo ""

# Check current boot config
BOOT_CONFIG=""
if [ -f /boot/config.txt ]; then
    BOOT_CONFIG="/boot/config.txt"
elif [ -f /boot/firmware/config.txt ]; then
    BOOT_CONFIG="/boot/firmware/config.txt"
fi

if [ -n "$BOOT_CONFIG" ]; then
    echo "Current boot config location: $BOOT_CONFIG"
    if grep -q "vc4-kms-v3d" "$BOOT_CONFIG"; then
        print_success "✓ KMS appears to be already enabled in boot config"
    else
        print_info "! KMS not found in boot config - you'll need to add it manually"
    fi
fi

echo ""
print_info "Installation complete!"
