#ifndef ESP32_COMM_H
#define ESP32_COMM_H

#include <string>
#include <thread>
#include <atomic>
#include <termios.h>

class ESP32Comm {
public:
    ESP32Comm();
    ~ESP32Comm();
    
    // Initialize connection to ESP32
    bool init(const std::string& device_path = "/dev/ttyUSB0", int baud_rate = 115200);
    
    // Close connection
    void close();
    
    // Check if connected
    bool is_connected() const;
    
    // Send commands to ESP32
    bool send_goto(int x, int y);
    bool send_click(int x, int y);
    bool send_scroll(int x, int y, int direction, int amount = 1);
    bool send_scroll_up(int x, int y, int amount = 3);
    bool send_scroll_down(int x, int y, int amount = 3);
    bool send_home();
    bool send_status();
    bool send_calibrate(int x, int y);
    bool send_screen_resolution(int width, int height);
    
    // Generic command sender
    bool send_command(const std::string& command);
    
    // Set iPhone screen resolution for coordinate mapping
    void set_iphone_resolution(int width, int height);
    
    // Get iPhone screen resolution
    int get_iphone_width() const { return iphone_width_; }
    int get_iphone_height() const { return iphone_height_; }

private:
    int serial_fd_;
    std::atomic<bool> connected_;
    struct termios old_termios_;
    
    int iphone_width_;
    int iphone_height_;
    
    // Helper functions
    bool configure_serial_port(int fd, int baud_rate);
    bool write_to_serial(const std::string& data);
};

#endif // ESP32_COMM_H 