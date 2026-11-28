# CPSU MotorPool changes — November 28, 2026

Team handoff for the admin web app, driver web app, driver mobile app, Laravel backend, and tracking hardware. Dates follow Philippine time.

## Follow-up changes

- The driver web and mobile trip request forms no longer ask for estimated hours. The driver enters the departure schedule and can add a return departure if known. The backend still allows one pending request and one active trip per driver.
- For overlap checks before a trip starts, requests without a scheduled end use a four-hour booking window. A later scheduled return can extend that window to one hour after its planned departure.
- For live outbound ETA, the backend uses remaining road distance and speed estimated from recent GPS fixes. It uses the routing service's travel time when suitable speed readings are unavailable. The admin map displays the GPS-derived speed when the estimate uses it.
- [Backend ETA follow-up](https://github.com/raffysolon/cpsu-motorpool-backend/commit/6c285cf32f2e52e61d37a8f7627ee96388ae8bda) and [driver mobile form follow-up](https://github.com/raffysolon/cpsu-motorpool-driver-app/commit/3d8b75e55bda6d240f4e50ef4a8fa13d5ad7ed16). The web form and ETA panel changes are in the web revision containing this handoff.
- Verification passed before the push with 129 backend tests, 7 mobile tests, and 4 focused web tests. Live ETA still needs a configured `OSRM_BASE_URL`, a destination pin, and recent GPS data.

## Review the initial feature revisions

The comparison links show the main feature rollout before the follow-up changes above.

| Repository | Verified head | Feature comparison |
|---|---|---|
| Admin and driver web | [`8c40114`](https://github.com/raffysolon/cpsumotorpool-web-app-backup-file/commit/8c401140866a5b48f971b0916177ffb50ae98da3) | [`b3337e1...8c40114`](https://github.com/raffysolon/cpsumotorpool-web-app-backup-file/compare/b3337e1...8c40114) |
| Laravel backend | [`2f7df48`](https://github.com/raffysolon/cpsu-motorpool-backend/commit/2f7df4814cef523f769f296d06df5c2c17eb550e) | [`5f7e16c...2f7df48`](https://github.com/raffysolon/cpsu-motorpool-backend/compare/5f7e16c...2f7df48) |
| Driver mobile app | [`9efd726`](https://github.com/raffysolon/cpsu-motorpool-driver-app/commit/9efd7263aefc22befb58274056184fecc122f71b) | [`53e25d9...9efd726`](https://github.com/raffysolon/cpsu-motorpool-driver-app/compare/53e25d9...9efd726) |

### Earlier changes on November 28

| Repository | Earlier changes published today | Reference commit |
|---|---|---|
| Admin and driver web | Destination maps and forms, Sync Logs, trip history, notification polling and audio, and rebuilt Flutter web release | [b3337e1](https://github.com/raffysolon/cpsumotorpool-web-app-backup-file/commit/b3337e1) |
| Laravel backend | Completed-trip GPS route endpoint | [64331d8](https://github.com/raffysolon/cpsu-motorpool-backend/commit/64331d8) |
| Driver mobile app | Saved destination chooser and notification sounds | [53e25d9](https://github.com/raffysolon/cpsu-motorpool-driver-app/commit/53e25d9) |

## Saved destinations and trip requests

- **Admin** can create and edit common destinations before a trip exists. Open **Map → Saved destinations**, enter a name, and pin the location. The map includes zoom controls and supports an optional satellite layer when a MapTiler browser key is configured.
- **Driver web and mobile** show **Choose saved destination** beside the destination input. Each opening fetches the latest list, including pins added after the form opened. Drivers can also type a destination. The chooser distinguishes loading, an empty list, and a failed request.
- **Backend** copies the saved coordinates into the trip when the submitted name matches. For example, typing `CPSU SAN CARLOS` matches `CPSU San Carlos` when the case-insensitive match is unique. Typing only `San Carlos` remains a free-text destination unless that name was also saved. An admin can set a pin later from the trip request details.
- The destination-pin dialog now keeps the map controller alive through its closing animation and blocks Back while saving. This addresses the reported Flutter disposed-controller error.
- Two Laravel migrations add nullable coordinates to trips and create the saved destinations table. Existing trips may have empty coordinates. Authenticated users can list destinations. Creating and editing saved places requires admin access.

## Notifications and driver actions

- On admin web, the app checks the inbox every 15 seconds while the admin shell is active. Closing the mobile drawer no longer removes the notification timer.
- Web audio uses a page click to enable playback where the browser requires a user gesture. Ordinary new trip events can play a sound. Sound defaults to enabled on web and mobile and respects each user's saved mute, volume, and priority settings.
- On driver web, **Start Trip** uses green when available and light green while disabled. **View Trip Ticket** in My Trips uses a green background and white text.
- A driver can have one pending request at a time. An approved future trip still allows a new request if the schedules do not overlap. A driver must complete an active trip before starting another.
- The backend uses the scheduled end when one exists. When none exists, it computes the booking window automatically from departure and any scheduled return.

## Sync Logs, trip history, and printing

- Admin Sync Logs opens with a vehicle summary showing the registered vehicle, campus, currently assigned driver, and last upload. Campus and driver come from Assignments. **View Details** opens the vehicle's records. The layout gives the data and action button more room on smaller screens.
- The updated Pi gateway reports queued records, connection or upload delays, records needing review, and confirmed uploads. Sync Logs shows the last reported state and time, including before the first GPS upload. A total Pi internet outage leaves the last report visible until the Pi reconnects.
- Completed admin-created trip tickets move into **Trip History** and carry a **Created by Admin** indicator.
- **Trip History → View Details** shows the actual GPS route, including points uploaded after completion. It separates outbound and return legs and breaks the line across gaps longer than two minutes.
- The **Trip Activity Timeline** records people and timestamps for trip creation, admin decisions, outbound and return travel, and completion. Older trips show available timestamps and identify missing actors or decision times.
- The backend trip ticket PDF uses **12 mm left and right margins**, 8 mm at the top, and 15 mm at the bottom on **8.5 × 13 inch** long bond paper.

## Hardware and ETA

The vehicle attempts an LTE heartbeat about every 60 seconds when connectivity, time, and credentials are available. GPS capture starts after a valid fix and time. LoRa recovery uses the admin-side Pi to forward buffered GPS records. The vehicle advances to its next pending record after cloud confirmation, which limits backlog transfer while the Pi is offline. The gateway with Sync Logs reporting is in the web repository's verified commit. [Updated gateway and setup instructions](https://github.com/raffysolon/cpsumotorpool-web-app-backup-file/tree/8c40114/hardware/gateway)

The admin map shows heartbeat receipt time and the latest GPS capture time separately. The **Tracker status** list includes devices without a GPS fix. Select an active vehicle marker to view its outbound ETA or set a missing destination pin.

Road ETA requires `OSRM_BASE_URL` in the Laravel environment and a routing service that covers the trip area. Return-leg ETA and firmware-level recording controlled by the driver's Start Trip action are still pending.

Run the backend migrations before releasing the updated web and mobile apps. The Render deployment script runs `php artisan migrate --force`. Confirm that migrations `000003`, `000004`, and `000005` succeeded. Install the updated [gateway script](hardware/gateway/gateway.py) on the Raspberry Pi to enable transfer reports. Keep the Pi's existing SQLite queue and gateway credential during the update.

## Code entry points for review

| Feature | Backend | Web, mobile, or gateway |
|---|---|---|
| Recorded route | `GpsLocationController.php` → `recordedRoute`, `GET /api/trips/{trip}/recorded-route` | `lib/pages/Admin/pages/TripHistory.dart`, `lib/widgets/recorded_trip_route.dart` |
| Outbound ETA | `GpsLocationController.php` → `tripEta`, `GET /api/trips/{trip}/eta` | `lib/widgets/active_vehicles_map.dart`, `lib/widgets/active_trip_eta.dart` |
| Booking limits | `TripController.php` → request, approval, schedule edit, and start guards, with `scheduled_end_at` on trips | Web `lib/pages/Driver/pages/CreateTripTicket.dart`, mobile `lib/pages/create_trip_ticket.dart` |
| Separate heartbeat and GPS times | Device Registry provides `last_heartbeat_received_at` and the latest GPS endpoint provides `recorded_at` | `lib/services/gps_service.dart`, `lib/widgets/active_vehicles_map.dart` |
| Gateway transfer status | `GatewaySyncStatusController.php`, `POST /api/gps/sync-status`, and `GET /api/gps/sync-logs?summary=1` | `hardware/gateway/gateway.py`, `lib/services/gps_sync_service.dart`, `lib/pages/Admin/pages/SnycLogs.dart` |
| Trip activity | `TripActivity.php`, lifecycle writes in `TripController.php`, and `GET /api/trips/{trip}/activity` | `lib/widgets/trip_activity_timeline.dart`, `lib/pages/Admin/pages/TripHistory.dart` |

## Review scenarios

1. **Booking.** Approve tomorrow's trip, then submit a non-overlapping trip for today. Try a second pending request, a trip during the overnight return window, and another start while yesterday's trip is still active.
2. **Route and timeline.** Complete a round trip. Upload GPS points captured during the trip after it closes and check that the route uses capture time, skips another vehicle's points, and keeps the two legs separate. Check that the timeline records the acting user and labels missing legacy details.
3. **ETA and tracker status.** Submit a trip from web and mobile without entering hours. Start the trip with a custom destination and no saved pin. Set the pin from the admin map and check the ETA with a configured routing service and recent GPS fixes. Stop GPS updates while keeping heartbeat active and check the two timestamps separately.
4. **Gateway recovery.** With test data, disconnect the Pi from the internet while it receives GPS records. Confirm the records stay queued locally, then restore the connection and verify that the backend's acknowledgment is required before **Uploaded** appears. The status describes the Pi queue. The number of records still on the vehicle SD card remains unknown.

Ask the reviewer to flag reproducible defects, affected files, deployment prerequisites, and behaviors that still need physical or production verification. Use a local test database and synthetic GPS points for review.

## Verification and outstanding checks

| Check | Result |
|---|---|
| Earlier full-suite run | 124 web, 121 backend, and 7 mobile tests passed before the final UI and polling edits. |
| Focused follow-up tests | The map dialog regression passed. Saved destination tests passed with 15 assertions, including a driver submitting a differently capitalized saved name and a custom destination. The admin shell and sound run passed all 11 tests. |
| Latest feature tests | The full Laravel suite passed 129 tests. Focused Flutter tests passed for the timeline, Sync Logs, tracker status, and ETA. The Pi gateway passed 4 local Python tests. The web release build completed with the existing WebAssembly compatibility warning. |
| Production | Render migration completion, Vercel production behavior, and the updated mobile and Pi installations still need confirmation. |
| Physical hardware | Flash and bench-test both Heltec boards. Check repeated SD writes beyond the previously observed six records, a fresh GPS timestamp, LTE heartbeat, and LoRa recovery without duplicate database rows. |

For a live software check, save a campus in **Admin → Map**, open the driver chooser on web and phone, submit a request, and check the pin and notification on the admin side. Then approve the trip and check the driver's notification. This flow can be tested before the hardware is ready.
