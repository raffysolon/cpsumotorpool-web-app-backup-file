# CPSU Motorpool Tracker — instructions for Codex

Read `CPSU_MOTORPOOL_PROJECT_HISTORY.md` before any work. This is a continuing BSIT/student system project, not a greenfield implementation.

## Non-negotiable collaboration rules
1. Continue from the current stopping point. **Do not restart the project, change its architecture unnecessarily, or rewrite working modules.**
2. Examine the actual checked-out files before proposing code changes. The history file is context, not a guarantee that the current branch has identical filenames or implementations.
3. Explain the change and affected files before editing. Make one small, verifiable change at a time, particularly with ESP32/LoRa/LTE hardware.
4. Keep the deployed Flutter UI design, authentication, trip management, driver app, device registry, Laravel API contracts, Raspberry Pi gateway, and database migrations intact unless the task explicitly requires changes.
5. Never hardcode, print, commit, request in chat, or expose real gateway keys, database passwords, Supabase credentials, Laravel APP_KEY, bearer tokens, or private credentials. Use redacted placeholders in all prompts, screenshots and output. The user previously exposed a gateway key in chat; recommend rotation but don't block user-requested debugging solely on that.
6. Before editing files, check `git status`, current branch, remotes, and build tooling. Never force push, reset, delete branches, or overwrite backups without explicit authorization. Propose a new working branch for GPS-map changes.
7. Do not send unauthorised writes to production Laravel/Supabase. Test POST requests create real rows and may update dashboard state. Distinguish recorded test coordinates from live GPS sensor data.
8. Report exact commands, file paths, diff summaries, tests executed and tests not executed. Do not claim completion from source inspection alone.
9. For Flutter map integration, prefer the existing authenticated Laravel GPS latest-location endpoint over direct client access to Supabase or hardcoded map coordinates. Preserve UI visuals; integrate and test incrementally.
10. Respect hardware details: Heltec WiFi LoRa 32 V2 driver node, UART TX GPIO22 / RX GPIO13 to HAISEN A7672E-FASE carrier with common GND and separately USB-powered boards. GPIO13 conflicts with earlier SD-card CS arrangement, so resolve before restoring SD and LTE on the same unit. Keep LoRa transmission off in LTE-only tests, and use a LoRa antenna when transmitting.

## Current verified stopping point (Nov 18, 2026, Asia/Manila)
- ESP32 secure LTE GPS POST succeeded, HTTP 201, measured duration 2.919 s.
- Laravel JSON replied `GPS location saved successfully`; record ID **3177**, `device_registry_id=3`, `vehicle_id=7`, latitude **10.589795**, longitude **123.476213**, satellites **12**, `recorded_at=2026-11-17T17:41:01.000000Z` (01:41:01 PHT on Nov 18).
- Supabase Table Editor independently showed saved GPS record; prior POST timed out at `HTTP -11` and apparently still wrote a record. Do not blindly retry uncertain POSTs without checking for duplicates.
- HTTPS GET using `NetworkClientSecure::setCACert(ROOT_CA)` and SNTP succeeded with HTTP **405** (expected POST-only endpoint).
- NEXT: the user is cloning the **current main** of `https://github.com/raffysolon/cpsumotorpool-web-app-backup-file` into VS Code and wants to wire real saved GPS data into the existing Flutter Map page. Inspect code before any change. The currently reviewed main used hardcoded sample `activeVehicles` instead of API-driven GPS markers; verify this on checkout.

## Entry task for Codex
1. Read the history file, inspect `git status`, project tree, Flutter version and `pubspec.yaml`.
2. Locate map components (`Map.dart`, `active_vehicles_map.dart` / ActiveVehiclesMap; locate by symbol search if paths differ), `activeVehicles` sample data, API client/base URL, login/token handling, device registry UI.
3. Inspect the backend repository if present, especially routes and GPS latest-location response schema / authentication. Don't invent response field names.
4. Summarize an incremental plan that turns the existing map into actual vehicle markers via the existing authenticated Laravel latest-location endpoint; handle errors, no-data state, loading, timestamps, and refresh gracefully.
5. **Ask for permission before editing** and then implement the first focused frontend change only; run `flutter analyze`/tests when available.
