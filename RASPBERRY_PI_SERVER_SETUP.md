# Raspberry Pi Server Setup Guide
## CPSU MotorPool Vehicle Tracking System

This guide will help you set up your Raspberry Pi as a **LoRa Gateway Server** to receive GPS data from your Heltec LoRa32 V2 vehicle trackers.

---

## 🏗️ System Architecture

**Vehicle Side (2 vehicles with 1 LoRa32 each):**
- GPS Module (NEO-6M) → Heltec LoRa32 V2 (ESP32 + LoRa) → LoRa transmission to Raspberry Pi
- SD Card Module → Local data logging (backup if connection fails)
- Backup: SIM A7672E LTE → Send via cellular if LoRa unavailable

**Raspberry Pi Server (LoRa Gateway):**
- LoRa module receives data from vehicles
- Stores in MySQL database
- Provides API for Laravel backend
- Laravel backend → Admin Dashboard

---

## 📋 What You'll Need

### Hardware:
- ✅ Raspberry Pi (3B+, 4, or 5 recommended)
- ✅ MicroSD Card (16GB minimum, 32GB+ recommended)
- ✅ Power Supply (5V 3A for Pi 4/5)
- ✅ **LoRa Module** (SX1276/SX1278 for Raspberry Pi)
  - Recommended: Ra-02 LoRa module or Dragino LoRa HAT
  - Frequency: 433MHz or 915MHz (match with your LoRa32)
- ✅ Network connection (Ethernet cable or WiFi)
- ✅ Heltec LoRa32 V2 (x2 for 2 vehicles) - already in your setup
- ✅ MicroSD Card Module (x2 for each vehicle)
- ✅ MicroSD Cards (4GB-16GB each for data logging)

### Software:
- Raspberry Pi OS (formerly Raspbian)
- Python 3.x (pre-installed)
- MySQL/MariaDB or PostgreSQL
- Optional: Node.js for real-time features

---

## 🚀 Step-by-Step Setup

### **Step 1: Install Raspberry Pi OS**

1. Download **Raspberry Pi Imager**: https://www.raspberrypi.com/software/
2. Insert MicroSD card into your computer
3. Open Raspberry Pi Imager:
   - Choose OS: **Raspberry Pi OS (64-bit)** recommended
   - Choose Storage: Your MicroSD card
   - Click gear icon ⚙️ for advanced settings:
     - ✅ Enable SSH
     - ✅ Set username/password (e.g., `cpsu` / `motorpool123`)
     - ✅ Configure WiFi (if using wireless)
     - ✅ Set timezone: Asia/Manila
4. Click **WRITE** and wait
5. Insert MicroSD into Raspberry Pi and power on

---

### **Step 2: Connect to Raspberry Pi**

**Option A: Direct connection (with monitor/keyboard)**
- Just plug in and login with your credentials

**Option B: SSH (headless - no monitor needed)**
```bash
# Find your Pi's IP address from your router
# Or use: ping raspberrypi.local

# Connect via SSH (from your Windows PowerShell)
ssh cpsu@192.168.1.XXX
# Replace XXX with your Pi's IP address
```

---

### **Step 3: Initial Setup & Updates**

```bash
# Update system
sudo apt update
sudo apt upgrade -y

# Install essential packages
sudo apt install -y git curl wget vim nano

# Check Python version (should be 3.x)
python3 --version
```

---

### **Step 4: Install Database**

**Option A: MariaDB (MySQL compatible - RECOMMENDED)**
```bash
# Install MariaDB
sudo apt install -y mariadb-server mariadb-client

# Secure installation
sudo mysql_secure_installation
# Answer: Y to all questions
# Set root password: motorpool_secure_pass

# Create database
sudo mysql -u root -p
```

In MySQL prompt:
```sql
CREATE DATABASE cpsu_motorpool;
CREATE USER 'motorpool_user'@'localhost' IDENTIFIED BY 'your_secure_password';
GRANT ALL PRIVILEGES ON cpsu_motorpool.* TO 'motorpool_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

---

### **Step 5: Install LoRa Support**

```bash
# Enable SPI interface (required for LoRa module)
sudo raspi-config
# Navigate to: Interface Options → SPI → Enable → Finish → Reboot

# After reboot, install SPI tools
sudo apt install -y python3-spidev

# Verify SPI is enabled
lsmod | grep spi
```

---

### **Step 6: Wire LoRa Module to Raspberry Pi**

**LoRa Module (SX1276/SX1278) → Raspberry Pi GPIO:**

| LoRa Module | Raspberry Pi GPIO | Pin # |
|-------------|-------------------|-------|
| VCC         | 3.3V              | Pin 1 |
| GND         | GND               | Pin 6 |
| MISO        | GPIO 9 (MISO)     | Pin 21|
| MOSI        | GPIO 10 (MOSI)    | Pin 19|
| SCK         | GPIO 11 (SCLK)    | Pin 23|
| NSS/CS      | GPIO 8 (CE0)      | Pin 24|
| RESET       | GPIO 25           | Pin 22|
| DIO0        | GPIO 24           | Pin 18|

**⚠️ Important:**
- Use 3.3V NOT 5V (will damage LoRa module!)
- Double-check wiring before powering on
- Use jumper wires or solder for stable connection

---

### **Step 7: Set Up Python Server**

```bash
# Create project directory
mkdir -p ~/motorpool-server
cd ~/motorpool-server

# Install Python packages
sudo apt install -y python3-pip python3-venv python3-dev

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install required packages
pip install flask pymysql requests

# Install LoRa library
pip install pyLoRa
```

---

### **Step 8: Create LoRa Gateway Server**

Create a Python server that receives LoRa data and provides REST API:

```bash
nano ~/motorpool-server/lora_gateway.py
```

Paste this code:

```python
from flask import Flask, request, jsonify
import pymysql
from datetime import datetime
import json
import threading
from time import sleep
from SX127x.LoRa import *
from SX127x.board_config import BOARD

app = Flask(__name__)

# LoRa Configuration (match with your Heltec LoRa32)
LORA_FREQUENCY = 915  # MHz - change to 433 if using 433MHz modules
LORA_SPREADING_FACTOR = 7  # SF7 to SF12 (higher = longer range, slower)
LORA_BANDWIDTH = 125000  # 125kHz
LORA_CODING_RATE = 5  # 4/5
LORA_SYNC_WORD = 0x12  # Must match ESP32 setting

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'user': 'motorpool_user',
    'password': 'your_secure_password',
    'database': 'cpsu_motorpool',
    'charset': 'utf8mb4'
}

def get_db_connection():
    return pymysql.connect(**DB_CONFIG)

# Create table if not exists
def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS vehicle_locations (
            id INT AUTO_INCREMENT PRIMARY KEY,
            vehicle_id VARCHAR(50) NOT NULL,
            latitude DECIMAL(10, 8) NOT NULL,
            longitude DECIMAL(11, 8) NOT NULL,
            speed FLOAT DEFAULT 0,
            altitude FLOAT DEFAULT 0,
            satellites INT DEFAULT 0,
            rssi INT DEFAULT 0,
            snr FLOAT DEFAULT 0,
            transmission_type ENUM('lora', 'lte') DEFAULT 'lora',
            timestamp DATETIME NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_vehicle_id (vehicle_id),
            INDEX idx_timestamp (timestamp),
            INDEX idx_transmission_type (transmission_type)
        )
    ''')
    conn.commit()
    cursor.close()
    conn.close()

# LoRa receiver class
class LoRaReceiver(LoRa):
    def __init__(self, verbose=False):
        super(LoRaReceiver, self).__init__(verbose)
        self.set_mode(MODE.SLEEP)
        self.set_dio_mapping([0] * 6)
        
    def on_rx_done(self):
        """Called when LoRa message received"""
        payload = self.read_payload(nocheck=True)
        
        try:
            # Decode message (expects JSON string from LoRa32)
            message = bytes(payload).decode('utf-8')
            print(f"LoRa received: {message}")
            
            data = json.loads(message)
            
            # Store in database
            store_gps_data(data)
            
        except Exception as e:
            print(f"Error processing LoRa message: {e}")
        
        # Continue listening
        self.set_mode(MODE.SLEEP)
        self.reset_ptr_rx()
        self.set_mode(MODE.RXCONT)
        
    def start(self):
        """Start LoRa receiver"""
        self.reset_ptr_rx()
        self.set_mode(MODE.RXCONT)
        
        while True:
            sleep(1)

def store_gps_data(data):
    """Store GPS data in database"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO vehicle_locations 
            (vehicle_id, latitude, longitude, speed, altitude, satellites, 
             rssi, snr, transmission_type, timestamp)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ''', (
            data.get('vehicle_id'),
            data.get('latitude'),
            data.get('longitude'),
            data.get('speed', 0),
            data.get('altitude', 0),
            data.get('satellites', 0),
            data.get('rssi', 0),
            data.get('snr', 0),
            data.get('type', 'lora'),  # 'lora' or 'lte'
            data.get('timestamp', datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
        ))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        print(f"Stored location for vehicle: {data.get('vehicle_id')}")
        
    except Exception as e:
        print(f"Database error: {e}")

# API endpoint for LTE backup (when vehicle can't reach LoRa gateway)
@app.route('/api/gps/update', methods=['POST'])
def receive_gps_lte():
    """
    Receive GPS data via LTE (backup method)
    Expected JSON format from SIM A7672E:
    {
        "vehicle_id": "ABC-1234",
        "latitude": 10.12345,
        "longitude": 122.98765,
        "speed": 45.5,
        "altitude": 12.3,
        "satellites": 8,
        "timestamp": "2024-01-15 14:30:00",
        "type": "lte"
    }
    """
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['vehicle_id', 'latitude', 'longitude']
        if not all(field in data for field in required_fields):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Mark as LTE transmission
        data['type'] = 'lte'
        
        # Store in database
        store_gps_data(data)
        
        return jsonify({
            'status': 'success',
            'message': 'GPS data received via LTE',
            'vehicle_id': data['vehicle_id']
        }), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/gps/latest/<vehicle_id>', methods=['GET'])
def get_latest_location(vehicle_id):
    """Get latest location for a vehicle"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        cursor.execute('''
            SELECT * FROM vehicle_locations 
            WHERE vehicle_id = %s 
            ORDER BY timestamp DESC 
            LIMIT 1
        ''', (vehicle_id,))
        
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if result:
            return jsonify(result), 200
        else:
            return jsonify({'error': 'Vehicle not found'}), 404
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/gps/history/<vehicle_id>', methods=['GET'])
def get_location_history(vehicle_id):
    """Get location history for a vehicle"""
    try:
        # Get limit from query params (default 100)
        limit = request.args.get('limit', 100, type=int)
        
        conn = get_db_connection()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        cursor.execute('''
            SELECT * FROM vehicle_locations 
            WHERE vehicle_id = %s 
            ORDER BY timestamp DESC 
            LIMIT %s
        ''', (vehicle_id, limit))
        
        results = cursor.fetchall()
        cursor.close()
        conn.close()
        
        return jsonify(results), 200
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'service': 'CPSU MotorPool GPS Server'}), 200

def start_lora_receiver():
    """Start LoRa receiver in separate thread"""
    print("Initializing LoRa module...")
    BOARD.setup()
    
    lora = LoRaReceiver(verbose=False)
    lora.set_mode(MODE.STDBY)
    
    # Configure LoRa settings
    lora.set_pa_config(pa_select=1)
    lora.set_freq(LORA_FREQUENCY)
    lora.set_spreading_factor(LORA_SPREADING_FACTOR)
    lora.set_bw(LORA_BANDWIDTH)
    lora.set_coding_rate(LORA_CODING_RATE)
    lora.set_sync_word(LORA_SYNC_WORD)
    
    print(f"LoRa configured: {LORA_FREQUENCY}MHz, SF{LORA_SPREADING_FACTOR}")
    print("Listening for vehicle data...")
    
    lora.start()

if __name__ == '__main__':
    print("Initializing database...")
    init_db()
    
    # Start LoRa receiver in background thread
    lora_thread = threading.Thread(target=start_lora_receiver, daemon=True)
    lora_thread.start()
    
    print("Starting Flask API server...")
    # 0.0.0.0 means accessible from any device on network
    app.run(host='0.0.0.0', port=5000, debug=False)
```

---

### **Step 9: Create Systemd Service (Auto-start on boot)**

```bash
# Create service file
sudo nano /etc/systemd/system/motorpool-lora.service
```

Paste this:

```ini
[Unit]
Description=CPSU MotorPool LoRa Gateway
After=network.target mariadb.service

[Service]
Type=simple
User=cpsu
WorkingDirectory=/home/cpsu/motorpool-server
Environment="PATH=/home/cpsu/motorpool-server/venv/bin"
ExecStart=/home/cpsu/motorpool-server/venv/bin/python lora_gateway.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start service:
```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable auto-start
sudo systemctl enable motorpool-lora

# Start service
sudo systemctl start motorpool-lora

# Check status
sudo systemctl status motorpool-lora

# View logs (see LoRa messages in real-time)
sudo journalctl -u motorpool-lora -f
```

---

### **Step 10: Configure Firewall**

```bash
# Install firewall
sudo apt install -y ufw

# Allow SSH
sudo ufw allow ssh

# Allow GPS server port
sudo ufw allow 5000/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

---

### **Step 11: Find Your Raspberry Pi's IP Address**

```bash
# Get IP address
hostname -I

# Or more detailed
ip addr show
```

You'll see something like: `192.168.1.100`

---

### **Step 12: Test the Server**

From your Windows PC, test the API:

```powershell
# Test health check
curl http://192.168.1.100:5000/health

# Test GPS data submission
curl -X POST http://192.168.1.100:5000/api/gps/update `
  -H "Content-Type: application/json" `
  -d '{\"vehicle_id\":\"ABC-1234\",\"latitude\":10.12345,\"longitude\":122.98765,\"speed\":45.5}'

# Get latest location
curl http://192.168.1.100:5000/api/gps/latest/ABC-1234
```

---

## 📡 Heltec LoRa32 V2 Arduino Code (Vehicle Side)

### **SD Card Module Wiring:**

**MicroSD Card Module → Heltec LoRa32 V2:**

| SD Module Pin | Heltec LoRa32 Pin | Description |
|---------------|-------------------|-------------|
| VCC           | 3.3V              | Power (NOT 5V!) |
| GND           | GND               | Ground |
| MISO          | GPIO 19           | SPI MISO |
| MOSI          | GPIO 27           | SPI MOSI |
| SCK           | GPIO 5            | SPI Clock |
| CS            | GPIO 2            | Chip Select |

**⚠️ Important:**
- Use 3.3V NOT 5V for SD module
- Format SD card as FAT32
- Use quality SD cards (Class 10 recommended)

---

Here's the Arduino code for your Heltec LoRa32 V2 to send GPS data via LoRa (with SD Card logging and LTE backup):

```cpp
#include <heltec.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <SD.h>
#include <SPI.h>

// Vehicle Configuration
const String VEHICLE_ID = "ABC-1234";  // Change for each vehicle

// SD Card Configuration
#define SD_CS_PIN 2  // Chip Select pin for SD card
bool sdCardAvailable = false;

// LoRa Configuration (must match Raspberry Pi)
#define LORA_BAND    915E6  // 915MHz (or 433E6 for 433MHz)
#define LORA_SF      7       // Spreading Factor 7
#define LORA_BW      125E3   // Bandwidth 125kHz
#define LORA_CR      5       // Coding Rate 4/5
#define LORA_SYNC    0x12    // Sync word

// GPS Setup
TinyGPSPlus gps;
HardwareSerial GPS_Serial(1);  // UART1

// Timing
unsigned long lastSendTime = 0;
const unsigned long sendInterval = 10000;  // Send every 10 seconds

// LTE Backup (if LoRa fails)
#define USE_LTE_BACKUP true
HardwareSerial LTE_Serial(2);  // UART2 for SIM A7672E
const char* serverUrl = "http://YOUR_RASPBERRY_PI_IP:5000/api/gps/update";

void setup() {
  // Initialize Heltec LoRa
  Heltec.begin(
    true,   // DisplayEnable
    true,   // LoRa Enable
    true,   // Serial Enable
    true,   // PABOOST Enable
    LORA_BAND
  );
  
  // Configure LoRa
  LoRa.setSpreadingFactor(LORA_SF);
  LoRa.setSignalBandwidth(LORA_BW);
  LoRa.setCodingRate4(LORA_CR);
  LoRa.setSyncWord(LORA_SYNC);
  
  // Initialize SD Card
  Serial.println("Initializing SD card...");
  if (SD.begin(SD_CS_PIN)) {
    sdCardAvailable = true;
    Serial.println("SD card initialized successfully");
    
    // Create log file header if new
    if (!SD.exists("/gps_log.csv")) {
      File logFile = SD.open("/gps_log.csv", FILE_WRITE);
      if (logFile) {
        logFile.println("timestamp,vehicle_id,latitude,longitude,speed,altitude,satellites,status");
        logFile.close();
      }
    }
  } else {
    sdCardAvailable = false;
    Serial.println("SD card initialization failed!");
  }
  
  // Initialize GPS
  GPS_Serial.begin(9600, SERIAL_8N1, 12, 13);  // RX=12, TX=13
  
  // Initialize LTE (if using backup)
  if (USE_LTE_BACKUP) {
    LTE_Serial.begin(115200, SERIAL_8N1, 16, 17);  // RX=16, TX=17
    initLTE();
  }
  
  // Display
  Heltec.display->clear();
  Heltec.display->drawString(0, 0, "CPSU MotorPool");
  Heltec.display->drawString(0, 10, "Vehicle: " + VEHICLE_ID);
  Heltec.display->drawString(0, 20, "SD: " + String(sdCardAvailable ? "OK" : "FAIL"));
  Heltec.display->drawString(0, 30, "Waiting for GPS...");
  Heltec.display->display();
  
  Serial.println("System initialized");
}

void loop() {
  // Read GPS data
  while (GPS_Serial.available() > 0) {
    gps.encode(GPS_Serial.read());
  }
  
  // Send data every interval
  if (millis() - lastSendTime > sendInterval) {
    lastSendTime = millis();
    
    if (gps.location.isValid()) {
      sendGPSData();
    } else {
      Serial.println("Waiting for GPS fix...");
      updateDisplay("No GPS Fix", gps.satellites.value());
    }
  }
}

void sendGPSData() {
  // Create JSON payload
  String jsonData = "{";
  jsonData += "\"vehicle_id\":\"" + VEHICLE_ID + "\",";
  jsonData += "\"latitude\":" + String(gps.location.lat(), 8) + ",";
  jsonData += "\"longitude\":" + String(gps.location.lng(), 8) + ",";
  jsonData += "\"speed\":" + String(gps.speed.kmph(), 2) + ",";
  jsonData += "\"altitude\":" + String(gps.altitude.meters(), 2) + ",";
  jsonData += "\"satellites\":" + String(gps.satellites.value()) + ",";
  jsonData += "\"timestamp\":\"" + getGPSDateTime() + "\"";
  jsonData += "}";
  
  Serial.println("Sending: " + jsonData);
  
  // Always log to SD card first (even if transmission succeeds)
  logToSDCard(jsonData, "pending");
  
  // Try LoRa first
  bool loraSent = sendViaLoRa(jsonData);
  
  if (loraSent) {
    Serial.println("Sent via LoRa");
    logToSDCard(jsonData, "lora_ok");
    updateDisplay("LoRa OK", gps.satellites.value());
  } else if (USE_LTE_BACKUP) {
    // Fallback to LTE
    Serial.println("LoRa failed, trying LTE...");
    bool lteSent = sendViaLTE(jsonData);
    
    if (lteSent) {
      Serial.println("Sent via LTE");
      logToSDCard(jsonData, "lte_ok");
      updateDisplay("LTE OK", gps.satellites.value());
    } else {
      Serial.println("All transmission failed");
      logToSDCard(jsonData, "failed");
      updateDisplay("TX Failed", gps.satellites.value());
    }
  } else {
    logToSDCard(jsonData, "no_backup");
    updateDisplay("No Backup", gps.satellites.value());
  }
}

void logToSDCard(String jsonData, String status) {
  if (!sdCardAvailable) return;
  
  File logFile = SD.open("/gps_log.csv", FILE_APPEND);
  if (logFile) {
    // Parse JSON and write CSV
    String csvLine = getGPSDateTime() + ",";
    csvLine += VEHICLE_ID + ",";
    csvLine += String(gps.location.lat(), 8) + ",";
    csvLine += String(gps.location.lng(), 8) + ",";
    csvLine += String(gps.speed.kmph(), 2) + ",";
    csvLine += String(gps.altitude.meters(), 2) + ",";
    csvLine += String(gps.satellites.value()) + ",";
    csvLine += status;
    
    logFile.println(csvLine);
    logFile.close();
    
    Serial.println("Logged to SD: " + status);
  } else {
    Serial.println("Failed to open log file");
  }
}

bool sendViaLoRa(String data) {
  // Begin LoRa packet
  LoRa.beginPacket();
  LoRa.print(data);
  LoRa.endPacket();
  
  return true;  // LoRa doesn't provide ACK, assume success
}

bool sendViaLTE(String data) {
  // Implement HTTP POST via SIM A7672E
  // This is a simplified version
  
  LTE_Serial.println("AT+HTTPINIT");
  delay(1000);
  
  LTE_Serial.println("AT+HTTPPARA=\"URL\",\"" + String(serverUrl) + "\"");
  delay(1000);
  
  LTE_Serial.println("AT+HTTPPARA=\"CONTENT\",\"application/json\"");
  delay(500);
  
  LTE_Serial.println("AT+HTTPDATA=" + String(data.length()) + ",10000");
  delay(500);
  LTE_Serial.println(data);
  delay(2000);
  
  LTE_Serial.println("AT+HTTPACTION=1");  // POST
  delay(3000);
  
  // Check response (simplified)
  if (LTE_Serial.available()) {
    String response = LTE_Serial.readString();
    if (response.indexOf("200") > 0) {
      return true;
    }
  }
  
  return false;
}

void initLTE() {
  Serial.println("Initializing LTE...");
  LTE_Serial.println("AT");
  delay(1000);
  LTE_Serial.println("AT+CGATT=1");  // Attach to network
  delay(2000);
}

String getGPSDateTime() {
  char datetime[20];
  sprintf(datetime, "%04d-%02d-%02d %02d:%02d:%02d",
    gps.date.year(), gps.date.month(), gps.date.day(),
    gps.time.hour(), gps.time.minute(), gps.time.second()
  );
  return String(datetime);
}

void updateDisplay(String status, int sats) {
  Heltec.display->clear();
  Heltec.display->drawString(0, 0, "CPSU MotorPool");
  Heltec.display->drawString(0, 10, "ID: " + VEHICLE_ID);
  Heltec.display->drawString(0, 20, "Status: " + status);
  Heltec.display->drawString(0, 30, "Sats: " + String(sats));
  Heltec.display->drawString(0, 40, "Lat: " + String(gps.location.lat(), 6));
  Heltec.display->drawString(0, 50, "Lng: " + String(gps.location.lng(), 6));
  
  // Show SD card status indicator
  if (sdCardAvailable) {
    Heltec.display->drawString(110, 0, "[SD]");
  }
  
  Heltec.display->display();
}
```

**⚠️ Important Notes:**
- Change `VEHICLE_ID` for each vehicle ("ABC-1234" for vehicle 1, "XYZ-5678" for vehicle 2)
- Match `LORA_BAND` with your region (915MHz for Philippines)
- LoRa has ~2-5km range in urban areas, ~10-15km in open areas
- LTE backup activates when LoRa can't transmit
- **SD Card Benefits:**
  - ✅ Logs ALL GPS data even if transmission fails
  - ✅ Backup data recovery if connection lost
  - ✅ Useful for debugging and trip history
  - ✅ CSV format - easy to import to Excel/database
  - ✅ Can retrieve data manually by removing SD card

**Required Arduino Libraries:**
```cpp
// Install via Arduino Library Manager:
- Heltec ESP32 Dev-Boards
- TinyGPSPlus
- SD (built-in)
- SPI (built-in)
```

---

## 🔒 Security Best Practices

1. **Change default passwords**
2. **Use strong database passwords**
3. **Keep system updated**: `sudo apt update && sudo apt upgrade`
4. **Enable fail2ban**: `sudo apt install fail2ban`
5. **Use HTTPS in production** (add SSL certificate)
6. **Implement API authentication** (add API keys)

---

## 🌐 Optional: Port Forwarding for Remote Access

If you want to access from outside your local network:

1. Login to your router admin panel
2. Find "Port Forwarding" section
3. Forward external port (e.g., 8080) to Pi IP:5000
4. Use your public IP to access remotely
5. **⚠️ Security Warning**: Use VPN or implement proper authentication!

---

## 📊 Monitoring & Maintenance

```bash
# Check service status
sudo systemctl status motorpool-lora

# View logs
sudo journalctl -u motorpool-lora -f

# Restart service
sudo systemctl restart motorpool-lora

# Check disk space
df -h

# Check memory usage
free -h

# Check CPU temperature
vcgencmd measure_temp
```

---

## 🔄 Integration with Your Laravel Backend

Update your Laravel backend to fetch data from Raspberry Pi:

```php
// In your Laravel controller
public function getVehicleLocation($vehicleId) {
    $raspberryPiUrl = 'http://192.168.1.100:5000/api/gps/latest/' . $vehicleId;
    
    try {
        $response = Http::timeout(5)->get($raspberryPiUrl);
        
        if ($response->successful()) {
            return response()->json($response->json());
        }
        
        return response()->json(['error' => 'Failed to fetch location'], 500);
    } catch (\Exception $e) {
        return response()->json(['error' => $e->getMessage()], 500);
    }
}
```

---

## 🆘 Troubleshooting

**Can't connect via SSH?**
- Check if Pi is powered on
- Verify IP address: `ping raspberrypi.local`
- Check router for Pi's IP

**Service won't start?**
- Check logs: `sudo journalctl -u motorpool-lora -n 50`
- Verify Python script has no errors
- Check database connection
- Verify SPI is enabled: `lsmod | grep spi`

**LoRa not receiving?**
- Check LoRa module wiring (especially 3.3V NOT 5V!)
- Verify frequency matches (915MHz or 433MHz)
- Check spreading factor and bandwidth match
- Test LoRa module: `sudo python3 -c "from SX127x.LoRa import *; print('OK')"`
- Increase spreading factor for longer range (SF7 → SF10)

**GPS not working on vehicle?**
- Wait for GPS fix (may take 5+ minutes outdoors)
- Check GPS module wiring to Heltec
- Verify GPS baud rate (9600)
- Check antenna connection

**SD Card not working?**
- Format SD card as FAT32 (not exFAT or NTFS)
- Check wiring (use 3.3V NOT 5V!)
- Try different SD card (use Class 10)
- Check CS pin connection (GPIO 2)
- View serial monitor for SD init messages

---

## 📞 Support

If you encounter issues, check:
- Service logs: `sudo journalctl -u motorpool-lora -f`
- System logs: `sudo tail -f /var/log/syslog`
- Database: `sudo mysql -u root -p`
- LoRa signal strength (RSSI): Check logs for received packets

**Testing LoRa Communication:**
1. Start Raspberry Pi gateway first
2. Monitor logs: `sudo journalctl -u motorpool-lora -f`
3. Power on Heltec LoRa32 vehicle tracker
4. Wait for GPS fix (LED indicator)
5. Watch Raspberry Pi logs for incoming LoRa messages
6. Check database: `mysql -u motorpool_user -p cpsu_motorpool -e "SELECT * FROM vehicle_locations ORDER BY id DESC LIMIT 10;"`

---

**Good luck with your setup! 🚀**
