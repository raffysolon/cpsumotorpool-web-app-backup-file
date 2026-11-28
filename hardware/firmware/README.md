# GPS2 firmware pair — bench-test version

## Files and configuration

- `VEHICLE_TRACKER_SYNC_V2/VEHICLE_TRACKER_SYNC_V2.ino`: vehicle GPS, SD outbox, LTE and LoRa retry.
- `ADMIN_LORA_SYNC_V2/ADMIN_LORA_SYNC_V2.ino`: receiver and USB acknowledgment relay.
- `../gateway/gateway.py`: matching Pi program. Update all three together; the previous four-field receiver is incompatible.

Target: Heltec WiFi LoRa 32 V2, ESP32 Arduino core 3.3.7 (as supplied by the user). Install LoRa by Sandeep Mistry, TinyGPSPlus, Adafruit SSD1306/GFX and ArduinoJson **7**. No Arduino compiler/toolchain was available here, so these sketches have NOT been compiled or flashed. Verify in Arduino IDE before use.

Vehicle setup:
1. Copy `device_secrets.example.h` to `device_secrets.h`, and enter the provisioned **individual tracker key**, not the Pi's shared gateway key. Each registered device needs its own key.
2. Copy your previously verified `root_ca.h` defining `ROOT_CA` into the vehicle sketch folder. Its certificate must validate the actual backend TLS chain. No certificate/key is included here.
3. Check `DEVICE_ID`, APN and backend URL. Pin assignments follow the supplied firmware: GPS RX36/TX17, LTE TX22/RX13, SD CS23; SPI5/19/27; LoRa CS18/RST14/DIO026; OLED4/15/RST16/VEXT21.
4. Set `ENABLE_LTE=false` for LoRa-only testing if the modem/power supply is not ready. Both radio boards must have working appropriate antennas before transmitting, including the admin board which now sends ACKs.

Both radios use 915 MHz, SF7, BW125kHz, CR4/5, sync word0x12 and CRC enabled. The supplied older firmware disabled CRC; do not mix versions. Frequency/power suitability must be confirmed for your deployment.

## Record and acknowledgment flow

1. Fresh GPS fixes are appended to `/gps_v2.log` with the same record ID, sequence and UTC capture time used on every transport. Original `/gps_log.csv` is untouched; it is NOT automatically imported.
2. One oldest pending record is attempted over LTE, then LoRa if LTE fails.
3. Pi commits to SQLite, then returns `ACK2|device|record|PI` over USB. Admin radio relays it.
4. Pi uploads via HTTPS. Only matching backend acknowledgments produce cloud_saved state.
5. On the vehicle's next retry, Pi replies `ACK2|device|record|CLOUD` if cloud_saved. Vehicle advances its persisted cursor. Archive bytes remain on SD.

The PI acknowledgment does **not** advance the vehicle cursor. This deliberately conservative first version waits for cloud confirmation before moving to the next record. **It cannot bulk-offload the entire SD backlog while the Pi has no internet.** Do not present it as completed offline recovery. That needs a separate durable handoff cursor, a replay/reconciliation protocol and transfer sessions.

Identical IDs are used for LTE/LoRa to allow backend deduplication. HTTP 409 or malformed acknowledgments never advance the cursor. Never erase NVS, replace `/gps_v2.log`, change device ID, or downgrade firmware without a sequence/cursor migration: that can reuse IDs or invalidate offsets. NVS failure, partial SD write or a damaged tail stops new persistence for inspection. No data is automatically deleted or formatted. Back up the SD before testing.

## Remaining limitations

- No trip-start gating: like the supplied firmware, GPS recording starts when valid GPS/time is available. Driver Start Trip does not yet command this firmware.
- LTE heartbeat is attempted every60s while powered with modem/time available. This does not prove engine-on. LoRa recovery does not impersonate a live LTE heartbeat.
- LTE attach and HTTPS calls can block GPS processing and stretch the nominal15s sample interval. The UART buffer reduces but cannot eliminate this. A task-based acquisition/uplink design is needed for uninterrupted sampling under bad LTE.
- CRC detects radio corruption; it does NOT authenticate a radio peer. These ACKs are for a trusted bench environment; authenticated radio messages and replay protection are required before deployment in an untrusted environment.
- Pi storage and SD archives grow without automatic retention cleanup.
- Multiple-vehicle collisions, long-range performance, power interruption, carrier PPP reconnect behavior and physical SD durability are untested.
- No cloud transfer-status endpoint is added by these files. OLED status describes recent packet activity, not full-trip completion. Dashboard integration remains pending.

## Bench checklist

1. Arduino Verify both sketches; resolve actual library/core compatibility before flashing.
2. Confirm SD writes, GPS UTC and monotonically increasing IDs over reboot.
3. With LTE disabled, confirm `GPS2|...` appears once per received radio packet on Pi USB.
4. With Pi internet disabled, confirm PI acknowledgment and a durable pending row; vehicle must keep the same pending record.
5. Restore Pi internet, confirm HTTP acknowledgment and CLOUD ACK on retry; vehicle must then advance.
6. Repeat an identical record through both LTE and LoRa: only one database GPS record should exist.
7. Disconnect USB/power at each stage; verify records are retried and never considered cloud_saved without confirmation.

References used: https://github.com/sandeepmistry/arduino-LoRa/blob/master/API.md and Espressif's PPP example. A reference review is not a firmware compilation or hardware test.
