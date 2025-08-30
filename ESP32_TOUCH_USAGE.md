# ESP32 Touch Control for RPiPlay

This guide explains how to use the new ESP32 touch control functionality that allows you to control an iPhone by touching the Raspberry Pi screen.

## Hardware Setup

### Required Components
1. **Raspberry Pi** with touchscreen display
2. **ESP32 development board** (with BLE support)
3. **USB cable** to connect ESP32 to Raspberry Pi
4. **iPhone** with Bluetooth enabled

### Connections
1. Connect the ESP32 to the Raspberry Pi via USB cable
2. The ESP32 will appear as `/dev/ttyUSB0` (or similar) on the RPi
3. Make sure the RPi touchscreen is working and accessible at `/dev/input/event4`

## Software Setup

### 1. Program the ESP32
Upload the `esp/main.ino` file to your ESP32 using Arduino IDE:

1. Install the ESP32 Arduino Core
2. Install the `ESP32-BLE-Mouse` library by T-vK
3. Open `esp/main.ino` in Arduino IDE
4. Select your ESP32 board and port
5. Upload the sketch

### 2. Build RPiPlay with Touch Support
```bash
cd RPiPlay
mkdir build
cd build
cmake ..
make -j
sudo make install
```

### 3. Pair iPhone with ESP32
1. On your iPhone, go to Settings > Bluetooth
2. Put the ESP32 in pairing mode (it should appear as "iPhone Remote")
3. Pair with the ESP32
4. The ESP32 should now appear as a connected mouse device

## Usage

### Basic Usage
Start RPiPlay with ESP32 and touch support:
```bash
rpiplay -esp32 /dev/ttyUSB0 -touch /dev/input/event4
```

### Advanced Configuration
```bash
# Specify different devices and resolutions
rpiplay -esp32 /dev/ttyUSB0 -touch /dev/input/event1 -iphone 390x844 -rpi 800x480

# With custom AirPlay name
rpiplay -n "My RPi Touch" -esp32 /dev/ttyUSB0 -touch /dev/input/event4
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-esp32 device` | ESP32 serial device path | `/dev/ttyUSB0` |
| `-touch device` | Touch input device path | `/dev/input/event4` |
| `-iphone WxH` | iPhone screen resolution | `390x844` (iPhone 14) |
| `-rpi WxH` | RPi touchscreen resolution | `800x480` |

### Supported iPhone Resolutions
| iPhone Model | Resolution | Command |
|--------------|------------|---------|
| iPhone 14 Pro Max | 430x932 | `-iphone 430x932` |
| iPhone 14 Pro | 393x852 | `-iphone 393x852` |
| iPhone 14 | 390x844 | `-iphone 390x844` |
| iPhone 13 | 390x844 | `-iphone 390x844` |
| iPhone 12 | 390x844 | `-iphone 390x844` |
| iPhone SE (3rd gen) | 375x667 | `-iphone 375x667` |

## How It Works

1. **Touch Detection**: The RPi touchscreen generates Linux input events
2. **Coordinate Mapping**: Touch coordinates are mapped from RPi screen to iPhone screen proportionally
3. **Command Generation**: Touch events are converted to serial commands
4. **ESP32 Communication**: Commands are sent to ESP32 via serial connection
5. **BLE Mouse Emulation**: ESP32 sends mouse commands to iPhone via Bluetooth

### Supported Gestures
- **Tap**: Single finger tap → Click at coordinates
- **Vertical Scroll**: Drag vertically → Scroll up/down
- **Multi-tap**: Multiple quick taps → Multiple clicks

### Touch Event Flow
```
RPi Touchscreen → Linux Input Events → Touch Handler → ESP32 Commands → BLE Mouse → iPhone
```

## Troubleshooting

### ESP32 Not Detected
```bash
# Check if ESP32 is connected
ls -la /dev/ttyUSB*

# Check dmesg for device detection
dmesg | tail

# Try different USB port or cable
```

### Touch Not Working
```bash
# Check available input devices
ls -la /dev/input/event*

# Test touch input
sudo cat /dev/input/event4  # Should show data when touching

# Check permissions
sudo chmod 666 /dev/input/event4
```

### iPhone Not Pairing
1. Forget the ESP32 device from iPhone Bluetooth settings
2. Reset ESP32 and try pairing again
3. Check ESP32 serial output for debugging info

### Coordinate Mapping Issues
1. Verify your RPi touchscreen resolution with `fbset`
2. Adjust `-rpi WxH` parameter accordingly
3. Calibrate iPhone resolution if needed

## ESP32 Serial Commands

The ESP32 accepts these serial commands (you can also send them manually):

| Command | Description | Example |
|---------|-------------|---------|
| `GOTO,x,y` | Move cursor to coordinates | `GOTO,195,422` |
| `CLICK,x,y` | Click at coordinates | `CLICK,195,422` |
| `SCROLL_UP,x,y,amount` | Scroll up at coordinates | `SCROLL_UP,195,422,3` |
| `SCROLL_DOWN,x,y,amount` | Scroll down at coordinates | `SCROLL_DOWN,195,422,3` |
| `HOME` | Home cursor to (0,0) | `HOME` |
| `STATUS` | Show current status | `STATUS` |

### Manual Testing
```bash
# Connect to ESP32 directly
screen /dev/ttyUSB0 115200

# Send commands manually
CLICK,195,422
SCROLL_UP,195,422,3
STATUS
```

## Example Session

1. Start RPiPlay with touch control:
   ```bash
   rpiplay -esp32 /dev/ttyUSB0 -touch /dev/input/event4 -iphone 390x844
   ```

2. Connect iPhone to RPiPlay for screen mirroring

3. Touch the RPi screen - your touches will be translated to the iPhone!

4. The console will show debug output:
   ```
   Touch input enabled on /dev/input/event4
   ESP32 communication enabled on /dev/ttyUSB0
   Touch up/click at (195, 422)
   Sent to ESP32: CLICK,195,422
   ```

## Tips
- Start with AirPlay mirroring first, then test touch control
- Use two-finger scroll gestures for better scroll detection
- The coordinate mapping is proportional, so it works with any screen size ratio
- Check ESP32 serial output for debugging information
- Make sure iPhone Bluetooth is enabled and ESP32 is paired 