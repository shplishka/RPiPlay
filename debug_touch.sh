#!/bin/bash

# RPiPlay Touch Control Debug Script
# This script helps diagnose touch control issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}  RPiPlay Touch Control Diagnostics${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

print_step() {
    echo -e "\n${GREEN}[CHECK]${NC} $1\n"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

check_input_devices() {
    print_step "Checking input devices"
    
    echo "Available input devices:"
    for device in /dev/input/event*; do
        if [ -e "$device" ]; then
            # Get device info
            if command -v udevadm >/dev/null; then
                name=$(udevadm info --query=property --name="$device" | grep "ID_INPUT_TOUCHSCREEN=1" || true)
                if [ -n "$name" ]; then
                    print_success "$device (touchscreen detected)"
                else
                    echo "  $device"
                fi
            else
                echo "  $device"
            fi
        fi
    done
    
    # Test each device for touch events
    echo -e "\nTesting for touch events (touch screen for 3 seconds):"
    for device in /dev/input/event*; do
        if [ -e "$device" ]; then
            echo -n "Testing $device... "
            if timeout 3 cat "$device" >/dev/null 2>&1; then
                print_success "Activity detected!"
            else
                echo "No activity"
            fi
        fi
    done
}

check_permissions() {
    print_step "Checking permissions"
    
    # Check user groups
    groups_output=$(groups)
    if echo "$groups_output" | grep -q "input"; then
        print_success "User is in 'input' group"
    else
        print_error "User is NOT in 'input' group"
        echo "Fix: sudo usermod -a -G input $USER"
    fi
    
    if echo "$groups_output" | grep -q "dialout"; then
        print_success "User is in 'dialout' group"
    else
        print_error "User is NOT in 'dialout' group"
        echo "Fix: sudo usermod -a -G dialout $USER"
    fi
    
    # Check device permissions
    echo -e "\nDevice permissions:"
    for device in /dev/input/event*; do
        if [ -e "$device" ]; then
            perm=$(ls -l "$device")
            if [ -r "$device" ]; then
                print_success "$device readable"
            else
                print_error "$device NOT readable"
                echo "Fix: sudo chmod 666 $device"
            fi
        fi
    done
}

check_esp32() {
    print_step "Checking ESP32 connection"
    
    # Check for serial devices
    echo "Available serial devices:"
    found_serial=false
    for device in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -e "$device" ]; then
            echo "  $device"
            found_serial=true
            
            # Test if readable
            if [ -r "$device" ]; then
                print_success "$device is readable"
                
                # Try to communicate with ESP32
                echo -n "Testing ESP32 communication on $device... "
                if timeout 2 bash -c "echo 'STATUS' > $device && sleep 1" 2>/dev/null; then
                    print_success "Communication test sent"
                else
                    echo "Could not send command"
                fi
            else
                print_error "$device is NOT readable"
            fi
        fi
    done
    
    if [ "$found_serial" = false ]; then
        print_error "No serial devices found!"
        echo "Make sure ESP32 is connected via USB"
    fi
}

check_rpiplay() {
    print_step "Checking RPiPlay installation"
    
    if command -v rpiplay >/dev/null; then
        print_success "rpiplay command found"
        
        # Check version and features
        echo "RPiPlay help:"
        rpiplay -h | grep -E "(esp32|touch)" || echo "  No ESP32/touch options found - may need to rebuild"
        
    else
        print_error "rpiplay command NOT found"
        echo "Run the installation script first"
    fi
}

manual_touch_test() {
    print_step "Manual touch device test"
    
    echo "Select a device to test:"
    select device in /dev/input/event* "Skip test"; do
        if [ "$device" = "Skip test" ]; then
            break
        elif [ -e "$device" ]; then
            print_info "Testing $device - touch the screen now!"
            print_info "Press Ctrl+C to stop the test"
            echo ""
            
            # Monitor touch events
            timeout 10 cat "$device" | hexdump -C | head -20 || true
            echo ""
            print_info "If you saw output when touching, the device works!"
            break
        fi
    done
}

manual_esp32_test() {
    print_step "Manual ESP32 communication test"
    
    echo "Select ESP32 device to test:"
    select device in /dev/ttyUSB* /dev/ttyACM* "Skip test"; do
        if [ "$device" = "Skip test" ]; then
            break
        elif [ -e "$device" ]; then
            print_info "Testing ESP32 on $device"
            print_info "This will send commands to test communication"
            
            # Send test commands
            {
                echo "STATUS"
                sleep 1
                echo "RESET"
                sleep 1  
                echo "CLICK,100,200"
            } > "$device" 2>/dev/null || print_error "Could not send commands to $device"
            
            print_info "Commands sent. Check ESP32 serial monitor for responses."
            break
        fi
    done
}

run_live_test() {
    print_step "Live RPiPlay test"
    
    echo "This will start RPiPlay with debug output."
    echo "Touch the screen and watch for debug messages."
    echo "Press Ctrl+C to stop."
    echo ""
    
    read -p "Press Enter to start, or Ctrl+C to skip..."
    
    # Find devices
    touch_device=""
    esp32_device=""
    
    for device in /dev/input/event*; do
        if [ -r "$device" ]; then
            touch_device="$device"
            break
        fi
    done
    
    for device in /dev/ttyUSB* /dev/ttyACM*; do
        if [ -r "$device" ]; then
            esp32_device="$device"
            break
        fi
    done
    
    if [ -z "$touch_device" ]; then
        print_error "No readable touch device found"
        return 1
    fi
    
    if [ -z "$esp32_device" ]; then
        print_error "No readable ESP32 device found"
        return 1
    fi
    
    print_info "Using touch device: $touch_device"
    print_info "Using ESP32 device: $esp32_device"
    
    # Start RPiPlay with debug
    rpiplay -d -touch "$touch_device" -esp32 "$esp32_device" -n "Debug Test"
}

show_solutions() {
    print_step "Common solutions"
    
    echo -e "${BLUE}If touch device not detected:${NC}"
    echo "1. Check all /dev/input/event* devices with: sudo cat /dev/input/eventX"
    echo "2. Install evtest: sudo apt install evtest"
    echo "3. Run evtest to identify touch device: sudo evtest"
    echo ""
    
    echo -e "${BLUE}If permission denied:${NC}"  
    echo "1. Add to groups: sudo usermod -a -G input,dialout $USER"
    echo "2. Set permissions: sudo chmod 666 /dev/input/event* /dev/ttyUSB*"
    echo "3. Create udev rules (see installation script)"
    echo "4. Reboot after group changes"
    echo ""
    
    echo -e "${BLUE}If ESP32 not responding:${NC}"
    echo "1. Check ESP32 is programmed with main.ino"
    echo "2. Open serial monitor at 115200 baud"
    echo "3. Send 'STATUS' command manually"
    echo "4. Check iPhone is paired with ESP32 Bluetooth"
    echo ""
    
    echo -e "${BLUE}If iPhone not controllable:${NC}"
    echo "1. Pair iPhone with ESP32 ('iPhone Remote' device)"
    echo "2. Enable Switch Control or AssistiveTouch on iPhone"
    echo "3. Trust the ESP32 as an input device"
    echo "4. Check ESP32 LED is on (indicates iPhone connection)"
    echo ""
    
    echo -e "${BLUE}Debug RPiPlay build:${NC}"
    echo "1. Rebuild with debug: cd ~/RPiPlay/build && make clean && cmake .. && make -j"
    echo "2. Check if touch/ESP32 options exist: rpiplay -h | grep -E 'esp32|touch'"
    echo "3. Run with debug logging: rpiplay -d ..."
}

interactive_menu() {
    while true; do
        echo -e "\n${BLUE}Choose a diagnostic test:${NC}"
        echo "1. Check input devices"
        echo "2. Check permissions"  
        echo "3. Check ESP32 connection"
        echo "4. Check RPiPlay installation"
        echo "5. Manual touch device test"
        echo "6. Manual ESP32 communication test"
        echo "7. Live RPiPlay test"
        echo "8. Show common solutions"
        echo "9. Run all checks"
        echo "0. Exit"
        echo ""
        
        read -p "Select option (0-9): " choice
        
        case $choice in
            1) check_input_devices ;;
            2) check_permissions ;;
            3) check_esp32 ;;
            4) check_rpiplay ;;
            5) manual_touch_test ;;
            6) manual_esp32_test ;;
            7) run_live_test ;;
            8) show_solutions ;;
            9) 
                check_input_devices
                check_permissions
                check_esp32
                check_rpiplay
                ;;
            0) break ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# Main function
main() {
    print_header
    
    if [ $# -eq 0 ]; then
        interactive_menu
    else
        # Run specific test based on argument
        case $1 in
            "devices") check_input_devices ;;
            "permissions") check_permissions ;;
            "esp32") check_esp32 ;;
            "rpiplay") check_rpiplay ;;
            "all") 
                check_input_devices
                check_permissions
                check_esp32
                check_rpiplay
                ;;
            *) 
                echo "Usage: $0 [devices|permissions|esp32|rpiplay|all]"
                echo "Or run without arguments for interactive mode"
                ;;
        esac
    fi
}

main "$@" 