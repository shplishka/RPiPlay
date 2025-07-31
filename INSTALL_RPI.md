# Installing RPiPlay with Touch Control on Raspberry Pi

This guide shows how to install all dependencies and build RPiPlay with ESP32 touch control on Raspberry Pi.

## Prerequisites

- Raspberry Pi with Raspberry Pi OS (Bullseye or newer recommended)
- ESP32 development board
- Touchscreen display (official RPi touchscreen or compatible)
- Internet connection

## Step 1: Update System

```bash
sudo apt update && sudo apt upgrade -y
```

## Step 2: Install OpenMAX and VideoCore Libraries

The OpenMAX libraries are usually included with Raspberry Pi OS, but if missing:

```bash
# Install VideoCore libraries and headers
sudo apt install libraspberrypi-dev libraspberrypi0 libraspberrypi-bin

# Install development headers for VideoCore
sudo apt install libraspberrypi-dev

# Verify OpenMAX libraries exist
ls -la /opt/vc/lib/libopenmaxil.so
ls -la /opt/vc/lib/libbcm_host.so
```

If the `/opt/vc/` directory doesn't exist, you may need the legacy GPU driver:

```bash
# Enable legacy GPU driver (required for older Pi models)
sudo raspi-config
# Navigate to: Advanced Options > GL Driver > Legacy
# Reboot after changing
```

## Step 3: Install Build Dependencies

```bash
# Essential build tools
sudo apt install cmake build-essential git pkg-config

# OpenSSL and networking
sudo apt install libssl-dev libavahi-compat-libdnssd-dev

# plist library for Apple protocols
sudo apt install libplist-dev

# GStreamer (fallback renderer)
sudo apt install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools \
    gstreamer1.0-x gstreamer1.0-alsa gstreamer1.0-gl gstreamer1.0-gtk3 \
    gstreamer1.0-qt5 gstreamer1.0-pulseaudio
```

## Step 4: Clone and Build RPiPlay

```bash
cd ~
git clone https://github.com/FD-/RPiPlay.git
cd RPiPlay

# Create build directory
mkdir build
cd build

# Configure build (this will detect OpenMAX automatically)
cmake ..

# Build (use all CPU cores)
make -j$(nproc)

# Install system-wide
sudo make install
```

## Step 5: Verify OpenMAX Detection

During the cmake step, you should see:
```
-- Found OpenMAX libraries for Raspberry Pi
```

If you see:
```
-- OpenMAX libraries not found, skipping compilation of Raspberry Pi renderer
```

Then run this diagnostic:

```bash
# Check if VideoCore libraries exist
find /opt/vc -name "*.so" | head -10

# Check if headers exist
find /opt/vc -name "*.h" | head -10

# Verify GPU memory split (should be at least 64MB)
vcgencmd get_mem gpu

# Check GPU firmware
vcgencmd version
```

## Step 6: Fix Common OpenMAX Issues

### Issue 1: GPU Memory Too Low
```bash
# Edit config file
sudo nano /boot/config.txt

# Add or modify this line:
gpu_mem=128

# Reboot
sudo reboot
```

### Issue 2: Missing VideoCore Package
```bash
# Force reinstall VideoCore
sudo apt install --reinstall libraspberrypi0 libraspberrypi-dev libraspberrypi-bin

# Update firmware
sudo rpi-update

# Reboot
sudo reboot
```

### Issue 3: Wrong GPU Driver
```bash
# Switch to legacy driver
sudo raspi-config
# Advanced Options > GL Driver > Legacy
# Reboot
```

## Step 7: Set Up Touch Input Permissions

```bash
# Add user to input group
sudo usermod -a -G input $USER

# Set permissions for touch device
sudo chmod 666 /dev/input/event*

# Make permanent with udev rule
sudo tee /etc/udev/rules.d/99-input.rules > /dev/null <<EOF
SUBSYSTEM=="input", GROUP="input", MODE="0664"
EOF
```

## Step 8: Set Up ESP32 Serial Permissions

```bash
# Add user to dialout group for serial access
sudo usermod -a -G dialout $USER

# Log out and back in, or reboot
```

## Step 9: Test the Build

```bash
# Test basic functionality (should show help)
rpiplay -h

# Test with ESP32 and touch (adjust device paths as needed)
rpiplay -esp32 /dev/ttyUSB0 -touch /dev/input/event0 -iphone 390x844

# Test different renderer if OpenMAX doesn't work
rpiplay -vr gstreamer -ar gstreamer
```

## Troubleshooting OpenMAX

### Check GPU Memory Split
```bash
vcgencmd get_mem gpu
# Should return: gpu=128M or higher
```

### Verify OpenMAX Libraries
```bash
# These should all exist:
ls -la /opt/vc/lib/libopenmaxil.so
ls -la /opt/vc/lib/libbcm_host.so  
ls -la /opt/vc/lib/libvcos.so
ls -la /opt/vc/lib/libvchiq_arm.so
ls -la /opt/vc/lib/libbrcmGLESv2.so
ls -la /opt/vc/lib/libbrcmEGL.so
```

### Check Build Configuration
```bash
cd ~/RPiPlay/build
cmake .. 2>&1 | grep -i openmax
# Should show: "Found OpenMAX libraries for Raspberry Pi"
```

### Alternative: Use GStreamer Renderer
If OpenMAX still doesn't work, you can use GStreamer:
```bash
rpiplay -vr gstreamer -ar gstreamer -esp32 /dev/ttyUSB0 -touch /dev/input/event0
```

## Hardware-Specific Notes

### Raspberry Pi 4/5
- Use standard installation
- GPU memory: 128MB or higher
- Both legacy and KMS drivers work

### Raspberry Pi 3/3B+
- GPU memory: 128MB recommended
- Legacy driver usually required
- May need `dtoverlay=vc4-fkms-v3d` in `/boot/config.txt`

### Raspberry Pi Zero/Zero 2
- GPU memory: 64MB minimum, 128MB recommended
- Legacy driver required
- Performance will be limited

### Custom/Third-party Screens
```bash
# Find your touch device
ls /dev/input/event*

# Test which one is touch
sudo cat /dev/input/event0  # Should show data when touching
sudo cat /dev/input/event1  # Try each one

# Use the correct device with -touch parameter
rpiplay -touch /dev/input/event1
```

## Success Indicators

When everything works correctly, you should see:
```
RPiPlay 1.2: An open-source AirPlay mirroring server for Raspberry Pi
ESP32 communication enabled on /dev/ttyUSB0
Touch input enabled on /dev/input/event0
Coordinate mapping set: 800x480 -> 390x844
```

Now your iPhone should appear as "RPiPlay" in AirPlay, and touching the RPi screen will control the iPhone! 