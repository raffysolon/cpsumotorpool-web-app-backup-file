# CPSU MOTORPOOL TRACKER — DETAILED PROJECT HANDOFF FOR CODEX

**Compiled:** November 18, 2026 (Philippines time, UTC+8)  
**Purpose:** Transfer the verified history, architecture, state, decisions, tests, software paths, troubleshooting, and next tasks from ChatGPT conversations to Codex in VS Code.  
**Evidence policy:** Information marked VERIFIED was directly supported by code, logs, screenshots or successful commands shared in conversations. REPORTED indicates user-provided setup or past summary. PENDING means not yet demonstrated. Exact dates are only assigned where prior messages or logs establish them; some intermediate work cannot reliably be attributed to a specific day.

## 1. User's overarching instructions
- This is an EXISTING project. User directive: “Use this as the master context for my CPSU Motorpool Tracker. Continue from the current stopping point. Do not restart the project or change the architecture unnecessarily. Guide me one hardware step at a time.”
- User is a BSIT student carrying out hardware, Laravel backend, Raspberry Pi gateway, Flutter web/driver frontend and database integration.
- Preserve existing working code, UI layout, database records, deployment, hardware wiring, and prior project decisions.
- Prefer concise practical instructions and incremental testing over repeated setup or unnecessary architectural redesign.
- Do not repeat requests for secrets, keys, known device ID, coordinate sample, repo URLs, or tests already completed.

## 2. Project purpose and intended end-to-end architecture
CPSU Motorpool Tracker handles motorpool vehicles, drivers, devices and location tracking. The intended topology is:

```
Vehicle GPS module / recorded GPS sample
       |
Heltec WiFi LoRa 32 V2 (driver/vehicle node)
       |\
       | \--> microSD local/offline log (historically tested)
       |
       +--> 915 MHz LoRa --> Heltec receiver / Raspberry Pi 4 admin gateway
       |                  --> internet --> Laravel REST API
       |
       +--> HAISEN MCore A7672E-FASE LTE carrier, TNT SIM
                                     --> mobile data (PPP)
                                     --> HTTPS --> Laravel REST API on Render
                                                    |
                                                    v
                                             Supabase PostgreSQL
                                                    |
                                                    v
                                         Flutter/Dart admin dashboard
                                               Device Registry
                                               Map / latest GPS
                                               Trips and other UI
```

- Raspberry Pi is a LoRa gateway, not the application database/backend. Its connectivity and gateway script were tested separately.
- LTE is a vehicle-to-cloud option. LoRa+gateway remains an alternative; neither replaces the other automatically.
- microSD stores GPS records for offline capability, but complete conflict-free offline sync and deduplication were NOT yet verified.
- Final plan includes supporting two vehicle units; initial demonstrated device is `VEHICLE-01`.

## 3. Repositories, deployment and local tooling

### GitHub / web
- **Flutter admin web app current repository:** `https://github.com/raffysolon/cpsumotorpool-web-app-backup-file`
- **Laravel backend:** `https://github.com/raffysolon/cpsu-motorpool-backend`
- **Driver Flutter app:** `https://github.com/raffysolon/cpsu-motorpool-driver-app` (historical name `cpsu-motorpool-driver-app-main`; inspect actual repo)
- **Deployed admin web UI:** `https://cpsumotorpool.vercel.app/`
- **Deployed Laravel:** `https://cpsu-motorpool-backend.onrender.com/`
- **GPS POST endpoint:** `https://cpsu-motorpool-backend.onrender.com/api/gps/location`
- Repository has a backup-related name and another backup branch, but **branch name and exact commit are not verified**. User most recently chose to clone the current repository/main and continue from it, rather than switch to the old backup branch.
- Flutter/Dart application; past project context reports `flutter_map` ~8.3.1. Check `pubspec.yaml` for exact installed version.
- Laravel 12 / Sanctum 4 were reported in prior setup; confirm in `composer.json` before relying on version-specific syntax.

### Windows workstation
- Windows PC; VS Code, PowerShell, Arduino IDE 1.8.19, Heltec board definition on ESP32 Arduino core **3.3.7**.
- Earlier PHP/XAMPP was **PHP 8.0.30** with OpenSSL/Composer certificate problems.
- Installed standalone PHP **8.3.33** at `C:\php83\php.exe`; loaded ini `C:\php83\php.ini`.
- Composer **2.11.2** reported on Nov 10. Windows CA root bundle exported to `C:\php83\windows-ca.pem`, configured via `openssl.cafile` and `curl.cainfo` to resolve CA verification.
- Laravel backend initially sat in OneDrive folder; `bootstrap/cache` existed but was not writable. Moving to `C:\cpsu-motorpool-backend-main` resolved environment issues; `composer install` succeeded with 121 packages installed.
- Commands previously run included `php artisan`, `php --ini`, `where php`, curl tests, composer version checks.
- Arduino GPS test original folder was **`C:\Arduino\CPSU_LTE_GPS_POST_TEST.ino\`**, unusually with `.ino` in the directory name. Main file was **`CPSU_LTE_GPS_POST_TEST.ino.ino`**. Do not assume folder has been renamed; use IDE Sketch > Show Sketch Folder. A later Arduino compilation problem was traced/suspected to duplicate definitions from multiple `.ino` sketch files; inspect folder contents and keep backups before moving files.

## 4. Hardware inventory, tested wiring, caveats

### Driver/vehicle ESP32
- **Heltec WiFi LoRa 32 V2**, driver/vehicle unit; has a usable LoRa antenna assembly.
- A separate Admin Heltec's LoRa antenna pigtail was damaged; avoid transmitting with damaged/missing antenna and replace it before LoRa RF use.
- Existing SD wiring used **GPIO13 as SD chip-select**, which conflicts with the **working LTE UART RX GPIO13** pin. Integration of LoRa + SD + LTE on one unit requires pin planning, code changes and retesting; current LTE-only proof is valid but not final combined wiring.

### LTE carrier/modem
- **HAISEN MCore A7672E-FASE 4G LTE carrier** with TNT SIM.
- Carrier vendor product described UART as **3.3 V TTL default**. Do not confuse the carrier's TTL interface with bare SIMCom module native UART voltage.
- **Verified working cable map:** Heltec **GPIO22 (TX)** → HAISEN **UTX**, Heltec **GPIO13 (RX)** ← HAISEN **URX**, shared **GND**. Unusual UTX/URX labeling is per carrier and is proven by successful UART AT tests. Boards independently powered over USB for these tests.
- UART2 at **115200 baud**, no hardware flow control, using `PPP.setPins(22, 13, -1, -1, ESP_MODEM_FLOW_CONTROL_NONE)`.
- Previous GPIO34 receive attempt / loopback failed; switching to GPIO13 succeeded (`HELLO` seven-byte UART loopback) and AT commands returned `OK`.
- The project does **not** require an extra TXS0108E level converter or XL4015 just to reproduce the now-working USB-powered LTE carrier test. Final portable power/battery management still needs validation; earlier discussions used LM2596-type buck converter considerations.
- LTE-only test sketches deliberately do not initialize/transmit on LoRa.

### GPS and SD
- Recorded GPS sample used for Laravel POST: `VEHICLE-01,10.589795,123.476213,12`, found in driver SD `gps_log.csv`.
- Successful LTE POST from Nov 18 used this **stored coordinate**, not a fresh live GPS reading. Do NOT claim full GNSS live tracking is finished.
- Other historical packet example `VEHICLE-01,LAT:10.589759,LON:123.476157,SAT:7` appeared during LoRa/GPS tests.

## 5. Cellular setup and modem verification
- SIM PIN: `AT+CPIN?` returned `+CPIN: READY`.
- Network signal: `AT+CSQ` returned `24,99` (roughly −65 dBm RSSI in GSM CSQ conversion).
- Attached: `AT+CGATT?` returned `+CGATT: 1`.
- APN configured and acknowledged: `talkntext.MNC003.MCC515.GPRS`; checked through `AT+CGDCONT?`. PDP contexts 1 and 8 were active in earlier output.
- ESP32 `PPP.h` successfully entered modem data mode, attached, and received mobile IP addresses, e.g. `10.217.43.241` and later `10.191.118.93` (carrier/private addresses; not fixed IP).
- Core working flow:
  ```cpp
  PPP.setApn("talkntext.MNC003.MCC515.GPRS");
  PPP.setPins(22, 13, -1, -1, ESP_MODEM_FLOW_CONTROL_NONE);
  PPP.begin(PPP_MODEM_GENERIC, 2, 115200);
  PPP.attached();
  PPP.mode(ESP_MODEM_MODE_DATA);
  PPP.waitStatusBits(ESP_NETIF_CONNECTED_BIT, 30000);
  Network.setDefaultInterface(PPP);
  ```
  The production sketch handles failures at each step; shown here only to identify interfaces.
- Before verified HTTPS certificate testing, temporary `NetworkClientSecure::setInsecure()` was used ONLY for diagnostics: `https://example.com/` returned HTTP 200 twice; Render homepage HTTP 200; GET to POST-only GPS endpoint HTTP 405. `setInsecure()` must not be restored for authenticated production POSTs.

## 6. Secure HTTPS and credentials
- Render TLS leaf certificate was inspected on the Raspberry Pi using `openssl s_client`, issuer **Google Trust Services WE1**; on Nov 2026 it had a validity window Sep 21–Dec 20, 2026. Leaf renewal is expected, so never pin the short-lived leaf.
- Downloaded **Google Trust Services Root R4** from `https://pki.goog/repo/certs/gtsr4.pem`; public root certificate valid through 2036. Pi `/tmp/gtsr4.pem` transferred by SCP to Windows and copied into Arduino sketch folder.
- `root_ca.h` contains `static const char ROOT_CA[] = R"EOF( ...PEM... )EOF";`, with `#pragma once`.
- Secure sketch includes `#include "root_ca.h"`, `#include <time.h>`, `NetworkClientSecure client; client.setCACert(ROOT_CA);`.
- After PPP: `configTime(0,0,"pool.ntp.org","time.google.com")`; poll `time(nullptr)` until a plausible timestamp (historical threshold `1700000000`) for max ~30 seconds. NTP succeeded in actual tests.
- **AUTHENTICATION:** Python gateway and Arduino use HTTP header `X-Gateway-Key`; `GATEWAY_API_KEY` is configured in Raspberry Pi `/etc/motorpool-gateway.env` and the matching secret is configured on Render for Laravel authentication. The Arduino constant is `GATEWAY_KEY`. Never copy real value to this file or Codex chats.
- Real gateway key was exposed in past chats. Security recommendation is to rotate across Render, Pi and all clients, but rotation is separate from preserving and debugging functionality. Do not expose any key values.

## 7. Backend GPS API contract and data shape
- Existing ingestion endpoint: `POST /api/gps/location`
- Headers from working Pi gateway and ESP32:
  ```http
  X-Gateway-Key: [SECRET — DO NOT LOG OR COMMIT]
  Accept: application/json
  Content-Type: application/json
  ```
- JSON payload sent successfully:
  ```json
  {
    "device_id": "VEHICLE-01",
    "latitude": 10.589795,
    "longitude": 123.476213,
    "satellites": 12
  }
  ```
- Expected success from demonstrated Laravel controller: **HTTP 201**, JSON `{"message":"GPS location saved successfully.","location":{...}}`.
- Historical failure cases: HTTP 401/403 auth, 404 wrong device/route, 422 input validation; negative client `-11` is read timeout and **does not establish that database write failed**.
- Existing authenticated retrieval endpoints seen in project review:
  - `GET /api/gps/vehicles/{vehicle_id}/latest`
  - `GET /api/gps/vehicles/{vehicle_id}/history`
  Inspect `routes/api.php`, controller, guards/token and real response schema before implementation.
- The user has a registered `VEHICLE-01`, **device registry ID 3**, assigned **vehicle ID 7**, Toyota Hiace, plate ABC 1234 in past UI screenshot.
- Supabase PostgreSQL table `public.gps_locations` contains `device_registry_id`, `vehicle_id`, lat/lon, satellites and timestamps; Table Editor independently verified GPS records.
- The Laravel GPS controller was reported to update `last_seen` and `is_online` on GPS inserts. No verified process for transitioning online state back to offline based on stale timestamps; investigate before making live-online promises.

## 8. Raspberry Pi LoRa gateway
- Raspberry Pi 4, Linux user `admin`; local hostname `cpsu-motorpool-pi.local` in past SSH; past LAN IP `192.168.254.193` is not stable.
- Connect via Windows PowerShell: `ssh admin@cpsu-motorpool-pi.local` (requires user credentials; never place in notes).
- Gateway Python source: `/home/admin/motorpool-gateway/raspberry_pi_gateway.py`.
- systemd service: `/etc/systemd/system/motorpool-gateway.service`.
- environment file: `/etc/motorpool-gateway.env` with secret (DO NOT print it or commit it).
- LoRa packet parse shape: `VEHICLE-01,LAT:<latitude>,LON:<longitude>,SAT:<count>`.
- Python uses `requests.Session().post(API_URL, json=data, headers=HEADERS, timeout=(10,60))`, with `X-Gateway-Key`.
- `journalctl -u motorpool-gateway` / systemd troubleshooting were used. Raspberry Pi serial at `/dev/ttyUSB0`, 115200 baud, captured gateway packets.
- Historical records show **Nov 14** a valid `VEHICLE-01` LoRa packet received by the gateway and saved, with RSSI/SNR logging; **Nov 16** further valid GPS packets were parsed and saved, invalid serial chatter ignored. Thus past high-level handover statement that vehicle→Pi reception was pending became outdated by these later successes.
- Raspberry Pi gateway-to-cloud operation is separate from direct ESP32 LTE-to-cloud POST; both were tested but production coexistence, two-vehicle scenarios and deduplication remain to be proven.

## 9. Frontend Flutter UI and map status (reviewed before Codex takeover)
- Web app is Flutter/Dart with existing admin login, Device Registry, vehicle management, trip-related features, driver assignments and map UI. Preserve current visuals and flows.
- Earlier source review located a `Map.dart`, an `active_vehicles_map.dart` / `ActiveVehiclesMap`, and sample `activeVehicles`. Actual paths/identifiers need confirmation after checkout. The map was rendering **three hardcoded sample vehicles**, rather than live `gps_locations` API data. Thus live location markers are NOT verified, even though backend saves GPS rows.
- Device Registry does fetch `/devices` from backend, and displays `Last Seen` and `Online/Offline`. Screenshot showed ISO/UTC-style raw strings (e.g. `2026-11-17T17:20:48.000...`), which could be displayed in Philippine time with formatting as a later UI improvement.
- `last_seen` was seen updated around the time of GPS tests; alone it does not prove a particular POST created a record. Database row plus HTTP 201 does prove the successful Nov 18 test.
- Flutter should retrieve GPS through existing authenticated Laravel API, not directly embed Supabase service credentials or read database from client.
- Improve state handling: no location yet, offline/stale device, network error, loading, authenticated request failure, location refresh and map marker interactions. Keep existing map design and architecture.

## 10. Detailed dated activity timeline

### Earlier phases — dates not securely recorded in available history
- Created Flutter admin and driver applications, Laravel/Sanctum backend, deployed Flutter web on Vercel and backend on Render, provisioned Supabase PostgreSQL, registered vehicle and device, and exercised UI buttons. Exact creation dates and branch commits cannot be recovered reliably from available notes.
- Assembled Heltec GPS + microSD + LoRa firmware, stored GPS locally, tested 915 MHz LoRa send/receive, planned Pi gateway and LTE failover. Some testing was inconsistent due to SD/GPS startup conditions.
- Established Raspberry Pi headless SSH and network connectivity, created Python GPS gateway and systemd service.
- Investigated Windows PHP/Composer CA trust, OneDrive write permissions and Laravel dependency setup. Exact full date-per-command log not retained.

### November 10, 2026 — development workstation / backend environment
- Composer identified as version **2.11.2** on Nov 10; standalone PHP 8.3.33 and Windows CA bundle were part of the troubleshooting period.
- Solved Composer TLS trust by exporting Windows roots to PEM and setting PHP INI paths; moved Laravel backend out of OneDrive to writable `C:\cpsu-motorpool-backend-main`; `composer install` finished with 121 installs. Dates for each substep are not individually verified.
- Goal was to integrate partner's backend changes and resume hardware LoRa synchronization, not rebuild backend architecture.

### November 13, 2026 — consolidated hardware handover and scope
- User restated the mandatory continuation rule and provided stable repo URLs / existing system context.
- Hardware handover described Heltec GPS, SD, LoRa at 915 MHz, Raspberry Pi LoRa gateway, LTE option, Laravel/Render/Supabase web platform, eventual two-vehicle system.
- Earlier pending items included Pi packet ingress, modem signal-level / power uncertainty, battery integration, offline sync and dashboard map. Later tests in this same history resolved several of those items.

### November 14, 2026 — Raspberry Pi gateway LoRa evidence
- Gateway service started, serial interface `/dev/ttyUSB0` at 115200, accepted a valid `VEHICLE-01` packet, recorded LoRa RSSI/SNR and saved GPS through Laravel; skipped invalid serial lines. Evidence from prior gateway log files.

### November 16, 2026 — repeated GPS gateway success
- Logs showed valid `VEHICLE-01` packets parsed and saved to backend with coordinates, satellites, timestamps and database IDs. This proved Pi LoRa gateway ingestion for tested packets.

### November 13–17, 2026 — direct HAISEN LTE integration (exact substep dates not fully documented)
- Discovered carrier's `3.3 V TTL (Default)` UART statement, avoided unnecessary converter purchases.
- GPIO34 RX tests failed; GPIO22→GPIO13 loopback succeeded; connected Heltec GPIO22/GPIO13 to modem UTX/URX and common ground, with both boards independently USB-powered.
- Validated `AT`, SIM ready, cellular signal `AT+CSQ` 24, registration/attachment, configured TNT APN, PPP data mode and assigned a carrier IP.
- TLS smoke tests used temporary insecure client only to establish connectivity; GET example.com HTTP 200, Render homepage HTTP 200, GPS endpoint HTTP 405.
- Constructed Arduino `.ino` without `ArduinoJson` because `ArduinoJson.h` was missing; used `snprintf` for JSON.
- Recovered recorded GPS sample from microSD, verified device ID `VEHICLE-01` (not `VEHICLE-001`).
- Created `root_ca.h` using Google Trust Services Root R4, added SNTP time sync and secure certificate verification. Fixed odd sketch folder naming and investigated duplicate-definition compile failure caused by duplicate sketch compilation.

### November 18, 2026 — secure HTTPS GET and successful authenticated POST (verified with logs)
**At 00:55 PHT:**
- LTE connected, time synchronized (about 17s), IP `10.191.118.93`, HTTPS GET GPS endpoint returned `HTTP -11 read Timeout` at 00:55:55.

**At 01:00 PHT:**
- Same secure GET test retried with larger timeout `https.setTimeout(90000)`, LTE and clock synced, returned **HTTP 405** at **01:00:38** and printed `SUCCESS! Secure HTTPS reached the GPS API.` This validates CA-backed TLS connectivity and expected rejection of GET to POST-only route.

**At 01:19–01:20 PHT:**
- Switched to authenticated POST, added `X-Gateway-Key`, used same secure CA, clock, TLS and `VEHICLE-01` recorded coordinates.
- Request started at **01:20:01**, returned **HTTP -11 read Timeout** at **01:20:28**, despite `https.setTimeout(90000)` being configured in sketch. Do not infer timeout always equals specified maximum; distinguish stage-specific networking delays.
- Render screenshot showed service boot logs with PHP-FPM and Nginx starting around 17:20:40 UTC; possible cold-start/restart but **not proven as cause**.
- Device Registry screenshot showed `last_seen` near `2026-11-17T17:20:48Z`; Supabase first table screenshot showed **3,176** GPS rows and matching recent coordinates. This supports a write near the test but alone does not prove every timed-out request's exact fate.

**At 01:40–01:41 PHT — decisive success:**
- ESP32 starts and connects LTE, time synced, private IP `10.191.118.93`.
- POST started ~01:40:38, duration **2919 ms**, returned **HTTP 201** at **01:40:41**.
- Server response: `{"message":"GPS location saved successfully.","location":{"device_registry_id":3,"vehicle_id":7,"latitude":10.589795,"longitude":123.476213,"satellites":12,"recorded_at":"2026-11-17T17:41:01.000000Z","updated_at":"2026-11-17T17:41:01.000000Z","created_at":"2026-11-17T17:41:01.000000Z","id":3177}}`.
- `2026-11-17T17:41:01Z` = **2026-11-18 01:41:01 Philippine time**. Clock differences between host Serial Monitor and backend timestamps can explain ~20s disparity; do not invent sync cause.
- Supabase Table Editor screenshot independently showed row **3177**, vehicle 7, registry 3, matching exact coordinates/satellites. **Verified end-to-end for fixed recorded test coordinates.**

**Later November 18 PHT:**
- User asked to review UI code and discovered that map still showed sample/hardcoded vehicle markers while Device Registry was API-driven.
- User tried Render Shell, could not access it; verified GPS data directly in Supabase Table Editor instead.
- User planned to clone Flutter current frontend repo into VS Code for live map integration; briefly considered a backup branch, then decided to clone current repo.
- User now wants to install **OpenAI Codex IDE extension** and provide all prior detailed project context so Codex continues correctly.

## 11. Current feature status: verified versus pending

| Component | State | Evidence / caveat |
|---|---|---|
| Heltec→HAISEN UART | VERIFIED | AT replies + PPP mobile data |
| TNT SIM LTE PPP | VERIFIED | Attached, mobile IP, HTTPS connection |
| Secure CA-validated TLS via PPP | VERIFIED | NTP success and HTTP 405 GET with `setCACert` |
| Authenticated fixed-sample GPS POST | VERIFIED | HTTP 201, JSON, 2.919 s |
| Supabase GPS insert | VERIFIED | Row #3177 exact values |
| Pi gateway LoRa packets and backend insert | VERIFIED in past logs | Nov 14/16 gateway logs |
| Device Registry retrieves devices | VERIFIED in past review | Uses `/devices` |
| Live map uses latest backend GPS | PENDING | Prior map source uses sample positions |
| Continuous realtime GPS hardware feed | PENDING | Nov 18 LTE POST is from old SD-recorded sample |
| Complete SD+LoRa+LTE co-wiring | PENDING | GPIO13 conflicts with historical SD CS |
| Offline sync/dedupe/retries | PENDING | A timed-out request may have written row |
| Online/offline freshness rule | PENDING | `is_online` may become stale |
| Two concurrent vehicles end-to-end | PENDING | One demonstrated device |
| Battery/field power | PENDING | USB-powered working setup is not portable final design |
| Old admin Heltec antenna fix | PENDING | Damaged pigtail |

## 12. Immediate next task: Flutter live GPS map integration

**User's latest decision:** Clone current `main` of web UI repository; do not switch to older backup branch unless asked. Work in VS Code with Codex.

### First, audit actual current code
1. `git status`, `git branch --show-current`, `git remote -v`; ensure uncommitted work preserved; create non-destructive working branch if changes are authorized.
2. Open `pubspec.yaml`, examine Flutter plugin versions and build scripts; `flutter --version`, `flutter pub get` if appropriate; don't run deployment.
3. Locate `Map.dart`, `active_vehicles_map.dart`, `activeVehicles` constant/sample source, map marker/model widgets; verify any assumptions from earlier source inspection.
4. Locate `DeviceRegistry.dart`, existing API service/base URL, authentication/token handling, vehicle and driver models, and `vehicle_id` relationship.
5. If backend checkout available, review `routes/api.php`, controller handling `GET /api/gps/vehicles/{vehicle_id}/latest`, response JSON and Sanctum middleware; do not guess whether data are nested in a `location` object or top level.
6. Plan minimal refactor: maintain UI look, replace hardcoded sample marker positions with authenticated API latest location for registered vehicles; handle loading/empty/offline/error, coordinate validation, and periodic/manual refresh without unnecessary requests.
7. Consider user-visible timestamp formatting to PHT; keep server timestamps as UTC values and transform for display, not on storage.
8. Run `flutter analyze`, targeted tests and a local browser smoke test; compare map marker to Supabase row #3177 (`10.589795`, `123.476213`), but avoid assuming that's current as later GPS rows can arrive.

### Avoid common traps
- **Do not put Supabase service role key into Flutter client**; Flutter should call Laravel's authenticated API.
- **Do not turn `setInsecure()` back on**; successful TLS proof uses GTS R4 and SNTP.
- **Do not force GPS POST retries** while server may have already persisted a request; consider request IDs/idempotency for future reliable tracking.
- **Do not interpret `is_online=true` as recent connectivity** without a real freshness window.
- **Do not confuse data storage success with live GNSS sensor success.**
- **Do not assume each conversation described a separate development day.** Where source dates are unclear, preserve the range instead of fabricating a daily log.

## 13. Helpful troubleshooting commands (never print secrets)

```powershell
# Windows Flutter clone (if no same-name folder already exists)
cd C:\
git clone https://github.com/raffysolon/cpsumotorpool-web-app-backup-file.git
cd C:\cpsumotorpool-web-app-backup-file
code .
git status
git branch --show-current
flutter --version
```

```bash
# Raspberry Pi: read service status / recent logs; avoid dumping secret environment files
sudo systemctl status motorpool-gateway --no-pager
sudo journalctl -u motorpool-gateway -n 100 --no-pager
```

Arduino sketch files in original folder: `C:\Arduino\CPSU_LTE_GPS_POST_TEST.ino\CPSU_LTE_GPS_POST_TEST.ino.ino`, `root_ca.h`, `gtsr4.pem`. Check actual location via IDE instead of renaming blindly.

## 14. Ready-to-paste first prompt for Codex

> You are joining my existing CPSU Motorpool Tracker project. Read `AGENTS.md` and `CPSU_MOTORPOOL_PROJECT_HISTORY.md` carefully before writing code. Do NOT restart or redesign any working part. My Heltec/HAISEN TNT LTE GPS POST to Laravel on Render and Supabase already succeeded with HTTP 201 and GPS row #3177 for vehicle ID 7 / device `VEHICLE-01`. I am now working in the current Flutter web app repo. I need the Map page to show real latest GPS coordinates from the EXISTING authenticated Laravel API instead of hardcoded `activeVehicles` sample markers, with the existing UI unchanged. Inspect the actual repo and auth conventions, identify relevant files and exact API response structure, report what is verified versus assumed, propose a short incremental plan, and wait for my approval before editing any files. Never print or commit private gateway keys or tokens. Do one focused change at a time and run appropriate checks.
