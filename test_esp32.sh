#!/bin/bash

# ESP32 Test Script for RPiPlay
# This script tests ESP32 communication and command processing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}     ESP32 Test Script${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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

# Find ESP32 device
find_esp32_device() {
    print_step "Looking for ESP32 device..."
    
    ESP32_DEVICE=""
    
    # Check for USB devices
    for device in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -e "$device" ]; then
            print_success "Found serial device: $device"
            ESP32_DEVICE="$device"
            break
        fi
    done
    
    if [ -z "$ESP32_DEVICE" ]; then
        print_error "No ESP32 device found!"
        echo "Expected devices: /dev/ttyUSB0 or /dev/ttyACM0"
        echo "Make sure ESP32 is connected via USB"
        exit 1
    fi
    
    # Check permissions
    if [ -r "$ESP32_DEVICE" ] && [ -w "$ESP32_DEVICE" ]; then
        print_success "$ESP32_DEVICE has read/write access"
    else
        print_error "$ESP32_DEVICE lacks proper permissions"
        echo "Fix with: sudo usermod -a -G dialout \$USER && logout/login"
        exit 1
    fi
}

# Test serial communication
test_serial_communication() {
    print_step "Testing serial communication with ESP32..."
    
    # Send STATUS command and capture response
    echo "Sending STATUS command..."
    
    # Use timeout to prevent hanging
    if command -v timeout >/dev/null 2>&1; then
        echo "STATUS" > "$ESP32_DEVICE"
        sleep 2
        
        # Try to read response (non-blocking)
        if timeout 3 cat "$ESP32_DEVICE" 2>/dev/null | head -10; then
            print_success "ESP32 responded to STATUS command"
        else
            print_warning "No response from ESP32 (this might be normal if iPhone not connected)"
        fi
    else
        print_warning "timeout command not available - skipping response test"
    fi
}

# Send test commands
send_test_commands() {
    print_step "Sending test commands to ESP32..."
    
    echo "Sending test commands (check ESP32 serial monitor for responses):"
    echo
    
    # Array of test commands
    commands=(
        "STATUS"
        "HOME"
        "GOTO,100,200"
        "CLICK,150,300"
        "SCROLL_UP,200,400,3"
        "SCREEN,390,844"
    )
    
    for cmd in "${commands[@]}"; do
        echo -e "  → Sending: ${YELLOW}$cmd${NC}"
        echo "$cmd" > "$ESP32_DEVICE"
        sleep 1
    done
    
    print_success "Test commands sent"
}

# Interactive mode
interactive_mode() {
    print_step "Entering interactive mode..."
    echo "Type commands to send to ESP32 (or 'quit' to exit):"
    echo "Available commands:"
    echo "  STATUS                    - Show ESP32 status"
    echo "  HOME                     - Home cursor to (0,0)"
    echo "  GOTO,x,y                - Move to coordinates"
    echo "  CLICK,x,y               - Click at coordinates"
    echo "  SCROLL_UP,x,y,amount    - Scroll up"
    echo "  SCROLL_DOWN,x,y,amount  - Scroll down"
    echo "  SCREEN,width,height     - Set screen resolution"
    echo
    
    while true; do
        echo -n "ESP32> "
        read -r command
        
        if [ "$command" = "quit" ] || [ "$command" = "exit" ]; then
            break
        fi
        
        if [ -n "$command" ]; then
            echo -e "Sending: ${YELLOW}$command${NC}"
            echo "$command" > "$ESP32_DEVICE"
        fi
    done
}

# Monitor ESP32 output
monitor_esp32() {
    print_step "Monitoring ESP32 output..."
    echo "Press Ctrl+C to stop monitoring"
    echo "----------------------------------------"
    
    # Monitor serial output
    if command -v cat >/dev/null 2>&1; then
        cat "$ESP32_DEVICE" || print_warning "Could not read from ESP32 device"
    else
        print_error "Cannot monitor ESP32 output"
    fi
}

# Check ESP32 firmware
check_firmware() {
    print_step "Checking ESP32 firmware..."
    
    if [ -f "esp/main.ino" ]; then
        print_success "ESP32 firmware found: esp/main.ino"
        
        # Check if it contains expected functions
        if grep -q "handleCommand" esp/main.ino; then
            print_success "Firmware contains command handler"
        else
            print_warning "Firmware may be outdated"
        fi
        
        if grep -q "BleMouse" esp/main.ino; then
            print_success "Firmware contains BLE mouse support"
        else
            print_error "Firmware missing BLE mouse support"
        fi
    else
        print_warning "ESP32 firmware not found in esp/main.ino"
    fi
}

# Main menu
show_menu() {
    echo
    echo "Choose test option:"
    echo "1) Auto test (find device + send test commands)"
    echo "2) Interactive mode (manual command entry)"
    echo "3) Monitor ESP32 output"
    echo "4) Check firmware"
    echo "5) Exit"
    echo
}

# Main execution
main() {
    print_header
    
    while true; do
        show_menu
        echo -n "Select option [1-5]: "
        read -r choice
        
        case $choice in
            1)
                find_esp32_device
                test_serial_communication
                send_test_commands
                echo
                print_success "Auto test completed!"
                ;;
            2)
                find_esp32_device
                interactive_mode
                ;;
            3)
                find_esp32_device
                monitor_esp32
                ;;
            4)
                check_firmware
                ;;
            5)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-5."
                ;;
        esac
    done
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root - this may cause permission issues"
    echo
fi

main
