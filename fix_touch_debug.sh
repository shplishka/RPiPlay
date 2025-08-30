#!/bin/bash

# Fix Touch Debug Script
# This script rebuilds RPiPlay with enhanced debugging and tests the touch functionality

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}  RPiPlay Touch Debug Fix${NC}"
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
    echo -e "${GREEN}[OK]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "rpiplay.cpp" ] || [ ! -d "lib" ]; then
    print_error "Please run this script from the RPiPlay source directory"
    exit 1
fi

print_header

print_step "Applied fixes:"
echo "1. Increased touch tap detection threshold from 20 to 50 pixels"
echo "2. Added comprehensive debug logging to touch handler"
echo "3. Added debug logging to ESP32 communication"
echo "4. Enhanced error reporting for initialization"
echo ""

print_step "Rebuilding RPiPlay with debug enhancements"

# Create build directory if it doesn't exist
if [ ! -d "build" ]; then
    mkdir build
    print_info "Created build directory"
fi

cd build

# Clean previous build
print_info "Cleaning previous build..."
make clean 2>/dev/null || true
rm -f CMakeCache.txt

# Configure and build
print_info "Configuring build..."
if cmake .. -DCMAKE_BUILD_TYPE=Debug; then
    print_success "CMake configuration successful"
else
    print_error "CMake configuration failed"
    exit 1
fi

print_info "Building RPiPlay..."
if make -j$(nproc); then
    print_success "Build successful"
else
    print_error "Build failed"
    exit 1
fi

# Install
print_info "Installing RPiPlay..."
if sudo make install; then
    print_success "Installation successful"
else
    print_error "Installation failed"
    exit 1
fi

cd ..

print_step "Testing the fix"

# Check if rpiplay has the new options
if rpiplay -h | grep -q "esp32"; then
    print_success "RPiPlay has ESP32 support"
else
    print_error "RPiPlay missing ESP32 support"
    exit 1
fi

if rpiplay -h | grep -q "touch"; then
    print_success "RPiPlay has touch support"
else
    print_error "RPiPlay missing touch support"
    exit 1
fi

print_step "Device detection"

# Find ESP32 device
ESP32_DEVICE=""
for device in /dev/ttyUSB* /dev/ttyACM*; do
    if [ -e "$device" ] && [ -w "$device" ]; then
        ESP32_DEVICE="$device"
        print_success "Found ESP32 device: $ESP32_DEVICE"
        break
    fi
done

if [ -z "$ESP32_DEVICE" ]; then
    print_error "No writable ESP32 device found"
    echo "Available devices:"
    ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "  None found"
    echo ""
    echo "Fix: sudo chmod 666 /dev/ttyUSB* /dev/ttyACM*"
    echo "Or: sudo usermod -a -G dialout $USER && reboot"
    ESP32_DEVICE="/dev/ttyUSB0"  # Use default for testing
fi

# Find touch device
TOUCH_DEVICE=""
for device in /dev/input/event*; do
    if [ -e "$device" ] && [ -r "$device" ]; then
        TOUCH_DEVICE="$device"
        print_success "Found touch device: $TOUCH_DEVICE"
        break
    fi
done

if [ -z "$TOUCH_DEVICE" ]; then
    print_error "No readable touch device found"
    echo "Available devices:"
    ls -la /dev/input/event* 2>/dev/null || echo "  None found"
    echo ""
    echo "Fix: sudo chmod 666 /dev/input/event*"
    echo "Or: sudo usermod -a -G input $USER && reboot"
    TOUCH_DEVICE="/dev/input/event0"  # Use default for testing
fi

print_step "Creating test script"

cat > test_touch_debug.sh <<EOF
#!/bin/bash

echo "=========================================="
echo "  RPiPlay Touch Debug Test"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  ESP32 Device: $ESP32_DEVICE"
echo "  Touch Device: $TOUCH_DEVICE"
echo ""
echo "What to look for:"
echo "1. 'DEBUG: ESP32 communication successfully initialized'"
echo "2. 'DEBUG: Touch handler successfully initialized and started'"
echo "3. When you touch the screen:"
echo "   - 'Touch DOWN detected at raw(X,Y) mapped(X,Y)'"
echo "   - 'Touch UP detected at raw(X,Y) mapped(X,Y)'"
echo "   - 'Sending CLICK event'"
echo "   - 'DEBUG: Sending CLICK command to ESP32'"
echo "   - 'Sent to ESP32: CLICK,X,Y' (from ESP32 communication)"
echo ""
echo "Starting RPiPlay with debug output..."
echo "Touch the screen and watch for the debug messages above."
echo "Press Ctrl+C to stop."
echo ""

# Start RPiPlay with both ESP32 and touch enabled, plus debug output
exec rpiplay -d \\
    -esp32 "$ESP32_DEVICE" \\
    -touch "$TOUCH_DEVICE" \\
    -iphone "390x844" \\
    -rpi "800x480" \\
    -n "Touch Debug Test"
EOF

chmod +x test_touch_debug.sh

print_success "Created test script: test_touch_debug.sh"

print_step "Summary"
echo -e "${BLUE}Changes made:${NC}"
echo "1. ✅ Enhanced touch detection threshold (20 → 50 pixels)"
echo "2. ✅ Added comprehensive debug logging"
echo "3. ✅ Better error reporting for initialization issues"
echo "4. ✅ Rebuilt and installed RPiPlay"
echo ""

echo -e "${BLUE}Next steps:${NC}"
echo "1. Run the test: ${YELLOW}./test_touch_debug.sh${NC}"
echo "2. Touch the screen and watch for debug messages"
echo "3. Look for the specific messages listed above"
echo ""

echo -e "${BLUE}If touch still doesn't work:${NC}"
echo "1. Check device permissions: ${YELLOW}ls -la $ESP32_DEVICE $TOUCH_DEVICE${NC}"
echo "2. Test raw touch data: ${YELLOW}sudo cat $TOUCH_DEVICE${NC} (touch screen)"
echo "3. Test ESP32 communication: ${YELLOW}echo 'STATUS' > $ESP32_DEVICE${NC}"
echo "4. Check groups: ${YELLOW}groups | grep -E 'input|dialout'${NC}"
echo ""

print_success "Fix applied successfully! Run ./test_touch_debug.sh to test."
