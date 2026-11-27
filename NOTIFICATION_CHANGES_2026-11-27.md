# Notification follow-up

- Admin and driver web dashboards now show an in-app banner for unread notifications at first load and newly received notifications afterward. Repeated polling does not repeat the same alert.
- Admin Trip Requests and Scheduled & Active tabs show unread notification counts based on the linked trip's current status. Marking a notification read or deleting it removes it from these counts after refresh.
- Web inbox dialogs fetch current notifications when opened, refresh every 15 seconds, and show a retry error instead of reporting an empty inbox when the API fails.
- Web dashboards derive the unread count from the same inbox response rather than making a separate unread-count request. The driver dashboard updates changed content even when the item count stays the same.
- Driver mobile dashboard polls every 15 seconds and displays new-update banners. Its inbox now refreshes automatically while the app is resumed.
- Existing read/delete actions and sound preferences remain. Sound is optional; visible banners do not depend on sound being enabled.

## Deployment prerequisite

The previously pushed backend commit `ba25759` fixes the PostgreSQL migration that blocked the notification `priority` and `dismissed_at` columns. Deploy that backend fix and verify all migrations finish before testing production notifications. No new backend changes were required for this UI follow-up.

These are in-app polling notifications, not operating-system push notifications when the app is closed. Driver banners run from the dashboard; the mobile inbox refreshes while open. Hardware sync work is deferred until the latest Raspberry Pi script is available.

## Verification

Backend notification/trip status tests: 22 passed, 125 assertions (isolated SQLite). Web notification/navigation tests: 12 passed. Sync Logs tests: 3 passed. Mobile suite: 7 passed. The subsequent mobile bottom-spacing adjustment passed analysis without errors. Live delivery still needs a deployed backend and rebuilt clients.

## Sync Logs and mobile spacing

Sync Logs now groups uploaded records by vehicle within each results page. GPS coordinates, capture/receipt times and upload sources are shown in expandable details. Missing campus/driver names display Not available; no current assignment is guessed for historical records. Pending SD counts and live transfer completion remain unavailable until gateway integration. The driver Notifications list includes extra bottom padding above the phone navigation area.
