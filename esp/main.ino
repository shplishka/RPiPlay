#include "BleMouse.h"

BleMouse bleMouse("iPhone Remote", "SparkFun", 100);

// MouseTo-style absolute positioning for BLE
class BLEMouseTo {
private:
  int currentX = 0;
  int currentY = 0;
  int targetX = 0;
  int targetY = 0;
  int screenWidth = 390;   // iPhone 14 width
  int screenHeight = 844;  // iPhone 14 height
  bool isHomed = false;
  int maxJumpDistance = 50; // Max pixels per move
  float correctionFactor = 1.0;
  
public:
  // Set screen resolution for your iPhone model
  void setScreenResolution(int width, int height) {
    screenWidth = width;
    screenHeight = height;
  }
  
  // Set target coordinates for next move
  void setTarget(int x, int y) {
    targetX = constrain(x, 0, screenWidth);
    targetY = constrain(y, 0, screenHeight);
  }
  
  // Get current position
  int getCurrentX() { return currentX; }
  int getCurrentY() { return currentY; }
  int getTargetX() { return targetX; }
  int getTargetY() { return targetY; }
  
  // Home cursor to known position (top-left corner)
  void home() {
    if (!bleMouse.isConnected()) return;
    
    Serial.println("🏠 Homing cursor to (0,0)...");
    
    // Move to top-left corner with large movements
    // Move far left and up to ensure we reach (0,0)
    for(int i = 0; i < 20; i++) {
      bleMouse.move(-127, -127); // Max negative movement
      delay(50);
    }
    
    currentX = 0;
    currentY = 0;
    isHomed = true;
    
    Serial.println("✅ Cursor homed to (0,0)");
  }
  
  // Move toward target coordinates (call repeatedly until target reached)
  bool move() {
    if (!bleMouse.isConnected()) {
      Serial.println("❌ iPhone not connected");
      return false;
    }
    
    if (!isHomed) {
      home();
      return false; // Will reach target on next call
    }
    
    // Calculate distance to target
    int deltaX = targetX - currentX;
    int deltaY = targetY - currentY;
    
    // Check if we're already at target
    if (abs(deltaX) <= 2 && abs(deltaY) <= 2) {
      Serial.println("🎯 Target reached: (" + String(currentX) + "," + String(currentY) + ")");
      return true;
    }
    
    // Calculate this move step
    int moveX = 0;
    int moveY = 0;
    
    if (abs(deltaX) > maxJumpDistance) {
      moveX = (deltaX > 0) ? maxJumpDistance : -maxJumpDistance;
    } else {
      moveX = deltaX;
    }
    
    if (abs(deltaY) > maxJumpDistance) {
      moveY = (deltaY > 0) ? maxJumpDistance : -maxJumpDistance;
    } else {
      moveY = deltaY;
    }
    
    // Apply correction factor
    moveX = (int)(moveX * correctionFactor);
    moveY = (int)(moveY * correctionFactor);
    
    // Constrain to BLE HID limits
    moveX = constrain(moveX, -127, 127);
    moveY = constrain(moveY, -127, 127);
    
    // Send movement
    if (moveX != 0 || moveY != 0) {
      bleMouse.move(moveX, moveY);
      currentX += moveX;
      currentY += moveY;
      
      Serial.println("📍 Move: (" + String(moveX) + "," + String(moveY) + 
                    ") → Current: (" + String(currentX) + "," + String(currentY) + 
                    ") Target: (" + String(targetX) + "," + String(targetY) + ")");
      
      delay(20); // Small delay for smooth movement
    }
    
    return false; // Not at target yet
  }
  
  // Move to absolute coordinates (blocking - waits until target reached)
  void moveTo(int x, int y) {
    setTarget(x, y);
    
    Serial.println("🎯 Moving to absolute coordinates: (" + String(x) + "," + String(y) + ")");
    
    unsigned long startTime = millis();
    const unsigned long timeout = 10000; // 10 second timeout
    
    while (!move()) {
      if (millis() - startTime > timeout) {
        Serial.println("⏰ Movement timeout - target may not be reachable");
        break;
      }
      delay(50);
    }
  }
  
  // Quick move to coordinates with automatic retry
  void quickMoveTo(int x, int y) {
    setTarget(x, y);
    
    // Try up to 100 move steps
    for(int i = 0; i < 100; i++) {
      if (move()) {
        break; // Target reached
      }
      delay(30);
    }
  }
  
  // Click at current position
  void click() {
    if (bleMouse.isConnected()) {
      Serial.println("👆 Click at (" + String(currentX) + "," + String(currentY) + ")");
      bleMouse.click(MOUSE_LEFT);
    }
  }
  
  // Click at specific coordinates
  void clickAt(int x, int y) {
    moveTo(x, y);
    delay(100);
    click();
  }
  
  // Scroll at current position
  void scroll(int direction, int amount = 1) {
    if (bleMouse.isConnected()) {
      String dirStr = (direction > 0) ? "UP" : "DOWN";
      Serial.println("🔄 Scroll " + dirStr + " (" + String(abs(direction * amount)) + ") at (" + String(currentX) + "," + String(currentY) + ")");
      
      for (int i = 0; i < amount; i++) {
        bleMouse.move(0, 0, direction);
        delay(50); // Small delay between scroll steps
      }
    }
  }
  
  // Scroll at specific coordinates
  void scrollAt(int x, int y, int direction, int amount = 1) {
    moveTo(x, y);
    delay(100);
    scroll(direction, amount);
  }
  
  // Horizontal scroll (for newer iOS versions)
  void scrollHorizontal(int direction, int amount = 1) {
    if (bleMouse.isConnected()) {
      String dirStr = (direction > 0) ? "RIGHT" : "LEFT";
      Serial.println("↔️ Scroll " + dirStr + " (" + String(abs(direction * amount)) + ") at (" + String(currentX) + "," + String(currentY) + ")");
      
      for (int i = 0; i < amount; i++) {
        // Horizontal scroll using mouse wheel
        bleMouse.move(0, 0, 0, direction);
        delay(50);
      }
    }
  }
  
  // Set correction factor for calibration
  void setCorrectionFactor(float factor) {
    correctionFactor = factor;
    Serial.println("📐 Correction factor set to: " + String(factor));
  }
  
  // Set max jump distance
  void setMaxJumpDistance(int distance) {
    maxJumpDistance = constrain(distance, 1, 127);
    Serial.println("🦘 Max jump distance set to: " + String(maxJumpDistance));
  }
  
  // Force rehome (useful if cursor gets lost)
  void rehome() {
    isHomed = false;
    home();
  }
  
  // Reset position tracking (manual calibration)
  void setCurrentPosition(int x, int y) {
    currentX = x;
    currentY = y;
    isHomed = true;
    Serial.println("📍 Position manually set to: (" + String(x) + "," + String(y) + ")");
  }
};

// Global MouseTo instance
BLEMouseTo mouseTo;

void setup() {
  Serial.begin(115200);
  pinMode(13, OUTPUT);
  
  Serial.println("==========================================");
  Serial.println("ESP32 BLE MouseTo - Absolute Positioning");
  Serial.println("Based on per1234/MouseTo concept");
  Serial.println("==========================================");
  
  Serial.println("Initializing BLE Mouse...");
  bleMouse.begin();
  
  // Set iPhone screen resolution (adjust for your model)
  mouseTo.setScreenResolution(390, 844); // iPhone 14
  
  // Startup LED sequence
  for(int i=0; i<3; i++) {
    digitalWrite(13, HIGH);
    delay(200);
    digitalWrite(13, LOW);
    delay(200);
  }
  
  Serial.println("Ready! Commands:");
  Serial.println("  GOTO,x,y       - Move to absolute coordinates");
  Serial.println("  CLICK,x,y      - Click at coordinates");
  Serial.println("  SCROLL,x,y,dir,amt - Scroll at coordinates (dir: 1=up, -1=down, amt: steps)");
  Serial.println("  SCROLL_UP,x,y,amt  - Scroll up at coordinates");
  Serial.println("  SCROLL_DOWN,x,y,amt - Scroll down at coordinates");
  Serial.println("  HSCROLL,x,y,dir,amt - Horizontal scroll (dir: 1=right, -1=left)");
  Serial.println("  HOME           - Home cursor to (0,0)");
  Serial.println("  CALIBRATE,x,y  - Set current position");
  Serial.println("  SCREEN,w,h     - Set screen resolution");
  Serial.println("  FACTOR,f       - Set correction factor");
  Serial.println("  STATUS         - Show current position");
  Serial.println("==========================================");
}

void loop() {
  // Update LED status
  digitalWrite(13, bleMouse.isConnected() ? HIGH : LOW);
  
  // Handle serial commands
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    handleCommand(command);
  }
  
  delay(10);
}

void handleCommand(String command) {
  Serial.println("📥 Command: " + command);
  
  if (!bleMouse.isConnected() && !command.startsWith("STATUS")) {
    Serial.println("❌ iPhone not connected - pair via Bluetooth first");
    return;
  }
  
  if (command.startsWith("GOTO,")) {
    // Parse GOTO,x,y
    int comma = command.indexOf(',');
    int secondComma = command.indexOf(',', comma + 1);
    
    if (comma > 0 && secondComma > 0) {
      int x = command.substring(comma + 1, secondComma).toInt();
      int y = command.substring(secondComma + 1).toInt();
      
      mouseTo.moveTo(x, y);
      Serial.println("✅ GOTO completed");
    } else {
      Serial.println("❌ Invalid format. Use: GOTO,x,y");
    }
  }
  else if (command.startsWith("CLICK,")) {
    // Parse CLICK,x,y
    int comma = command.indexOf(',');
    int secondComma = command.indexOf(',', comma + 1);
    
    if (comma > 0 && secondComma > 0) {
      int x = command.substring(comma + 1, secondComma).toInt();
      int y = command.substring(secondComma + 1).toInt();
      
      mouseTo.clickAt(x, y);
      Serial.println("✅ CLICK completed");
    } else {
      Serial.println("❌ Invalid format. Use: CLICK,x,y");
    }
  }
  else if (command.startsWith("SCROLL,")) {
    // Parse SCROLL,x,y,direction,amount
    int comma1 = command.indexOf(',');
    int comma2 = command.indexOf(',', comma1 + 1);
    int comma3 = command.indexOf(',', comma2 + 1);
    int comma4 = command.indexOf(',', comma3 + 1);
    
    if (comma1 > 0 && comma2 > 0 && comma3 > 0) {
      int x = command.substring(comma1 + 1, comma2).toInt();
      int y = command.substring(comma2 + 1, comma3).toInt();
      int direction = command.substring(comma3 + 1, comma4 > 0 ? comma4 : command.length()).toInt();
      int amount = (comma4 > 0) ? command.substring(comma4 + 1).toInt() : 1;
      
      mouseTo.scrollAt(x, y, direction, amount);
      Serial.println("✅ SCROLL completed");
    } else {
      Serial.println("❌ Invalid format. Use: SCROLL,x,y,direction,amount");
    }
  }
  else if (command.startsWith("SCROLL_UP,")) {
    // Parse SCROLL_UP,x,y,amount
    int comma1 = command.indexOf(',');
    int comma2 = command.indexOf(',', comma1 + 1);
    int comma3 = command.indexOf(',', comma2 + 1);
    
    if (comma1 > 0 && comma2 > 0) {
      int x = command.substring(comma1 + 1, comma2).toInt();
      int y = command.substring(comma2 + 1, comma3 > 0 ? comma3 : command.length()).toInt();
      int amount = (comma3 > 0) ? command.substring(comma3 + 1).toInt() : 3;
      
      mouseTo.scrollAt(x, y, 1, amount); // 1 = scroll up
      Serial.println("✅ SCROLL_UP completed");
    } else {
      Serial.println("❌ Invalid format. Use: SCROLL_UP,x,y,amount");
    }
  }
  else if (command.startsWith("SCROLL_DOWN,")) {
    // Parse SCROLL_DOWN,x,y,amount  
    int comma1 = command.indexOf(',');
    int comma2 = command.indexOf(',', comma1 + 1);
    int comma3 = command.indexOf(',', comma2 + 1);
    
    if (comma1 > 0 && comma2 > 0) {
      int x = command.substring(comma1 + 1, comma2).toInt();
      int y = command.substring(comma2 + 1, comma3 > 0 ? comma3 : command.length()).toInt();
      int amount = (comma3 > 0) ? command.substring(comma3 + 1).toInt() : 3;
      
      mouseTo.scrollAt(x, y, -1, amount); // -1 = scroll down
      Serial.println("✅ SCROLL_DOWN completed");
    } else {
      Serial.println("❌ Invalid format. Use: SCROLL_DOWN,x,y,amount");
    }
  }
  else if (command.startsWith("HSCROLL,")) {
    // Parse HSCROLL,x,y,direction,amount
    int comma1 = command.indexOf(',');
    int comma2 = command.indexOf(',', comma1 + 1);
    int comma3 = command.indexOf(',', comma2 + 1);
    int comma4 = command.indexOf(',', comma3 + 1);
    
    if (comma1 > 0 && comma2 > 0 && comma3 > 0) {
      int x = command.substring(comma1 + 1, comma2).toInt();
      int y = command.substring(comma2 + 1, comma3).toInt();
      int direction = command.substring(comma3 + 1, comma4 > 0 ? comma4 : command.length()).toInt();
      int amount = (comma4 > 0) ? command.substring(comma4 + 1).toInt() : 1;
      
      mouseTo.moveTo(x, y);
      delay(100);
      mouseTo.scrollHorizontal(direction, amount);
      Serial.println("✅ HSCROLL completed");
    } else {
      Serial.println("❌ Invalid format. Use: HSCROLL,x,y,direction,amount");
    }
  }
  else if (command == "HOME") {
    mouseTo.home();
    Serial.println("✅ HOME completed");
  }
  else if (command.startsWith("CALIBRATE,")) {
    // Parse CALIBRATE,x,y
    int comma = command.indexOf(',');
    int secondComma = command.indexOf(',', comma + 1);
    
    if (comma > 0 && secondComma > 0) {
      int x = command.substring(comma + 1, secondComma).toInt();
      int y = command.substring(secondComma + 1).toInt();
      
      mouseTo.setCurrentPosition(x, y);
      Serial.println("✅ CALIBRATE completed");
    }
  }
  else if (command.startsWith("SCREEN,")) {
    // Parse SCREEN,width,height
    int comma = command.indexOf(',');
    int secondComma = command.indexOf(',', comma + 1);
    
    if (comma > 0 && secondComma > 0) {
      int w = command.substring(comma + 1, secondComma).toInt();
      int h = command.substring(secondComma + 1).toInt();
      
      mouseTo.setScreenResolution(w, h);
      Serial.println("✅ Screen resolution set to " + String(w) + "x" + String(h));
    }
  }
  else if (command.startsWith("FACTOR,")) {
    // Parse FACTOR,value
    int comma = command.indexOf(',');
    if (comma > 0) {
      float factor = command.substring(comma + 1).toFloat();
      mouseTo.setCorrectionFactor(factor);
      Serial.println("✅ Correction factor set");
    }
  }
  else if (command == "STATUS") {
    Serial.println("📊 === STATUS ===");
    Serial.println("Connection: " + String(bleMouse.isConnected() ? "✅ Connected" : "❌ Disconnected"));
    Serial.println("Current Position: (" + String(mouseTo.getCurrentX()) + "," + String(mouseTo.getCurrentY()) + ")");
    Serial.println("Target Position: (" + String(mouseTo.getTargetX()) + "," + String(mouseTo.getTargetY()) + ")");
    Serial.println("=================");
  }
  else {
    Serial.println("❌ Unknown command. Available commands:");
    Serial.println("  GOTO,x,y | CLICK,x,y | HOME | STATUS | CALIBRATE,x,y");
    Serial.println("  SCROLL,x,y,dir,amt | SCROLL_UP,x,y,amt | SCROLL_DOWN,x,y,amt");
    Serial.println("  HSCROLL,x,y,dir,amt | SCREEN,w,h | FACTOR,f");
  }
}