# CPSU MotorPool Hardware Setup Guide

## System Overview

```
[Vehicle Tracker] --LoRa--> [Raspberry Pi Gateway] --Internet--> [Cloud Database]
                                                                        ↓
                                                                  [Admin Web App]
```

---

## 1. ADMIN SIDE HARDWARE

### Computer/Laptop Requirements
- **Purpose**: Run the Admin Web Application
- **Minimum Specs**:
  - Windows 10/11 or macOS or Linux
  - 4GB RAM minimum
  - Modern web browser (Chrome, Edge, Firefox)
  - Internet connection
- **What it does**: 
  - Register vehicles
  - Register devices (link tracker to vehicle)
  - Monitor real-time vehicle locations
  - Manage trips, assignments, fuel
  - Generate reports

### Raspberry Pi 4 (Gateway)
- **Model**: Raspberry Pi 4 (4GB RAM recommended)
- **Cost**: ₱4,000 - ₱5,000
- **Purpose**: Receive GPS data from vehicle trackers via LoRa
- **Components needed**:
  - Raspberry Pi 4 Board
  - 32GB microSD card (with Raspberry Pi OS)
  - 5V 3A USB-C power supply
  - LoRa module (SX1276 V2, 915MHz)
  - Case (optional but recommended)
  - Ethernet cable or WiFi for internet

**Total Gateway Cost**: ₱6,200 (Pi + LoRa module + accessories)

**Setup Steps**:
1. Install Raspberry Pi OS on microSD card
2. Connect SX1276 LoRa module via GPIO pins
3. Install Python and required libraries
4. Run gateway script (`raspberry_pi_gateway.py`)
5. Keep powered on 24/7 within campus

**Where to place**: 
- Central location on campus (CPSU)
- Must have LoRa coverage to parking areas
- Must have stable internet connection
- Protected from weather (indoors recommended)

---

## 2. VEHICLE SIDE HARDWARE

### GPS Tracker (Per Vehicle)

**Main Components**:

1. **Heltec LoRa32 V2**
   - ESP32 microcontroller + SX1276 LoRa radio
   - Built-in OLED display (0.96")
   - WiFi and Bluetooth
   - Cost: ₱1,580

2. **NEO-6M GPS Module**
   - Receives satellite GPS signals
   - Provides latitude, longitude, speed
   - Cost: ₱250

3. **SIM A7672E LTE Module** 
   - 4G cellular connectivity (backup when out of LoRa range)
   - SIM card for mobile data
   - Cost: ₱1,800

4. **SD Card Module**
   - Stores GPS logs locally (backup)
   - microSD card (16GB or larger)
   - Cost: ₱150 (module) + ₱200 (card)

5. **Battery System**
   - 7.4V 12,000mAh Li-ion battery pack
   - BMS (Battery Management System) included
   - LM2596 step-down converter (7.4V → 5V)
   - Cost: ₱2,000 (battery + BMS + converter)

**Total Cost Per Vehicle Tracker**: ₱5,980

### How the Tracker Works

1. **GPS Module** gets location from satellites
2. **Heltec LoRa32** processes the data
3. **Transmission** (3 methods):
   - **Primary**: LoRa radio → Raspberry Pi Gateway (free, on campus)
   - **Backup**: LTE cellular → Cloud directly (when far from campus)
   - **Always**: SD card logs data (if connection fails)
4. **Power**: Battery lasts 24-48 hours, recharge via USB-C

### Installation in Vehicle

**Mounting**:
- GPS antenna near windshield (clear sky view)
- Main unit under dashboard or in glove compartment
- Keep away from metal surfaces (interferes with GPS)
- Secure cables to prevent disconnection

**Power Options**:
- **Option A**: Rechargeable battery (remove and charge)
- **Option B**: Wire to vehicle 12V system (permanent installation)

**Wiring** (if permanent):
```
Vehicle 12V Battery → Fuse (2A) → LM2596 Converter (set to 5V) → Heltec LoRa32
```

---

## 3. SYSTEM FLOW

### Registration Process

**Step 1: Register Vehicle in Admin**
- Admin logs into web app
- Go to "Vehicles & Drivers" page
- Click "Register Vehicle"
- Enter plate number (e.g., "ABC-1234")
- System saves vehicle to database

**Step 2: Program Vehicle Tracker**
- Connect Heltec LoRa32 to computer via USB
- Upload Arduino code with matching device_id
- **Device ID Format**: `LORA32_ABC1234` (plate without dash)
- Example: Plate "ABC-1234" → Device ID "LORA32_ABC1234"

**Step 3: Register Device in Admin**
- Admin goes to "Device Registry" page
- Click "Register New Device"
- Enter Device ID: `LORA32_ABC1234`
- Select Vehicle: ABC-1234 from dropdown
- Click Register
- System links tracker to vehicle

### Real-Time Tracking

**Every 30 seconds** (or configured interval):

1. **Vehicle Tracker**:
   - GPS gets current location
   - Heltec prepares data packet:
     ```json
     {
       "device_id": "LORA32_ABC1234",
       "latitude": 8.4857,
       "longitude": 124.6565,
       "speed": 45.5,
       "timestamp": "2026-11-07 14:30:00"
     }
     ```
   - Sends via LoRa to Gateway

2. **Raspberry Pi Gateway**:
   - Receives LoRa transmission
   - Checks if device is registered in database
   - If registered: forwards to cloud database
   - If not registered: rejects with error

3. **Admin Web App**:
   - Automatically refreshes vehicle locations
   - Shows real-time markers on map
   - Updates "Last Seen" timestamp
   - Shows online/offline status

---

## 4. COST BREAKDOWN

### One-Time Setup (First Vehicle)
| Item | Cost |
|------|------|
| Raspberry Pi 4 Gateway (complete) | ₱6,200 |
| Vehicle Tracker #1 (complete) | ₱5,980 |
| **TOTAL** | **₱12,180** |

### Additional Vehicles
| Item | Cost |
|------|------|
| Vehicle Tracker (per unit) | ₱5,980 |

**Example**: 5 vehicles total
- Gateway: ₱6,200 (one time)
- 5 Trackers: ₱5,980 × 5 = ₱29,900
- **Grand Total**: ₱36,100

### Monthly Operating Cost
| Item | Cost/Month |
|------|------------|
| SIM load per vehicle (1GB data) | ₱300 |
| Electricity (Pi + charging) | ~₱100 |
| **Per vehicle** | **₱300-400** |

---

## 5. ADMIN OPERATIONS

### Daily Tasks
- Open admin web app on computer
- Check all vehicles online/offline
- Monitor active trips on map
- Approve trip requests
- Review fuel usage

### Device Management
- **Register new tracker**: Device Registry → Register
- **Check device status**: See last seen time, online indicator
- **Unregister device**: Remove before vehicle decommission
- **Reassign device**: Unlink from old vehicle, link to new one

### Troubleshooting
| Problem | Check |
|---------|-------|
| Vehicle not showing on map | Device registered? Online status? |
| "Device not found" error | Device ID matches exactly? Case-sensitive! |
| Old location data | Tracker battery dead? LoRa/LTE connection? |
| Gateway offline | Raspberry Pi powered on? Internet connected? |

---

## 6. HARDWARE MAINTENANCE

### Vehicle Tracker
- **Battery**: Recharge every 1-2 days (or wire to vehicle power)
- **GPS antenna**: Keep clear, no obstructions
- **Check monthly**: Connections tight, no water damage
- **SD card**: Replace annually, backup logs quarterly

### Raspberry Pi Gateway
- **Power**: Keep plugged in 24/7
- **Cooling**: Ensure airflow, consider fan in case
- **Updates**: SSH login monthly, run `sudo apt update && sudo apt upgrade`
- **Backup**: Copy gateway script and configs monthly
- **SD card**: Use quality card, replace every 2 years

### Expected Lifespan
- Vehicle Tracker: 3-5 years
- Battery: 2-3 years (rechargeable cycle limit)
- Raspberry Pi: 5+ years
- GPS Module: 5+ years
- LoRa Modules: 5+ years

---

## 7. DEVICE ID RULES (IMPORTANT!)

### Format Rules
✅ **Correct**: `LORA32_ABC1234` (plate without dash)
❌ **Wrong**: `LORA32_ABC-1234` (has dash)
❌ **Wrong**: `lora32_abc1234` (lowercase)
❌ **Wrong**: `LORA32_abc1234` (mixed case)

### Must Match Exactly
- Device ID in Arduino code = Device ID in Admin = Device ID in Database
- **Case-sensitive**: `LORA32_ABC1234` ≠ `lora32_abc1234`
- **No extra spaces**: `LORA32_ABC1234` ≠ `LORA32_ ABC1234`

### Why It Matters
When tracker sends data, backend checks:
```
SELECT * FROM device_registry WHERE device_id = 'LORA32_ABC1234'
```
If exact match found → Accept data
If not found → Reject with 404 error

---

## Summary

**ADMIN NEEDS**:
- Computer with web browser
- Raspberry Pi 4 + LoRa module (gateway)
- Internet connection
- Admin account access

**EACH VEHICLE NEEDS**:
- GPS Tracker (Heltec + GPS + LTE + SD + Battery)
- Installed in vehicle
- Registered in admin system
- SIM card with data plan

**SYSTEM WORKS**:
Vehicle Tracker → LoRa/LTE → Gateway → Cloud → Admin sees real-time location

**KEY POINT**: Device ID must match exactly between hardware code and admin registration!

