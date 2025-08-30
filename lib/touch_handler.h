#ifndef TOUCH_HANDLER_H
#define TOUCH_HANDLER_H

#include <string>
#include <thread>
#include <atomic>
#include <functional>
#include <linux/input.h>

struct TouchEvent {
    enum Type {
        TOUCH_DOWN,
        TOUCH_UP, 
        TOUCH_MOVE,
        SCROLL_UP,
        SCROLL_DOWN
    };
    
    Type type;
    int x;
    int y;
    int pressure;
    
    TouchEvent(Type t, int x_pos, int y_pos, int p = 0) 
        : type(t), x(x_pos), y(y_pos), pressure(p) {}
};

class TouchHandler {
public:
    typedef std::function<void(const TouchEvent&)> TouchCallback;
    
    TouchHandler();
    ~TouchHandler();
    
    // Initialize touch input handler
    bool init(const std::string& device_path = "/dev/input/event4");
    
    // Close handler
    void close();
    
    // Check if initialized
    bool is_initialized() const;
    
    // Set callback for touch events
    void set_touch_callback(TouchCallback callback);
    
    // Set screen resolution for coordinate mapping
    void set_screen_resolution(int width, int height);
    
    // Set coordinate mapping (RPi screen -> iPhone screen)
    void set_coordinate_mapping(int rpi_width, int rpi_height, int target_width, int target_height);
    
    // Start processing touch events (non-blocking)
    void start();
    
    // Stop processing touch events
    void stop();

private:
    int input_fd_;
    std::atomic<bool> initialized_;
    std::atomic<bool> running_;
    std::thread event_thread_;
    TouchCallback touch_callback_;
    
    // Screen dimensions
    int screen_width_;
    int screen_height_;
    
    // Target coordinate system (iPhone)
    int target_width_;
    int target_height_;
    
    // Touch state tracking
    bool touch_active_;
    int last_x_;
    int last_y_;
    int current_x_;
    int current_y_;
    
    // Scroll detection
    static const int SCROLL_THRESHOLD = 50;  // Minimum pixels for scroll
    unsigned long last_touch_time_;
    int scroll_start_y_;
    bool scroll_mode_;
    
    // Thread function for processing events
    void event_loop();
    
    // Process input event
    void process_event(const struct input_event& event);
    
    // Map coordinates from RPi screen to iPhone screen
    void map_coordinates(int rpi_x, int rpi_y, int& target_x, int& target_y);
    
    // Get current time in milliseconds
    unsigned long get_time_ms();
};

#endif // TOUCH_HANDLER_H 