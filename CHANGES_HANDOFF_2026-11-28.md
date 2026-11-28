# CPSU MotorPool changes — November 28, 2026

Team handoff for the admin web app, driver web app, driver mobile app, Laravel backend, and tracking hardware. Dates follow Philippine time.

## GitHub release references

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
- The driver web and mobile forms default to four hours for estimated trip duration. Drivers can adjust it for shorter trips, stops, or overnight returns. The backend uses the expected end time to check for overlaps.

## Sync Logs, trip history, and printing

- Admin Sync Logs opens with a vehicle summary showing the registered vehicle, campus, currently assigned driver, and last upload. Campus and driver come from Assignments. **View Details** opens the vehicle's records. The layout gives the data and action button more room on smaller screens.
- The updated Pi gateway reports queued records, connection or upload delays, records needing review, and confirmed uploads. Sync Logs shows the last reported state and time, including before the first GPS upload. A total Pi internet outage leaves the last report visible until the Pi reconnects.
- Completed admin-created trip tickets move into **Trip History** and carry a **Created by Admin** indicator.
- **Trip History → View Details** shows the actual GPS route, including points uploaded after completion. It separates outbound and return legs and breaks the line across gaps longer than two minutes.
- The **Trip Activity Timeline** records people and timestamps for trip creation, admin decisions, outbound and return travel, and completion. Older trips show available timestamps and identify missing actors or decision times.
- The backend trip ticket PDF uses **10 mm left and right margins**, 8 mm at the top, and 15 mm at the bottom on **8.5 × 13 inch** long bond paper.

## Hardware and ETA

The web repository also received the bench firmware and gateway files. For paired installation, use the vehicle sketch, admin receiver sketch, and Raspberry Pi gateway together. The vehicle attempts an LTE heartbeat about every 60 seconds when connectivity, time, and credentials are available. GPS capture starts after a valid fix and time. LoRa recovery uses the admin-side Pi to forward buffered GPS records. The vehicle advances to its next pending record after cloud confirmation, which limits backlog transfer while the Pi is offline. [Hardware branch and setup instructions](https://github.com/raffysolon/cpsu-motorpool-backend/tree/hardware/hardware)

The admin map shows heartbeat receipt time and the latest GPS capture time separately. The **Tracker status** list includes devices without a GPS fix. Select an active vehicle marker to view its outbound ETA or set a missing destination pin.

Road ETA requires `OSRM_BASE_URL` in the Laravel environment and a routing service that covers the trip area. Return-leg ETA and firmware-level recording controlled by the driver's Start Trip action are still pending.

Run the backend migrations before releasing the updated web and mobile apps. Install the updated [gateway script](hardware/gateway/gateway.py) on the Raspberry Pi to enable transfer reports.

## Verification and outstanding checks

| Check | Result |
|---|---|
| Earlier full-suite run | 124 web, 121 backend, and 7 mobile tests passed before the final UI and polling edits. |
| Focused follow-up tests | The map dialog regression passed. Saved destination tests passed with 15 assertions, including a driver submitting a differently capitalized saved name and a custom destination. The admin shell and sound run passed all 11 tests. |
| Latest feature tests | The full Laravel suite passed 129 tests. Focused Flutter tests passed for the timeline, Sync Logs, tracker status, and ETA. The Pi gateway passed 4 local Python tests. |
| Production | Render migration completion, Vercel production behavior, and the updated mobile and Pi installations still need confirmation. |
| Physical hardware | Flash and bench-test both Heltec boards. Check repeated SD writes beyond the previously observed six records, a fresh GPS timestamp, LTE heartbeat, and LoRa recovery without duplicate database rows. |

For a live software check, save a campus in **Admin → Map**, open the driver chooser on web and phone, submit a request, and check the pin and notification on the admin side. Then approve the trip and check the driver's notification. This flow can be tested before the hardware is ready.
