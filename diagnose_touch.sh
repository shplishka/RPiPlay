#!/bin/bash

# Touch Diagnostic Script for RPiPlay
# This script helps identify why touch input is not working

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} RPiPlay Touch Diagnostics${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_touch_devices() {
    print_step "Checking for touch input devices..."
    
    if [ -d "/dev/input" ]; then
        print_success "Input directory exists: /dev/input"
        
        # List all input devices
        echo "Available input devices:"
        ls -la /dev/input/event* 2>/dev/null || print_warning "No event devices found"
        
        # Check for common touch device names
        for device in /dev/input/event*; do
            if [ -e "$device" ]; then
                echo "  $device"
                
                # Try to get device info
                if command -v evtest >/dev/null 2>&1; then
                    echo "    Device info:"
                    timeout 2 evtest "$device" 2>/dev/null | head -5 || echo "    Cannot read device info"
                else
                    print_warning "evtest not installed - cannot get detailed device info"
                fi
            fi
        done
    else
        print_error "Input directory not found: /dev/input"
    fi
}

check_permissions() {
    print_step "Checking device permissions..."
    
    for device in /dev/input/event*; do
        if [ -e "$device" ]; then
            if [ -r "$device" ]; then
                print_success "$device is readable"
            else
                print_error "$device is not readable"
                echo "  Current permissions: $(ls -la $device)"
                echo "  Try: sudo chmod 644 $device"
                echo "  Or add user to input group: sudo usermod -a -G input $USER"
            fi
        fi
    done
}

check_user_groups() {
    print_step "Checking user groups..."
    
    groups_output=$(groups)
    echo "Current user groups: $groups_output"
    
    if echo "$groups_output" | grep -q "input"; then
        print_success "User is in 'input' group"
    else
        print_warning "User is NOT in 'input' group"
        echo "  Fix: sudo usermod -a -G input $USER && logout/login"
    fi
    
    if echo "$groups_output" | grep -q "video"; then
        print_success "User is in 'video' group"
    else
        print_warning "User is NOT in 'video' group"
        echo "  Fix: sudo usermod -a -G video $USER && logout/login"
    fi
}

check_touch_libraries() {
    print_step "Checking touch-related libraries..."
    
    # Check for libevdev
    if ldconfig -p | grep -q libevdev; then
        print_success "libevdev found"
    else
        print_error "libevdev not found"
        echo "  Install: sudo apt install libevdev-dev libevdev2"
    fi
    
    # Check for input libraries
    if ldconfig -p | grep -q libinput; then
        print_success "libinput found"
    else
        print_warning "libinput not found (optional)"
    fi
}

check_rpiplay_build() {
    print_step "Checking RPiPlay build and touch support..."
    
    if command -v rpiplay >/dev/null 2>&1; then
        print_success "rpiplay command found"
        
        # Check if touch flag is supported
        if rpiplay -h 2>&1 | grep -q "\-touch"; then
            print_success "Touch support compiled in RPiPlay"
        else
            print_error "Touch support NOT found in RPiPlay"
            echo "  RPiPlay may not be compiled with touch support"
            echo "  Check build configuration and recompile"
        fi
        
        # Show help for touch-related flags
        echo "Touch-related flags in rpiplay:"
        rpiplay -h 2>&1 | grep -E "(touch|esp32|iphone|rpi)" || echo "  No touch flags found"
        
    else
        print_error "rpiplay command not found"
        echo "  Install or build RPiPlay first"
    fi
}

check_esp32_device() {
    print_step "Checking ESP32 serial devices..."
    
    # Check for USB serial devices
    usb_devices=$(ls /dev/ttyUSB* 2>/dev/null || true)
    acm_devices=$(ls /dev/ttyACM* 2>/dev/null || true)
    
    if [ -n "$usb_devices" ] || [ -n "$acm_devices" ]; then
        print_success "Serial devices found:"
        [ -n "$usb_devices" ] && echo "  USB: $usb_devices"
        [ -n "$acm_devices" ] && echo "  ACM: $acm_devices"
        
        # Check permissions
        for device in $usb_devices $acm_devices; do
            if [ -r "$device" ] && [ -w "$device" ]; then
                print_success "$device has read/write access"
            else
                print_error "$device lacks proper permissions"
                echo "  Current permissions: $(ls -la $device)"
                echo "  Add user to dialout group: sudo usermod -a -G dialout $USER"
            fi
        done
    else
        print_warning "No serial devices found (ESP32 may not be connected)"
        echo "  Expected devices: /dev/ttyUSB0 or /dev/ttyACM0"
    fi
}

check_system_info() {
    print_step "System information..."
    
    echo "OS: $(uname -a)"
    echo "Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
    echo "Kernel: $(uname -r)"
    
    # Check if running in X11/Wayland
    if [ -n "$DISPLAY" ]; then
        print_success "Running in X11 environment: $DISPLAY"
    elif [ -n "$WAYLAND_DISPLAY" ]; then
        print_success "Running in Wayland environment: $WAYLAND_DISPLAY"
    else
        print_warning "Running in console/TTY mode"
        echo "  Touch coordinate mapping may need adjustment"
    fi
}

test_touch_device() {
    print_step "Testing touch device functionality..."
    
    # Find the most likely touch device
    touch_device=""
    for device in /dev/input/event*; do
        if [ -e "$device" ] && [ -r "$device" ]; then
            # Try to identify touch devices
            if command -v evtest >/dev/null 2>&1; then
                device_info=$(timeout 2 evtest "$device" 2>/dev/null | head -10 || true)
                if echo "$device_info" | grep -iq "touch\|finger\|screen"; then
                    touch_device="$device"
                    break
                fi
            else
                # Fallback - assume event4 is touch
                touch_device="/dev/input/event4"
                break
            fi
        fi
    done
    
    if [ -n "$touch_device" ]; then
        print_success "Potential touch device: $touch_device"
        
        if command -v evtest >/dev/null 2>&1; then
            echo "To test touch input manually, run:"
            echo "  sudo evtest $touch_device"
            echo "Then touch the screen to see if events are generated"
        else
            print_warning "Install evtest to test touch input: sudo apt install evtest"
        fi
    else
        print_error "No touch device found or accessible"
    fi
}

provide_solutions() {
    print_step "Common solutions..."
    
    echo "1. Permission issues:"
    echo "   sudo usermod -a -G input,video,dialout \$USER"
    echo "   logout and login again"
    echo ""
    echo "2. Device not found:"
    echo "   Check physical connections"
    echo "   Try different USB ports"
    echo "   Check dmesg for device detection"
    echo ""
    echo "3. RPiPlay not compiled with touch:"
    echo "   cd ~/RPiPlay && mkdir build && cd build"
    echo "   cmake .. && make -j4 && sudo make install"
    echo ""
    echo "4. Test touch manually:"
    echo "   sudo evtest /dev/input/event4"
    echo "   hexdump -C /dev/input/event4"
    echo ""
    echo "5. ESP32 issues:"
    echo "   Check ESP32 is programmed with correct firmware"
    echo "   Verify serial communication with: screen /dev/ttyUSB0 115200"
    echo ""
    echo "6. Coordinate mapping:"
    echo "   Use -iphone WxH and -rpi WxH flags to set resolutions"
    echo "   Example: -iphone 390x844 -rpi 800x480"
}

# Main execution
main() {
    print_header
    
    check_system_info
    echo
    
    check_touch_devices
    echo
    
    check_permissions
    echo
    
    check_user_groups
    echo
    
    check_touch_libraries
    echo
    
    check_rpiplay_build
    echo
    
    check_esp32_device
    echo
    
    test_touch_device
    echo
    
    provide_solutions
    
    echo
    print_step "Diagnostic complete!"
    echo "If issues persist, share this output for further assistance."
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root - some permission checks may not be accurate"
    echo
fi

main
