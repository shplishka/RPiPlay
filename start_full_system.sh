#!/bin/bash

# RPiPlay Complete System Startup Script
# This script starts the complete RPiPlay system with all components
# Run with: bash start_full_system.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
ESP32_DEVICE="/dev/ttyUSB0"
TOUCH_DEVICE="/dev/input/event0"
IPHONE_RESOLUTION="390x844"
RPI_RESOLUTION="800x480"
LOG_FILE="/tmp/rpiplay_system.log"
PID_FILE="/tmp/rpiplay_system.pid"

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}    RPiPlay Complete System Startup${NC}"
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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  start         Start the full system (default)"
    echo "  stop          Stop the running system"
    echo "  restart       Restart the system"
    echo "  status        Show system status"
    echo "  test          Run system tests"
    echo "  debug         Start with debug output"
    echo "  --esp32 DEV   ESP32 device (default: $ESP32_DEVICE)"
    echo "  --touch DEV   Touch device (default: $TOUCH_DEVICE)"
    echo "  --iphone RES  iPhone resolution (default: $IPHONE_RESOLUTION)"
    echo "  --rpi RES     RPi resolution (default: $RPI_RESOLUTION)"
    echo "  --help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 start                          # Start with defaults"
    echo "  $0 debug                          # Start with debug output"
    echo "  $0 --esp32 /dev/ttyUSB1 start     # Use different ESP32 device"
    echo "  $0 test                           # Run system tests"
    echo ""
}

check_prerequisites() {
    print_step "Checking system prerequisites"
    
    local errors=0
    
    # Check if RPiPlay is installed
    if ! command -v rpiplay >/dev/null 2>&1; then
        print_error "RPiPlay not found in PATH"
        print_info "Install with: bash install_rpiplay_touch.sh"
        errors=$((errors + 1))
    else
        print_success "RPiPlay found"
        
        # Check if it has touch support
        if rpiplay -h 2>/dev/null | grep -q "touch"; then
            print_success "RPiPlay has touch support"
        else
            print_warning "RPiPlay found but no touch support detected"
            print_info "Rebuild with: bash rebuild_rpiplay.sh"
        fi
    fi
    
    # Check ESP32 device
    if [ -e "$ESP32_DEVICE" ]; then
        if [ -w "$ESP32_DEVICE" ]; then
            print_success "ESP32 device accessible: $ESP32_DEVICE"
        else
            print_warning "ESP32 device found but not writable: $ESP32_DEVICE"
            print_info "Fix with: sudo chmod 666 $ESP32_DEVICE"
        fi
    else
        print_warning "ESP32 device not found: $ESP32_DEVICE"
        print_info "Available serial devices:"
        ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || print_info "  None found"
        
        # Try to find alternative devices
        for alt_device in /dev/ttyUSB1 /dev/ttyACM0 /dev/ttyACM1; do
            if [ -e "$alt_device" ]; then
                print_info "Alternative found: $alt_device"
                break
            fi
        done
    fi
    
    # Check touch device
    if [ -e "$TOUCH_DEVICE" ]; then
        if [ -r "$TOUCH_DEVICE" ]; then
            print_success "Touch device accessible: $TOUCH_DEVICE"
        else
            print_warning "Touch device found but not readable: $TOUCH_DEVICE"
            print_info "Fix with: sudo chmod 666 $TOUCH_DEVICE"
        fi
    else
        print_warning "Touch device not found: $TOUCH_DEVICE"
        print_info "Available input devices:"
        ls /dev/input/event* 2>/dev/null || print_info "  None found"
        
        # Try to find alternative devices
        for alt_device in /dev/input/event1 /dev/input/event2 /dev/input/event3 /dev/input/event4; do
            if [ -e "$alt_device" ]; then
                print_info "Alternative found: $alt_device"
                break
            fi
        done
    fi
    
    # Check permissions
    print_info "Checking user permissions..."
    if groups | grep -q input; then
        print_success "User is in 'input' group"
    else
        print_warning "User not in 'input' group"
        print_info "Add with: sudo usermod -a -G input $USER && sudo reboot"
    fi
    
    if groups | grep -q dialout; then
        print_success "User is in 'dialout' group"
    else
        print_warning "User not in 'dialout' group"
        print_info "Add with: sudo usermod -a -G dialout $USER && sudo reboot"
    fi
    
    # Check GPU memory
    if command -v vcgencmd >/dev/null 2>&1; then
        GPU_MEM=$(vcgencmd get_mem gpu | cut -d'=' -f2 | cut -d'M' -f1)
        if [ "$GPU_MEM" -ge 128 ]; then
            print_success "GPU memory sufficient: ${GPU_MEM}MB"
        else
            print_warning "GPU memory low: ${GPU_MEM}MB (recommended: 128MB+)"
            print_info "Increase with: echo 'gpu_mem=128' | sudo tee -a /boot/config.txt && sudo reboot"
        fi
    fi
    
    return $errors
}

auto_detect_devices() {
    print_step "Auto-detecting devices"
    
    # Auto-detect ESP32
    for device in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyACM0 /dev/ttyACM1; do
        if [ -e "$device" ] && [ -w "$device" ]; then
            ESP32_DEVICE="$device"
            print_success "Auto-detected ESP32: $ESP32_DEVICE"
            break
        fi
    done
    
    # Auto-detect touch device
    for device in /dev/input/event0 /dev/input/event1 /dev/input/event2 /dev/input/event3 /dev/input/event4; do
        if [ -e "$device" ] && [ -r "$device" ]; then
            # Simple test to see if it might be a touchscreen
            if timeout 1 cat "$device" >/dev/null 2>&1; then
                TOUCH_DEVICE="$device"
                print_success "Auto-detected touch device: $TOUCH_DEVICE"
                break
            fi
        fi
    done
}

show_configuration() {
    print_step "System Configuration"
    echo -e "${CYAN}ESP32 Device:${NC}     $ESP32_DEVICE"
    echo -e "${CYAN}Touch Device:${NC}     $TOUCH_DEVICE"
    echo -e "${CYAN}iPhone Resolution:${NC} $IPHONE_RESOLUTION"
    echo -e "${CYAN}RPi Resolution:${NC}    $RPI_RESOLUTION"
    echo -e "${CYAN}Log File:${NC}         $LOG_FILE"
    echo -e "${CYAN}PID File:${NC}         $PID_FILE"
    echo ""
}

start_system() {
    print_step "Starting RPiPlay System"
    
    # Check if already running
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        print_error "System already running (PID: $(cat "$PID_FILE"))"
        print_info "Stop with: $0 stop"
        return 1
    fi
    
    # Remove old PID file
    rm -f "$PID_FILE"
    
    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "RPiPlay System Started: $(date)" > "$LOG_FILE"
    
    # Build command
    local cmd="rpiplay"
    local args=""
    
    # Add ESP32 support if device exists
    if [ -e "$ESP32_DEVICE" ]; then
        args="$args -esp32 '$ESP32_DEVICE'"
        print_info "ESP32 support enabled"
    else
        print_warning "ESP32 device not found, running without ESP32 support"
    fi
    
    # Add touch support if device exists
    if [ -e "$TOUCH_DEVICE" ]; then
        args="$args -touch '$TOUCH_DEVICE'"
        print_info "Touch support enabled"
    else
        print_warning "Touch device not found, running without touch support"
    fi
    
    # Add resolutions
    args="$args -iphone '$IPHONE_RESOLUTION' -rpi '$RPI_RESOLUTION'"
    
    # Add device name
    args="$args -n 'RPiPlay Touch System'"
    
    # Add debug if requested
    if [ "$DEBUG_MODE" = true ]; then
        args="$args -d"
        print_info "Debug mode enabled"
    fi
    
    print_info "Starting RPiPlay with command:"
    echo -e "${CYAN}$cmd $args${NC}"
    echo ""
    
    # Start the system
    if [ "$DEBUG_MODE" = true ]; then
        # Run in foreground with debug
        eval "$cmd $args" 2>&1 | tee -a "$LOG_FILE"
    else
        # Run in background
        eval "$cmd $args" >> "$LOG_FILE" 2>&1 &
        local pid=$!
        echo $pid > "$PID_FILE"
        
        # Wait a moment and check if it started successfully
        sleep 2
        if kill -0 $pid 2>/dev/null; then
            print_success "System started successfully (PID: $pid)"
            print_info "View logs with: tail -f $LOG_FILE"
            print_info "Stop with: $0 stop"
            
            # Show status after 5 seconds
            (
                sleep 5
                if kill -0 $pid 2>/dev/null; then
                    echo -e "\n${GREEN}[STATUS]${NC} System running normally after 5 seconds"
                    echo -e "${CYAN}Ready for iPhone connections!${NC}"
                    echo ""
                    echo "Next steps:"
                    echo "1. Make sure ESP32 is programmed with esp/main.ino"
                    echo "2. Pair iPhone with ESP32 Bluetooth ('iPhone Remote')"
                    echo "3. Connect iPhone to 'RPiPlay Touch System' in AirPlay"
                    echo "4. Touch the screen to control your iPhone!"
                else
                    echo -e "\n${RED}[ERROR]${NC} System stopped unexpectedly"
                    echo "Check logs: cat $LOG_FILE"
                fi
            ) &
        else
            print_error "System failed to start"
            print_info "Check logs: cat $LOG_FILE"
            rm -f "$PID_FILE"
            return 1
        fi
    fi
}

stop_system() {
    print_step "Stopping RPiPlay System"
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_info "Stopping process $pid"
            kill "$pid"
            
            # Wait for graceful shutdown
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            
            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                print_warning "Force killing process $pid"
                kill -9 "$pid"
            fi
            
            print_success "System stopped"
        else
            print_warning "Process not running"
        fi
        rm -f "$PID_FILE"
    else
        print_warning "No PID file found, system may not be running"
    fi
    
    # Also try to kill any rpiplay processes
    if pgrep rpiplay >/dev/null; then
        print_info "Killing any remaining rpiplay processes"
        pkill rpiplay || true
    fi
}

show_status() {
    print_step "System Status"
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_success "System running (PID: $pid)"
            
            # Show process info
            if command -v ps >/dev/null; then
                echo -e "${CYAN}Process Info:${NC}"
                ps -p "$pid" -o pid,ppid,cmd,etime,pcpu,pmem || true
                echo ""
            fi
            
            # Show log tail
            if [ -f "$LOG_FILE" ]; then
                echo -e "${CYAN}Recent Log (last 10 lines):${NC}"
                tail -10 "$LOG_FILE"
                echo ""
            fi
            
            # Show device status
            echo -e "${CYAN}Device Status:${NC}"
            [ -e "$ESP32_DEVICE" ] && echo "ESP32: ✅ $ESP32_DEVICE" || echo "ESP32: ❌ $ESP32_DEVICE (not found)"
            [ -e "$TOUCH_DEVICE" ] && echo "Touch: ✅ $TOUCH_DEVICE" || echo "Touch: ❌ $TOUCH_DEVICE (not found)"
            
        else
            print_error "PID file exists but process not running"
            print_info "Cleaning up stale PID file"
            rm -f "$PID_FILE"
        fi
    else
        print_info "System not running"
    fi
    
    # Show any other rpiplay processes
    if pgrep rpiplay >/dev/null; then
        echo -e "\n${CYAN}Other RPiPlay processes:${NC}"
        pgrep -a rpiplay || true
    fi
}

run_tests() {
    print_step "Running System Tests"
    
    if [ -f "run_all_tests.sh" ]; then
        print_info "Running comprehensive test suite"
        bash run_all_tests.sh auto
    else
        print_info "Running basic tests"
        
        # Basic functionality test
        if ! command -v rpiplay >/dev/null; then
            print_error "RPiPlay not installed"
            return 1
        fi
        
        print_success "RPiPlay installed"
        
        # Device tests
        [ -e "$ESP32_DEVICE" ] && print_success "ESP32 device found" || print_warning "ESP32 device not found"
        [ -e "$TOUCH_DEVICE" ] && print_success "Touch device found" || print_warning "Touch device not found"
        
        print_success "Basic tests completed"
    fi
}

# Parse command line arguments
DEBUG_MODE=false
ACTION="start"

while [[ $# -gt 0 ]]; do
    case $1 in
        start)
            ACTION="start"
            shift
            ;;
        stop)
            ACTION="stop"
            shift
            ;;
        restart)
            ACTION="restart"
            shift
            ;;
        status)
            ACTION="status"
            shift
            ;;
        test)
            ACTION="test"
            shift
            ;;
        debug)
            ACTION="start"
            DEBUG_MODE=true
            shift
            ;;
        --esp32)
            ESP32_DEVICE="$2"
            shift 2
            ;;
        --touch)
            TOUCH_DEVICE="$2"
            shift 2
            ;;
        --iphone)
            IPHONE_RESOLUTION="$2"
            shift 2
            ;;
        --rpi)
            RPI_RESOLUTION="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_header
    
    case $ACTION in
        start)
            check_prerequisites
            auto_detect_devices
            show_configuration
            start_system
            ;;
        stop)
            stop_system
            ;;
        restart)
            stop_system
            sleep 2
            check_prerequisites
            auto_detect_devices
            show_configuration
            start_system
            ;;
        status)
            show_status
            ;;
        test)
            run_tests
            ;;
        *)
            print_error "Invalid action: $ACTION"
            show_usage
            exit 1
            ;;
    esac
}

# Signal handlers
cleanup() {
    echo ""
    print_info "Received interrupt signal"
    if [ "$ACTION" = "start" ] && [ "$DEBUG_MODE" = true ]; then
        print_info "Stopping system..."
        stop_system
    fi
    exit 0
}

trap cleanup INT TERM

# Run main function
main "$@"