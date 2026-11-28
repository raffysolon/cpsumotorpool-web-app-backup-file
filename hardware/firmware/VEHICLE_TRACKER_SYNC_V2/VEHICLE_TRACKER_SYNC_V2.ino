// Bench-test firmware for Heltec WiFi LoRa 32 V2 / ESP32 core 3.3.7.
// Dependencies: LoRa (Sandeep Mistry), TinyGPSPlus, Adafruit SSD1306/GFX,
// ArduinoJson 7. Copy device_secrets.example.h to device_secrets.h.
// Keep your verified root_ca.h defining ROOT_CA. No insecure TLS fallback.
#include <Arduino.h>
#include <SPI.h>
#include <SD.h>
#include <Wire.h>
#include <LoRa.h>
#include <TinyGPSPlus.h>
#include <Preferences.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoJson.h>
#include <PPP.h>
#include <NetworkClientSecure.h>
#include <HTTPClient.h>
#include <sys/time.h>
#include "device_secrets.h"
#include "root_ca.h"

const char* DEVICE_ID = "VEHICLE-01";
const bool ENABLE_LTE = true; // Set false for LoRa-only bench tests.
const char* APN = "talkntext.MNC003.MCC515.GPRS";
const char* BASE_URL = "https://cpsu-motorpool-backend.onrender.com/api";
const char* OUTBOX = "/gps_v2.log"; // Original gps_log.csv is never modified.
const uint32_t REPORT_MS = 15000, RETRY_MS = 10000;
const int SD_CS = 23, RADIO_CS = 18;
HardwareSerial gpsSerial(1);
TinyGPSPlus gps;
Preferences prefs;
Adafruit_SSD1306 oled(128, 64, &Wire, -1);
bool sdOK = false, radioOK = false, oledOK = false, storageFault = false;
bool pppStarted = false;
uint64_t nextSeq = 1;
uint32_t cloudOffset = 0, candidateEnd = 0;
uint32_t captureAt = 0, sendAt = 0, displayAt = 0, modemAt = 0, heartbeatAt = 0;
String candidate, candidateId, statusText = "Starting";

void readGPS() { while (gpsSerial.available()) gps.encode(char(gpsSerial.read())); }
void waitGPS(uint32_t ms) {
  uint32_t start = millis();
  while (millis() - start < ms) { readGPS(); delay(2); }
}
void fault(const char* why) {
  storageFault = true; statusText = why; Serial.println(why);
}
bool utc(char* out, size_t size) {
  if (gps.date.isValid() && gps.time.isValid() && gps.date.age() < 5000 &&
      gps.time.age() < 5000 && gps.date.year() >= 2024) {
    tm value = {};
    value.tm_year = gps.date.year() - 1900; value.tm_mon = gps.date.month() - 1;
    value.tm_mday = gps.date.day(); value.tm_hour = gps.time.hour();
    value.tm_min = gps.time.minute(); value.tm_sec = gps.time.second();
    time_t epoch = mktime(&value); // setup sets TZ=UTC0
    timeval tv = {epoch, 0}; settimeofday(&tv, nullptr);
  }
  time_t now = time(nullptr);
  if (now < 1700000000) return false;
  tm value; gmtime_r(&now, &value);
  return strftime(out, size, "%Y-%m-%dT%H:%M:%SZ", &value) > 0;
}
String field(const String &line, int index) {
  int start = 0;
  for (int i = 0; i < index; i++) {
    start = line.indexOf('|', start);
    if (start < 0) return "";
    start++;
  }
  int end = line.indexOf('|', start);
  return end < 0 ? line.substring(start) : line.substring(start, end);
}
void capture() {
  if (storageFault || !sdOK || !gps.location.isValid() || gps.location.age() > 5000) return;
  char stamp[26];
  if (!utc(stamp, sizeof(stamp))) { statusText = "Waiting GPS UTC"; return; }
  if (nextSeq == UINT64_MAX || prefs.putULong64("nextSeq", nextSeq + 1) != 8) {
    fault("NVS sequence failure"); return;
  }
  uint64_t seq = nextSeq++;
  char line[221];
  int length = snprintf(line, sizeof(line), "GPS2|%s|%s-%llu|%llu|%s|%.6f|%.6f|%u",
      DEVICE_ID, DEVICE_ID, (unsigned long long)seq, (unsigned long long)seq,
      stamp, gps.location.lat(), gps.location.lng(),
      gps.satellites.isValid() ? unsigned(gps.satellites.value()) : 0);
  if (length <= 0 || length >= int(sizeof(line))) { fault("Packet too long"); return; }
  digitalWrite(RADIO_CS, HIGH);
  File file = SD.open(OUTBOX, FILE_APPEND);
  if (!file) { fault("SD open failed"); return; }
  size_t n = file.print(line); size_t ending = file.print('\n');
  file.flush(); file.close();
  if (n != size_t(length) || ending != 1) { fault("SD partial write"); return; }
  Serial.println(line);
}
bool loadCandidate() {
  if (candidate.length()) return true;
  if (!sdOK || storageFault) return false;
  digitalWrite(RADIO_CS, HIGH);
  File file = SD.open(OUTBOX, FILE_READ);
  if (!file) return false;
  if (cloudOffset > file.size()) { file.close(); fault("Outbox replaced"); return false; }
  if (cloudOffset == file.size()) { file.close(); return false; }
  file.seek(cloudOffset);
  String line; bool complete = false;
  while (file.available() && line.length() <= 220) {
    char c = file.read();
    if (c == '\n') { complete = true; break; }
    line += c;
  }
  candidateEnd = file.position(); file.close();
  if (!complete || !line.startsWith(String("GPS2|") + DEVICE_ID + "|") || field(line, 7).isEmpty()) {
    fault("Review damaged SD row"); return false;
  }
  candidate = line; candidateId = field(line, 2);
  return true;
}
void confirmCloud() {
  if (!candidate.length()) return;
  if (prefs.putUInt("cloudPos", candidateEnd) != 4) { fault("NVS cursor failure"); return; }
  cloudOffset = candidateEnd;
  Serial.println("CLOUD_SAVED " + candidateId);
  candidate = ""; candidateId = ""; statusText = "Cloud confirmed";
}
void receiveAck() {
  if (!radioOK) return;
  digitalWrite(SD_CS, HIGH);
  if (LoRa.parsePacket()) {
    String packet;
    while (LoRa.available()) packet += char(LoRa.read());
    if (candidate.length() && field(packet, 0) == "ACK2" && field(packet, 1) == DEVICE_ID && field(packet, 2) == candidateId) {
      if (field(packet, 3) == "CLOUD") confirmCloud();
      else if (field(packet, 3) == "PI") statusText = "On Pi; cloud pending";
    }
    LoRa.receive();
  }
}
void transmitRadio() {
  if (!radioOK) return;
  digitalWrite(SD_CS, HIGH); LoRa.idle();
  if (LoRa.beginPacket()) { LoRa.print(candidate); LoRa.endPacket(); }
  LoRa.receive(); statusText = "Waiting Pi/cloud ACK";
}
void connectLTE() {
  if (!ENABLE_LTE || PPP.connected()) return;
  if (pppStarted) PPP.end();
  PPP.setApn(APN);
  PPP.setPins(22, 13, -1, -1, ESP_MODEM_FLOW_CONTROL_NONE);
  pppStarted = PPP.begin(PPP_MODEM_GENERIC, 2, 115200);
  if (!pppStarted) return;
  uint32_t start = millis();
  while (!PPP.attached() && millis() - start < 10000) waitGPS(100);
  if (!PPP.attached() || !PPP.mode(ESP_MODEM_MODE_DATA)) return;
  if (PPP.waitStatusBits(ESP_NETIF_CONNECTED_BIT, 10000)) {
    Network.setDefaultInterface(PPP);
    configTime(0, 0, "pool.ntp.org", "time.google.com");
  }
}
bool post(const char* route, JsonDocument &body, String &reply) {
  char stamp[26];
  if (!ENABLE_LTE || !PPP.connected() || !utc(stamp, sizeof(stamp)) || strlen(TRACKER_KEY) != 64) return false;
  NetworkClientSecure client; client.setCACert(ROOT_CA);
  HTTPClient http; http.setConnectTimeout(5000); http.setTimeout(10000);
  if (!http.begin(client, String(BASE_URL) + route)) return false;
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Accept", "application/json"); http.addHeader("X-Tracker-Key", TRACKER_KEY);
  String encoded; serializeJson(body, encoded);
  int code = http.POST(encoded); reply = http.getString(); http.end();
  Serial.printf("HTTP %d\n", code);
  return code == 200 || code == 201;
}
bool uploadLTE() {
  JsonDocument payload;
  payload["device_id"] = DEVICE_ID; payload["record_id"] = candidateId;
  payload["device_sequence"] = strtoull(field(candidate, 3).c_str(), nullptr, 10);
  payload["captured_at"] = field(candidate, 4);
  payload["latitude"] = field(candidate, 5).toDouble();
  payload["longitude"] = field(candidate, 6).toDouble();
  payload["satellites"] = field(candidate, 7).toInt();
  // Fresh captures can update the live map; backlog replay must not trigger movement alerts.
  tm captured = {};
  char* parsed = strptime(field(candidate, 4).c_str(), "%Y-%m-%dT%H:%M:%SZ", &captured);
  time_t captureTime = parsed ? mktime(&captured) : 0;
  time_t age = time(nullptr) - captureTime;
  payload["upload_source"] = captureTime > 0 && age >= 0 && age <= 30
      ? "live_lte" : "recovered_lte";
  String reply;
  if (!post("/gps/location", payload, reply)) return false;
  JsonDocument response;
  if (deserializeJson(response, reply)) return false;
  if (response["acknowledged_record_id"].as<String>() != candidateId) return false;
  confirmCloud(); return true;
}
void heartbeat() {
  char stamp[26]; if (!utc(stamp, sizeof(stamp))) return;
  JsonDocument payload; payload["device_id"] = DEVICE_ID; payload["sent_at"] = stamp;
  String reply; post("/devices/heartbeat", payload, reply);
}
void setup() {
  Serial.begin(115200); setenv("TZ", "UTC0", 1); tzset();
  pinMode(21, OUTPUT); digitalWrite(21, LOW);
  pinMode(16, OUTPUT); digitalWrite(16, LOW); delay(20); digitalWrite(16, HIGH);
  Wire.begin(4, 15); oledOK = oled.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  gpsSerial.setRxBufferSize(4096); gpsSerial.begin(9600, SERIAL_8N1, 36, 17);
  if (!prefs.begin("gps-records", false)) fault("NVS unavailable");
  // Migrate the previous uint32 nextSeq safely into a separate v2 counter key.
  uint32_t oldNext = prefs.getUInt("nextSeq", 1);
  prefs.end();
  if (!prefs.begin("gps-sync-v2", false)) fault("NVS unavailable");
  nextSeq = prefs.getULong64("nextSeq", oldNext);
  if (nextSeq == 0) fault("Invalid NVS sequence");
  cloudOffset = prefs.getUInt("cloudPos", 0);
  pinMode(SD_CS, OUTPUT); pinMode(RADIO_CS, OUTPUT);
  digitalWrite(SD_CS, HIGH); digitalWrite(RADIO_CS, HIGH);
  SPI.begin(5, 19, 27);
  sdOK = SD.begin(SD_CS, SPI, 1000000);
  if (!sdOK) fault("SD init failed");
  if (sdOK) {
    File previous = SD.open(OUTBOX, FILE_READ);
    if (previous) {
      if (previous.size()) {
        previous.seek(previous.size() - 1);
        if (previous.read() != '\n') fault("Review partial SD tail");
      }
      if (cloudOffset > previous.size()) fault("Outbox/cursor mismatch");
      previous.close();
    } else if (cloudOffset) fault("Outbox missing");
  }
  LoRa.setSPI(SPI); LoRa.setPins(18, 14, 26);
  radioOK = LoRa.begin(915E6);
  if (radioOK) {
    LoRa.setSyncWord(0x12); LoRa.setSpreadingFactor(7);
    LoRa.setSignalBandwidth(125E3); LoRa.setCodingRate4(5); LoRa.enableCrc(); LoRa.receive();
  }
  statusText = storageFault ? "Storage requires check" : "Waiting GPS fix";
}
void loop() {
  readGPS(); receiveAck();
  if (millis() - captureAt >= REPORT_MS) { captureAt = millis(); capture(); }
  if (ENABLE_LTE && millis() - modemAt >= 60000) { modemAt = millis(); connectLTE(); }
  if (ENABLE_LTE && millis() - heartbeatAt >= 60000) { heartbeatAt = millis(); heartbeat(); }
  if (millis() - sendAt >= RETRY_MS && loadCandidate()) {
    sendAt = millis();
    if (!uploadLTE()) transmitRadio();
  }
  if (oledOK && millis() - displayAt >= 1000) {
    displayAt = millis(); oled.clearDisplay(); oled.setCursor(0, 0);
    oled.setTextSize(1); oled.setTextColor(SSD1306_WHITE);
    oled.println(DEVICE_ID); oled.println(statusText);
    oled.print("SD: "); oled.println(storageFault ? "CHECK" : "OK");
    oled.print("LTE: "); oled.println(ENABLE_LTE && PPP.connected() ? "UP" : "DOWN");
    oled.println(candidateId); oled.println("SD archive retained"); oled.display();
  }
  delay(2);
}
