#include "BleMouse.h"

BleMouse bleMouse("ESP32 Mouse", "ESP32", 100);

// No scaling in ESP32 - Python handles all scaling
float X_SCALE = 1.0;  // No scaling - coordinates come pre-scaled from Python
float Y_SCALE = 1.0;  // No scaling - coordinates come pre-scaled from Python

// Base screen dimensions (physical iPhone screen size)
int BASE_SCREEN_WIDTH = 1170;   // iPhone 14 physical width (pixels)
int BASE_SCREEN_HEIGHT = 2532;  // iPhone 14 physical height (pixels)

// Actual screen dimensions (coordinates come pre-scaled from Python)
int ACTUAL_SCREEN_WIDTH = BASE_SCREEN_WIDTH * X_SCALE;   // Calculated: 1170 * 1.0 = 1170
int ACTUAL_SCREEN_HEIGHT = BASE_SCREEN_HEIGHT * Y_SCALE; // Calculated: 2532 * 1.0 = 2532

// Simple absolute mouse positioning for iPhone control
class SimpleBLEMouse {
private:
  // Use global actual screen dimensions
  // No position tracking - use home-based absolute positioning
  
public:
  // Set screen resolution (applies different scaling for X and Y axes)
  void setScreenResolution(int width, int height) {
    // Update base screen dimensions
    BASE_SCREEN_WIDTH = width;
    BASE_SCREEN_HEIGHT = height;
    
    // No scaling in ESP32 - coordinates come pre-scaled from Python
    ACTUAL_SCREEN_WIDTH = int(width * X_SCALE);   // X_SCALE = 1.0 (no scaling)
    ACTUAL_SCREEN_HEIGHT = int(height * Y_SCALE);  // Y_SCALE = 1.0 (no scaling)
    
    Serial.println("📱 Base screen set to: " + String(BASE_SCREEN_WIDTH) + "x" + String(BASE_SCREEN_HEIGHT));
    Serial.println("📱 ESP32 receives pre-scaled coordinates from Python");
  }
  
  // No position tracking in this version - always homes before each move
  
  // Get base screen resolution (logical dimensions)
  int getBaseScreenWidth() { return BASE_SCREEN_WIDTH; }
  int getBaseScreenHeight() { return BASE_SCREEN_HEIGHT; }
  
  // Get actual screen resolution (BLE coordinate dimensions)
  int getActualScreenWidth() { return ACTUAL_SCREEN_WIDTH; }
  int getActualScreenHeight() { return ACTUAL_SCREEN_HEIGHT; }
  
  // Move to absolute position using proper home-then-move strategy
  void moveToAbsolute(int targetX, int targetY) {
    
    // TEMPORARY: Disable coordinate constraints for testing
    // targetX = constrain(targetX, -200, screenWidth + 200);
    // targetY = constrain(targetY, -200, screenHeight + 200);
    
    Serial.println("🔓 FREE MODE: No coordinate constraints");
    
    Serial.println("🎯 Moving to absolute position: (" + String(targetX) + "," + String(targetY) + ")");
    
    // PROPER ABSOLUTE POSITIONING STRATEGY:
    // 1. Home to (0,0) with conservative movements
    // 2. Move from (0,0) to target
    
    // Step 1: Home to top-left corner (0,0)
    Serial.println("🏠 Homing to (0,0)...");
    // Move far enough to guarantee we reach (0,0) but not so far we go off-screen
    int homeSteps = max(ACTUAL_SCREEN_WIDTH, ACTUAL_SCREEN_HEIGHT) / 50 + 5;  // Conservative homing
    for(int i = 0; i < homeSteps; i++) {
      bleMouse.move(-50, -50);  // Small, safe movements
      delay(35);
    }
    
    // Step 2: Move from (0,0) to target position
    Serial.println("📍 Moving from (0,0) to target (" + String(targetX) + "," + String(targetY) + ")...");
    
    int remainingX = targetX;
    int remainingY = targetY;
    
    while (remainingX != 0 || remainingY != 0) {
      // Calculate next movement step (smaller steps for accuracy)
      int moveX = 0;
      int moveY = 0;
      
      if (remainingX > 0) {
        moveX = min(remainingX, 50);  // Smaller steps for accuracy
        remainingX -= moveX;
      } else if (remainingX < 0) {
        moveX = max(remainingX, -50);
        remainingX -= moveX;
      }
      
      if (remainingY > 0) {
        moveY = min(remainingY, 50);
        remainingY -= moveY;
      } else if (remainingY < 0) {
        moveY = max(remainingY, -50);
        remainingY -= moveY;
      }
      
      if (moveX != 0 || moveY != 0) {
        bleMouse.move(moveX, moveY);
        delay(35);
      } else {
        break;
      }
    }
    
    Serial.println("✅ Movement to (" + String(targetX) + "," + String(targetY) + ") completed");
  }
  
  // Click at current position
  void click() {
    Serial.println("👆 Click executed");
    bleMouse.click(MOUSE_LEFT);
  }
  
  // Click at specific coordinates
  void clickAt(int x, int y) {
    moveToAbsolute(x, y);
    delay(50);
    click();
  }
  
  // Reset - no position tracking needed in this version
  void resetPosition(int x = 0, int y = 0) {
    Serial.println("🔄 Reset command received (no position tracking in this version)");
  }
  
  // Scroll at current position
  void scroll(int direction, int amount = 1) {
    String dirStr = (direction > 0) ? "UP" : "DOWN";
    Serial.println("🔄 Scroll " + dirStr + " (" + String(abs(direction * amount)) + ")");
    
    for (int i = 0; i < amount; i++) {
      bleMouse.move(0, 0, direction);
      delay(50);
    }
  }
};

// Global mouse instance
SimpleBLEMouse mouse;

void setup() {
  Serial.begin(115200);
  pinMode(2, OUTPUT); // Use pin 2 for LED (common on ESP32)
  
  Serial.println("==========================================");
  Serial.println("ESP32 BLE Mouse - Absolute Position Control");
  Serial.println("==========================================");
  
  Serial.println("🔄 Initializing BLE Mouse...");
  bleMouse.begin();
  
  // Set default iPhone screen resolution using global base dimensions
  mouse.setScreenResolution(BASE_SCREEN_WIDTH, BASE_SCREEN_HEIGHT); // iPhone 14 physical resolution
  
  // Startup LED sequence
  for(int i = 0; i < 3; i++) {
    digitalWrite(2, HIGH);
    delay(200);
    digitalWrite(2, LOW);
    delay(200);
  }
  
  Serial.println("✅ Ready! Available commands:");
  Serial.println("  MOVE,x,y       - Move to absolute coordinates");
  Serial.println("  CLICK,x,y      - Click at coordinates");
  Serial.println("  CLICK          - Click at current position");
  Serial.println("  SCROLL,dir,amt - Scroll at current position (dir: 1=up, -1=down)");
  Serial.println("  RESET,x,y      - Reset position tracking");
  Serial.println("  RESET          - Reset to (0,0)");
  Serial.println("  SCREEN,w,h     - Set screen resolution");
  Serial.println("  STATUS         - Show current status");
  Serial.println("==========================================");
}

void loop() {
  // Update LED status - throttle check to once per second
  static unsigned long lastLedUpdateMs = 0;
  unsigned long nowMs = millis();
  if (nowMs - lastLedUpdateMs >= 1000) {
    digitalWrite(2, bleMouse.isConnected() ? HIGH : LOW);
    lastLedUpdateMs = nowMs;
  }
  
  // Handle serial commands
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    command.toUpperCase(); // Make commands case-insensitive
    handleCommand(command);
  }
  
  delay(10);
}

void handleCommand(String command) {
  Serial.println("📥 Command: " + command);
  
  // STATUS command works even when disconnected
  if (command == "STATUS") {
    showStatus();
    return;
  }
  
  // Parse and execute commands
  if (command.startsWith("MOVE,")) {
    // MOVE,x,y
    int comma = command.indexOf(',');
    int secondComma = command.indexOf(',', comma + 1);
    
    if (comma > 0 && secondComma > 0) {
      int x = command.substring(comma + 1, secondComma).toInt(); // No scaling - coordinates pre-scaled by Python
      int y = command.substring(secondComma + 1).toInt();        // No scaling - coordinates pre-scaled by Python
      mouse.moveToAbsolute(x, y);
    } else {
      Serial.println("❌ Invalid format. Use: MOVE,x,y");
    }
  }
  else if (command.startsWith("CLICK,")) {
    // CLICK,x,y
    int comma = command.indexOf(',');
    int secondComma = command.indexOf(',', comma + 1);
    
    if (comma > 0 && secondComma > 0) {
      int x = command.substring(comma + 1, secondComma).toInt(); // No scaling - coordinates pre-scaled by Python
      int y = command.substring(secondComma + 1).toInt();        // No scaling - coordinates pre-scaled by Python
      mouse.clickAt(x, y);
    } else {
      Serial.println("❌ Invalid format. Use: CLICK,x,y");
    }
  }
  else if (command == "CLICK") {
    // Click at current position
    mouse.click();
  }
  else if (command.startsWith("SCROLL,")) {
    // SCROLL,direction,amount
    int comma = command.indexOf(',');
    int secondComma = command.indexOf(',', comma + 1);
    
    if (comma > 0) {
      int direction = command.substring(comma + 1, secondComma > 0 ? secondComma : command.length()).toInt();
      int amount = (secondComma > 0) ? command.substring(secondComma + 1).toInt() : 1;
      mouse.scroll(direction, amount);
    } else {
      Serial.println("❌ Invalid format. Use: SCROLL,direction,amount");
    }
  }
  else if (command.startsWith("RESET,")) {
    // RESET,x,y
    int comma = command.indexOf(',');
    int secondComma = command.indexOf(',', comma + 1);
    
    if (comma > 0 && secondComma > 0) {
      int x = command.substring(comma + 1, secondComma).toInt();
      int y = command.substring(secondComma + 1).toInt();
      mouse.resetPosition(x, y);
    } else {
      Serial.println("❌ Invalid format. Use: RESET,x,y");
    }
  }
  else if (command == "RESET") {
    // Reset to (0,0)
    mouse.resetPosition(0, 0);
  }
  else if (command.startsWith("SCREEN,")) {
    // SCREEN,width,height
    int comma = command.indexOf(',');
    int secondComma = command.indexOf(',', comma + 1);
    
    if (comma > 0 && secondComma > 0) {
      int w = command.substring(comma + 1, secondComma).toInt();
      int h = command.substring(secondComma + 1).toInt();
      mouse.setScreenResolution(w, h);
    } else {
      Serial.println("❌ Invalid format. Use: SCREEN,width,height");
    }
  }
  else {
    Serial.println("❌ Unknown command. Available commands:");
    Serial.println("  MOVE,x,y | CLICK,x,y | CLICK | SCROLL,dir,amt");
    Serial.println("  RESET,x,y | RESET | SCREEN,w,h | STATUS");
  }
}

void showStatus() {
  Serial.println("📊 === STATUS ===");
  Serial.println("🔗 Connection: " + String(bleMouse.isConnected() ? "✅ Connected" : "❌ Disconnected"));
  Serial.println("📱 Base Screen: " + String(mouse.getBaseScreenWidth()) + "x" + String(mouse.getBaseScreenHeight()));
  Serial.println("📱 Actual BLE: " + String(mouse.getActualScreenWidth()) + "x" + String(mouse.getActualScreenHeight()));
  Serial.println("📏 ESP32 Scale: " + String(X_SCALE) + " (coordinates pre-scaled by Python)");
  Serial.println("🔋 Free Heap: " + String(ESP.getFreeHeap()) + " bytes");
  Serial.println("💡 Note: This version uses home-based absolute positioning");
  Serial.println("💡 No position tracking - each move starts from (0,0)");
  Serial.println("=================");
}