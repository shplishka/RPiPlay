#!/bin/bash

# RPiPlay Touch Control - Complete Test Suite
# Copy this script and all test*.sh scripts to Raspberry Pi

echo "=============================================="
echo "  RPiPlay Touch Control - Test Suite"
echo "=============================================="
echo ""
echo "This test suite will systematically check every component"
echo "of the touch control system to find and fix issues."
echo ""

echo "TEST SEQUENCE:"
echo "1. test1_check_rebuild.sh     - Check if RPiPlay has touch support"
echo "2. test2_check_devices.sh     - Check devices and permissions"
echo "3. test3_test_touch_raw.sh    - Test raw touch input"
echo "4. test4_test_esp32.sh        - Test ESP32 communication"
echo "5. test5_test_rpiplay_init.sh - Test RPiPlay initialization"
echo "6. test6_test_full_system.sh  - Test complete system"
echo ""

echo "USAGE OPTIONS:"
echo "A. Run individual tests: bash test1_check_rebuild.sh"
echo "B. Run all tests: bash run_all_tests.sh auto"
echo "C. Interactive mode: bash run_all_tests.sh"
echo ""

if [ "$1" = "auto" ]; then
    echo "Running all tests automatically..."
    echo ""
    
    # Test 1
    echo "========== TEST 1: Checking Rebuild =========="
    if bash test1_check_rebuild.sh; then
        echo "✅ Test 1 PASSED"
    else
        echo "❌ Test 1 FAILED - Fix and retry"
        exit 1
    fi
    
    echo ""
    
    # Test 2
    echo "========== TEST 2: Checking Devices =========="
    if bash test2_check_devices.sh; then
        echo "✅ Test 2 PASSED"
    else
        echo "❌ Test 2 FAILED - Fix and retry"
        exit 1
    fi
    
    echo ""
    
    # Test 3
    echo "========== TEST 3: Testing Touch Raw =========="
    echo "⚠ This test requires user interaction - touch screen when prompted"
    if bash test3_test_touch_raw.sh; then
        echo "✅ Test 3 PASSED"
    else
        echo "❌ Test 3 FAILED - Fix and retry"
        exit 1
    fi
    
    echo ""
    
    # Test 4
    echo "========== TEST 4: Testing ESP32 =========="
    echo "⚠ This test requires user verification - check ESP32 serial output"
    if bash test4_test_esp32.sh; then
        echo "✅ Test 4 PASSED"
    else
        echo "❌ Test 4 FAILED - Fix and retry"
        exit 1
    fi
    
    echo ""
    
    # Test 5
    echo "========== TEST 5: Testing RPiPlay Init =========="
    if bash test5_test_rpiplay_init.sh; then
        echo "✅ Test 5 PASSED"
    else
        echo "❌ Test 5 FAILED - Fix and retry"
        exit 1
    fi
    
    echo ""
    
    # Test 6
    echo "========== TEST 6: Testing Full System =========="
    echo "⚠ This test requires user interaction - touch screen during test"
    if bash test6_test_full_system.sh; then
        echo "✅ Test 6 PASSED"
        echo ""
        echo "🎉 ALL TESTS PASSED!"
        echo "Your touch control system is working!"
    else
        echo "❌ Test 6 FAILED - Check logs for details"
        exit 1
    fi
    
else
    echo "INTERACTIVE MODE:"
    echo ""
    echo "Run tests one by one, fixing issues as they're found."
    echo "Each test will give specific instructions if it fails."
    echo ""
    
    while true; do
        echo "Choose a test to run:"
        echo "1. Check RPiPlay rebuild"
        echo "2. Check devices and permissions"
        echo "3. Test raw touch input"
        echo "4. Test ESP32 communication"
        echo "5. Test RPiPlay initialization"
        echo "6. Test complete system"
        echo "7. Run all tests automatically"
        echo "0. Exit"
        echo ""
        
        read -p "Select test (0-7): " choice
        
        case $choice in
            1) bash test1_check_rebuild.sh ;;
            2) bash test2_check_devices.sh ;;
            3) bash test3_test_touch_raw.sh ;;
            4) bash test4_test_esp32.sh ;;
            5) bash test5_test_rpiplay_init.sh ;;
            6) bash test6_test_full_system.sh ;;
            7) bash "$0" auto ;;
            0) break ;;
            *) echo "Invalid option" ;;
        esac
        
        echo ""
        echo "Press Enter to continue..."
        read -r dummy
        echo ""
    done
fi

echo ""
echo "=============================================="
echo "TROUBLESHOOTING GUIDE:"
echo "=============================================="
echo ""
echo "If Test 1 fails (RPiPlay rebuild):"
echo "  cd ~/RPiPlay && rm -rf build && mkdir build && cd build"
echo "  cmake .. && make -j && sudo make install"
echo ""
echo "If Test 2 fails (devices/permissions):"
echo "  sudo chmod 666 /dev/input/event* /dev/ttyUSB*"
echo "  sudo usermod -a -G input,dialout $USER && sudo reboot"
echo ""
echo "If Test 3 fails (touch raw):"
echo "  sudo apt install evtest && sudo evtest"
echo "  dmesg | grep -i touch"
echo "  Try different /dev/input/eventX devices"
echo ""
echo "If Test 4 fails (ESP32):"
echo "  Check ESP32 is programmed with main.ino"
echo "  screen /dev/ttyUSB0 115200"
echo "  Try different USB port/cable"
echo ""
echo "If Test 5 fails (initialization):"
echo "  Check logs: cat /tmp/rpiplay_init.log"
echo "  Verify previous tests all passed"
echo ""
echo "If Test 6 fails (full system):"
echo "  Check logs: cat /tmp/rpiplay_full_test.log"
echo "  Verify ESP32 paired with iPhone Bluetooth"
echo "  Check ESP32 LED is on when iPhone connected"
echo ""
echo "==============================================" 