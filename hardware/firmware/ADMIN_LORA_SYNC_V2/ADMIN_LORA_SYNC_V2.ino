// Heltec WiFi LoRa 32 V2. Flash together with VEHICLE_TRACKER_SYNC_V2.
// USB Serial -> Raspberry Pi gateway.py. Serial Monitor must be closed on Pi.
#include <Arduino.h>
#include <SPI.h>
#include <Wire.h>
#include <LoRa.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

Adafruit_SSD1306 oled(128, 64, &Wire, -1);
bool screen = false;
String serialLine;
bool overflowed = false;
String lastDevice = "Waiting for vehicle";
String statusText = "No packets yet";
uint32_t receivedAt = 0, screenAt = 0, packetCount = 0;

void setup() {
  Serial.begin(115200);
  pinMode(21, OUTPUT); digitalWrite(21, LOW);
  pinMode(16, OUTPUT); digitalWrite(16, LOW); delay(20); digitalWrite(16, HIGH);
  Wire.begin(4, 15);
  screen = oled.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  SPI.begin(5, 19, 27, 18);
  LoRa.setPins(18, 14, 26);
  if (!LoRa.begin(915E6)) {
    Serial.println("ERROR: LoRa init failed");
    while (true) delay(1000);
  }
  LoRa.setSyncWord(0x12);
  LoRa.setSpreadingFactor(7);
  LoRa.setSignalBandwidth(125E3);
  LoRa.setCodingRate4(5);
  LoRa.enableCrc();
  LoRa.receive();
}

void relayAck(const String &line) {
  // Only Pi can confirm persistence. Receipt by radio alone is never an ACK.
  if (!line.startsWith("ACK2|") || line.length() > 220) return;
  int a = line.indexOf('|', 5), b = line.indexOf('|', a + 1);
  if (a <= 5 || b <= a + 1 || line.indexOf('|', b + 1) >= 0) return;
  String phase = line.substring(b + 1);
  if (phase != "PI" && phase != "CLOUD") return;
  LoRa.idle();
  if (LoRa.beginPacket()) { LoRa.print(line); LoRa.endPacket(); }
  LoRa.receive();
  statusText = phase == "CLOUD" ? "Cloud confirmed" : "Saved on Pi";
}

void loop() {
  int size = LoRa.parsePacket();
  if (size) {
    String packet;
    while (LoRa.available()) packet += char(LoRa.read());
    if (packet.startsWith("GPS2|") && packet.length() <= 220) {
      // Pi validates all fields and commits before replying.
      Serial.println(packet);
      int end = packet.indexOf('|', 5);
      lastDevice = end > 5 ? packet.substring(5, end) : "Invalid packet";
      receivedAt = millis(); packetCount++;
      statusText = "Receiving -> Pi";
    }
    LoRa.receive();
  }
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n') {
      if (!overflowed) { serialLine.trim(); relayAck(serialLine); }
      serialLine = ""; overflowed = false;
    } else if (serialLine.length() < 220 && !overflowed) serialLine += c;
    else overflowed = true;
  }
  if (screen && millis() - screenAt >= 500) {
    screenAt = millis();
    oled.clearDisplay(); oled.setTextSize(1); oled.setTextColor(SSD1306_WHITE); oled.setCursor(0, 0);
    oled.println("CPSU ADMIN GATEWAY");
    oled.println(lastDevice);
    oled.println(statusText);
    oled.print("Packets: "); oled.println(packetCount);
    if (packetCount && millis() - receivedAt > 30000) oled.println("No recent radio RX");
    oled.println("Not full-trip status");
    oled.display();
  }
}
