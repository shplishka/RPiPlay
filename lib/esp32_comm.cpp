#include "esp32_comm.h"
#include <fcntl.h>
#include <unistd.h>
#include <cstring>
#include <iostream>
#include <sstream>

ESP32Comm::ESP32Comm() 
    : serial_fd_(-1), connected_(false), iphone_width_(390), iphone_height_(844) {
}

ESP32Comm::~ESP32Comm() {
    close();
}

bool ESP32Comm::init(const std::string& device_path, int baud_rate) {
    // Open serial port
    serial_fd_ = open(device_path.c_str(), O_RDWR | O_NOCTTY | O_NDELAY);
    if (serial_fd_ == -1) {
        std::cerr << "Error: Cannot open ESP32 serial device " << device_path << std::endl;
        return false;
    }
    
    // Configure serial port
    if (!configure_serial_port(serial_fd_, baud_rate)) {
        ::close(serial_fd_);
        serial_fd_ = -1;
        return false;
    }
    
    // Set non-blocking mode
    fcntl(serial_fd_, F_SETFL, FNDELAY);
    
    connected_ = true;
    std::cout << "ESP32 communication initialized on " << device_path 
              << " at " << baud_rate << " baud" << std::endl;
    
    // Send initial status command to verify connection
    send_status();
    
    return true;
}

void ESP32Comm::close() {
    if (serial_fd_ != -1) {
        // Restore original terminal settings
        tcsetattr(serial_fd_, TCSANOW, &old_termios_);
        ::close(serial_fd_);
        serial_fd_ = -1;
    }
    connected_ = false;
}

bool ESP32Comm::is_connected() const {
    return connected_;
}

bool ESP32Comm::send_goto(int x, int y) {
    std::ostringstream cmd;
    cmd << "MOVE," << x << "," << y;
    return send_command(cmd.str());
}

bool ESP32Comm::send_click(int x, int y) {
    std::ostringstream cmd;
    cmd << "CLICK," << x << "," << y;
    return send_command(cmd.str());
}

bool ESP32Comm::send_scroll(int x, int y, int direction, int amount) {
    std::ostringstream cmd;
    cmd << "SCROLL," << direction << "," << amount;
    return send_command(cmd.str());
}

bool ESP32Comm::send_scroll_up(int x, int y, int amount) {
    std::ostringstream cmd;
    cmd << "SCROLL," << 1 << "," << amount;  // 1 = up direction
    return send_command(cmd.str());
}

bool ESP32Comm::send_scroll_down(int x, int y, int amount) {
    std::ostringstream cmd;
    cmd << "SCROLL," << -1 << "," << amount;  // -1 = down direction
    return send_command(cmd.str());
}

bool ESP32Comm::send_home() {
    return send_command("RESET");  // ESP32 uses RESET instead of HOME
}

bool ESP32Comm::send_status() {
    return send_command("STATUS");
}

bool ESP32Comm::send_calibrate(int x, int y) {
    // ESP32 doesn't have a CALIBRATE command, use RESET to specified position
    std::ostringstream cmd;
    cmd << "RESET," << x << "," << y;
    return send_command(cmd.str());
}

bool ESP32Comm::send_screen_resolution(int width, int height) {
    std::ostringstream cmd;
    cmd << "SCREEN," << width << "," << height;
    return send_command(cmd.str());
}

bool ESP32Comm::send_command(const std::string& command) {
    if (!connected_ || serial_fd_ == -1) {
        std::cerr << "ESP32 not connected" << std::endl;
        return false;
    }
    
    std::string cmd_with_newline = command + "\n";
    return write_to_serial(cmd_with_newline);
}

void ESP32Comm::set_iphone_resolution(int width, int height) {
    iphone_width_ = width;
    iphone_height_ = height;
    std::cout << "iPhone resolution set to " << width << "x" << height << std::endl;
    
    // Also send to ESP32
    send_screen_resolution(width, height);
}

bool ESP32Comm::configure_serial_port(int fd, int baud_rate) {
    struct termios options;
    
    // Get current options
    if (tcgetattr(fd, &options) != 0) {
        std::cerr << "Error getting serial port attributes" << std::endl;
        return false;
    }
    
    // Save original settings
    old_termios_ = options;
    
    // Convert baud rate
    speed_t speed;
    switch (baud_rate) {
        case 9600:   speed = B9600; break;
        case 19200:  speed = B19200; break;
        case 38400:  speed = B38400; break;
        case 57600:  speed = B57600; break;
        case 115200: speed = B115200; break;
        case 230400: speed = B230400; break;
        default:
            std::cerr << "Unsupported baud rate: " << baud_rate << std::endl;
            return false;
    }
    
    // Set baud rate
    cfsetispeed(&options, speed);
    cfsetospeed(&options, speed);
    
    // Configure 8N1
    options.c_cflag &= ~PARENB;   // No parity
    options.c_cflag &= ~CSTOPB;   // 1 stop bit
    options.c_cflag &= ~CSIZE;    // Clear character size mask
    options.c_cflag |= CS8;       // 8 data bits
    
    // Enable receiver and set local mode
    options.c_cflag |= (CLOCAL | CREAD);
    
    // Disable hardware flow control
    options.c_cflag &= ~CRTSCTS;
    
    // Configure input options (raw input)
    options.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
    
    // Configure output options (raw output)
    options.c_oflag &= ~OPOST;
    
    // Configure local options (raw mode)
    options.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    
    // Set read timeout
    options.c_cc[VMIN] = 0;   // Return immediately
    options.c_cc[VTIME] = 1;  // 100ms timeout
    
    // Apply settings
    if (tcsetattr(fd, TCSANOW, &options) != 0) {
        std::cerr << "Error setting serial port attributes" << std::endl;
        return false;
    }
    
    // Flush buffers
    tcflush(fd, TCIOFLUSH);
    
    return true;
}

bool ESP32Comm::write_to_serial(const std::string& data) {
    ssize_t bytes_written = write(serial_fd_, data.c_str(), data.length());
    if (bytes_written < 0) {
        std::cerr << "Error writing to ESP32 serial port" << std::endl;
        return false;
    }
    
    if (static_cast<size_t>(bytes_written) != data.length()) {
        std::cerr << "Warning: Not all data written to ESP32 serial port" << std::endl;
        return false;
    }
    
    // Flush the output
    tcdrain(serial_fd_);
    
    std::cout << "Sent to ESP32: " << data.substr(0, data.length()-1) << std::endl;
    return true;
} 