#include "touch_handler.h"
#include <fcntl.h>
#include <unistd.h>
#include <iostream>
#include <sys/time.h>
#include <cstring>

TouchHandler::TouchHandler() 
    : input_fd_(-1), initialized_(false), running_(false),
      screen_width_(800), screen_height_(480),
      target_width_(390), target_height_(844),
      touch_active_(false), last_x_(0), last_y_(0), 
      current_x_(0), current_y_(0), last_touch_time_(0),
      scroll_start_y_(0), scroll_mode_(false) {
}

TouchHandler::~TouchHandler() {
    stop();
    close();
}

bool TouchHandler::init(const std::string& device_path) {
    // Open input device
    input_fd_ = open(device_path.c_str(), O_RDONLY | O_NONBLOCK);
    if (input_fd_ == -1) {
        std::cerr << "Error: Cannot open touch input device " << device_path << std::endl;
        return false;
    }
    
    // Check if device supports touch events
    unsigned long evbit = 0;
    if (ioctl(input_fd_, EVIOCGBIT(0, EV_MAX), &evbit) < 0) {
        std::cerr << "Error: Cannot get device capabilities" << std::endl;
        ::close(input_fd_);
        input_fd_ = -1;
        return false;
    }
    
    if (!(evbit & (1 << EV_ABS))) {
        std::cerr << "Error: Device does not support absolute positioning" << std::endl;
        ::close(input_fd_);
        input_fd_ = -1;
        return false;
    }
    
    initialized_ = true;
    std::cout << "Touch handler initialized on " << device_path << std::endl;
    
    return true;
}

void TouchHandler::close() {
    if (input_fd_ != -1) {
        ::close(input_fd_);
        input_fd_ = -1;
    }
    initialized_ = false;
}

bool TouchHandler::is_initialized() const {
    return initialized_;
}

void TouchHandler::set_touch_callback(TouchCallback callback) {
    touch_callback_ = callback;
}

void TouchHandler::set_screen_resolution(int width, int height) {
    screen_width_ = width;
    screen_height_ = height;
    std::cout << "Touch screen resolution set to " << width << "x" << height << std::endl;
}

void TouchHandler::set_coordinate_mapping(int rpi_width, int rpi_height, int target_width, int target_height) {
    screen_width_ = rpi_width;
    screen_height_ = rpi_height;
    target_width_ = target_width;
    target_height_ = target_height;
    
    std::cout << "Coordinate mapping set: " << rpi_width << "x" << rpi_height 
              << " -> " << target_width << "x" << target_height << std::endl;
}

void TouchHandler::start() {
    if (!initialized_ || running_) {
        return;
    }
    
    running_ = true;
    event_thread_ = std::thread(&TouchHandler::event_loop, this);
    std::cout << "Touch event processing started" << std::endl;
}

void TouchHandler::stop() {
    if (!running_) {
        return;
    }
    
    running_ = false;
    if (event_thread_.joinable()) {
        event_thread_.join();
    }
    std::cout << "Touch event processing stopped" << std::endl;
}

void TouchHandler::event_loop() {
    struct input_event event;
    
    while (running_) {
        ssize_t bytes_read = read(input_fd_, &event, sizeof(event));
        
        if (bytes_read == sizeof(event)) {
            process_event(event);
        } else if (bytes_read == -1) {
            // No data available, sleep briefly
            usleep(10000); // 10ms
        }
    }
}

void TouchHandler::process_event(const struct input_event& event) {
    static bool syn_report = false;
    
    switch (event.type) {
        case EV_ABS:
            if (event.code == ABS_X) {
                current_x_ = event.value;
            } else if (event.code == ABS_Y) {
                current_y_ = event.value;
            } else if (event.code == ABS_PRESSURE || event.code == ABS_MT_PRESSURE) {
                // Pressure information (if available)
            }
            break;
            
        case EV_KEY:
            if (event.code == BTN_TOUCH || event.code == BTN_LEFT) {
                if (event.value == 1) {
                    // Touch down
                    touch_active_ = true;
                    last_x_ = current_x_;
                    last_y_ = current_y_;
                    last_touch_time_ = get_time_ms();
                    scroll_mode_ = false;
                    scroll_start_y_ = current_y_;
                    
                    int target_x, target_y;
                    map_coordinates(current_x_, current_y_, target_x, target_y);
                    
                    if (touch_callback_) {
                        touch_callback_(TouchEvent(TouchEvent::TOUCH_DOWN, target_x, target_y));
                    }
                } else if (event.value == 0) {
                    // Touch up
                    touch_active_ = false;
                    
                    int target_x, target_y;
                    map_coordinates(current_x_, current_y_, target_x, target_y);
                    
                    // Check if this was a scroll gesture
                    if (scroll_mode_) {
                        // Don't send touch up for scroll gestures
                        scroll_mode_ = false;
                    } else {
                        // Check if this was a simple tap (no significant movement)
                        int dx = abs(current_x_ - last_x_);
                        int dy = abs(current_y_ - last_y_);
                        
                        if (dx < 20 && dy < 20) {
                            // This was a tap - send click event
                            if (touch_callback_) {
                                touch_callback_(TouchEvent(TouchEvent::TOUCH_UP, target_x, target_y));
                            }
                        }
                    }
                }
            }
            break;
            
        case EV_SYN:
            if (event.code == SYN_REPORT) {
                syn_report = true;
                
                // Process movement if touch is active
                if (touch_active_) {
                    int dx = current_x_ - last_x_;
                    int dy = current_y_ - last_y_;
                    
                    // Check for scroll gesture
                    if (!scroll_mode_ && abs(dy) > SCROLL_THRESHOLD && abs(dx) < SCROLL_THRESHOLD / 2) {
                        scroll_mode_ = true;
                        std::cout << "Scroll mode activated" << std::endl;
                    }
                    
                    if (scroll_mode_) {
                        // Handle scroll
                        int scroll_distance = current_y_ - scroll_start_y_;
                        
                        if (abs(scroll_distance) > SCROLL_THRESHOLD) {
                            int target_x, target_y;
                            map_coordinates(current_x_, current_y_, target_x, target_y);
                            
                            TouchEvent::Type scroll_type = (scroll_distance > 0) ? 
                                TouchEvent::SCROLL_DOWN : TouchEvent::SCROLL_UP;
                            
                            if (touch_callback_) {
                                touch_callback_(TouchEvent(scroll_type, target_x, target_y));
                            }
                            
                            // Reset scroll start position
                            scroll_start_y_ = current_y_;
                        }
                    } else if (abs(dx) > 5 || abs(dy) > 5) {
                        // Regular movement
                        int target_x, target_y;
                        map_coordinates(current_x_, current_y_, target_x, target_y);
                        
                        if (touch_callback_) {
                            touch_callback_(TouchEvent(TouchEvent::TOUCH_MOVE, target_x, target_y));
                        }
                        
                        last_x_ = current_x_;
                        last_y_ = current_y_;
                    }
                }
            }
            break;
    }
}

void TouchHandler::map_coordinates(int rpi_x, int rpi_y, int& target_x, int& target_y) {
    // Map from RPi screen coordinates to iPhone screen coordinates
    target_x = (rpi_x * target_width_) / screen_width_;
    target_y = (rpi_y * target_height_) / screen_height_;
    
    // Ensure coordinates are within bounds
    target_x = std::max(0, std::min(target_x, target_width_ - 1));
    target_y = std::max(0, std::min(target_y, target_height_ - 1));
}

unsigned long TouchHandler::get_time_ms() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000 + tv.tv_usec / 1000;
} 