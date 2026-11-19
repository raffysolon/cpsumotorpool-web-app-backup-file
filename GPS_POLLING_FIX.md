# GPS polling and HTTP 429 fix

Changes are local only; nothing has been committed or deployed.

## Cause and scope

The backend shares a 60/minute per-user API limiter across GPS reads, devices,
trips and notifications. One vehicle on one active Map uses approximately 25
requests/minute (12 GPS + 1 registry page + 4 trip counts + 8 notifications),
excluding initial loads and user actions. Covered routes previously continued
polling, and notification refreshes could overlap. Other tabs using the same
account also share the backend budget. Exact production request counts have not
been captured.

The backend CORS configuration did not expose Retry-After to Flutter web.
The previous GPS cooldown did not pause sidebar requests and discarded retry
metadata on registry errors.

## Changes

- `ApiReads` shares concurrent GETs and a per-origin/per-token cooldown across
  GPS, devices, trips, notifications, drivers and vehicles. It preserves the
  response header delay (seconds or HTTP date), with JSON/default fallbacks.
  Successful responses are not cached by this helper.
- Covered Map and admin trip routes stop polling; Map also pauses while hidden.
  Sidebar polling stops on covered routes, removes its actual lifecycle observer
  on disposal, and guards initial and periodic count refreshes against overlap.
- Notification refreshes share one in-flight operation.
- Existing GPS caches and last-known-position retention remain. The prior local
  freshness fix keeps UTC normalization, a 60-second freshness window and a
  five-second future tolerance. Failed refreshes never reset the record's age.
- The separate backend checkout `.local-backend-review` exposes Retry-After,
  Date and rate-limit headers in `config/cors.php`, with regression tests.
  This checkout is ignored by the Flutter repository; review its changes there.

No dedicated GPS limiter is added for the current single-vehicle workload.
Authentication, role checks, the general 60/minute limit and gateway upload
throttling are unchanged. Larger fleets or many simultaneous tabs may need a
separately budgeted authenticated latest-location endpoint after measuring load.

## Verification

Frontend:
```
flutter test test/api_reads_test.dart test/gps_service_test.dart test/active_vehicles_map_test.dart test/admin_layout_test.dart test/trips_navigation_test.dart
```

Backend, from `.local-backend-review`:
```
php vendor/phpunit/phpunit/phpunit tests/Feature/GpsReadRateLimitTest.php
```
Backend tests use the testing environment and array cache, not Supabase.

Before deployment, run the frontend locally against an approved test backend.
Observe Network for a minute with one vehicle, navigate from dashboard to Map,
and confirm covered pages stop polling. Hide the tab and confirm periodic Map
and sidebar requests pause. Test 429 using a mock/test backend: reads should stop
until Retry-After expires, the last marker should remain, and a record older
than 60 seconds should turn gray. Resume valid uploads and confirm green returns.
Do not deliberately exhaust the production API for testing.

The backend CORS change must be included in a later backend deployment for the
browser to read retry headers. Until then, the frontend uses the JSON retry_after
value or a 60-second fallback. Cross-tab cooldown coordination is not implemented;
each tab respects its own 429 response.


## Completed trip monitoring and live-data UI

- All registered vehicles with GPS coordinates remain on the map, even without
  a trip. A fresh location with a confirmed null trip assignment shows a question
  mark. Scheduled/active trips keep the vehicle icon. Stale GPS remains gray.
- Missing trip context from an older backend is displayed as unavailable, never
  inferred to mean no trip. A future approved/scheduled trip counts as assigned;
  an active trip takes priority, otherwise the earliest scheduled trip is shown.
- Actual departure means the assigned driver presses Start Trip, not device
  power-on or the first GPS packet. GPS uploads and firmware are unchanged.
- After five minutes, admins receive one overdue alert per trip/schedule/admin.
  The database event_key uniqueness and a trip row lock prevent duplicate alerts.
  Read notifications are not recreated by polling. Rescheduling creates a new
  schedule identity after its new grace period.
- Starting late records actual departure and includes whole elapsed late minutes
  in the API, admin notification and map tooltip. The grace period is not
  subtracted: 09:12 for a 09:00 departure is 12 minutes late. Partial minutes are
  rounded down; the notification says less than one minute where appropriate.
- Sync Logs now shows paginated persisted GPS rows, not mock device records.
  It refreshes every 15 seconds while visible, keeps records on transient errors,
  clears them on lost access, and has explicit loading, empty and error states.
- PDF reads retain their original 150-second timeout; routine reads use 30 seconds.

### UI data audit

The six hardcoded GPS-001 through GPS-006 rows were the actual sample fleet
records found in lib and have been removed. Maps load registered devices and GPS
from the backend; trip lists, vehicles, drivers, assignments and notifications
already use backend services. The initial map camera center is a geographic
fallback, not a sample vehicle. Form hints, date/month lists, loading skeletons,
branding and test fixtures are not production fleet records and remain.
A stale MyTrips comment incorrectly described its API-populated view model as
sample data; the comment is corrected. No database records or seeds were deleted.
Existing real API page data is not the same as a continuous live feed: Map and
Sync Logs poll, while some other pages refresh on load or user action.

## Deployment plan ? NOT executed

There are two independent working trees. The Laravel changes live inside the
ignored .local-backend-review checkout. They must be reviewed and released from
that backend repository, not accidentally included in a Flutter commit.

1. Review both diffs, including the new migration and all new tests. Test against
   a staging database first. Preserve existing firmware, gateway keys, auth/role
   middleware, rate limits and database connection settings.
2. Review historical approved/scheduled trips that never started. The monitor
   intentionally includes them and will create one overdue alert for each current
   schedule. Do not delete or change records automatically to suppress alerts.
3. In the approved backend release, apply
   `php artisan migrate --force` including
   `2026_11_18_000001_add_event_key_to_notifications.php` before serving the new
   notification code. This adds a nullable unique event_key column; it does not
   delete existing notifications. Do not enable the new code without the column.
4. Refresh any existing configuration/route caches through the normal deployment
   process so CORS exposes Retry-After and the new sync route is registered.
5. Run Laravel's scheduler in the backend environment: a persistent
   `php artisan schedule:work`, or invoke `php artisan schedule:run` every minute
   using the hosting scheduler. Use the same release and database configuration.
   No scheduler was started by Codex. Without a running scheduler, checks happen
   only during admin notification reads. With it, detection is within the next
   minute after the grace period; the UI then refreshes notifications every 15s.
6. Deploy the Flutter build only after the backend API is verified. Verify the
   retry header is exposed, real sync rows load and the marker shows the correct
   trip state. Old backends show trip context unavailable and a Sync Logs error.
7. Verify on staging: a 09:00 trip has no overdue alert at 09:04:59, gets one at
   the first check from 09:05 onward, and shows 12 minutes late after Start Trip
   at 09:12. Repeated polls must not duplicate notifications. Also test a fresh
   tracker with no trip, a stale tracker, a hidden tab, pagination and a 429.

Rollback: stop the new scheduled command and restore the prior application
releases. Leaving the nullable event_key column in place is compatible with old
code. Do not run a broad migration rollback against unrelated production data.

## Final verification commands

```
flutter test --no-pub
flutter analyze --no-pub
flutter build web --no-pub --output build/review-web
```

From the backend checkout:
```
php vendor/phpunit/phpunit/phpunit tests/Feature/GpsReadRateLimitTest.php tests/Feature/TripDepartureMonitorTest.php
```

The earlier full backend baseline comparison found the same 15 failing/erroring
legacy tests on both original and modified code (missing local app key/GD and
existing password, route/response expectations). These are not covered up or
changed as part of GPS work. Focused feature tests are the acceptance gate for
this change; production/browser verification still requires an approved release.


## Validation results (2026-11-19)

- Full Flutter suite: 50 tests passed, including slow PDF generation, all marker
  assignment states, UTC/PHT timestamps, cooldown expiry, covered/hidden routes,
  live Sync Logs pagination/empty/error/access-loss states and narrow layouts.
- Replaced the obsolete Flutter counter-demo smoke test with a real app check
  that an unauthenticated visitor reaches login without exposing fleet data.
- Fixed the unused admin wrapper's ambiguous AppColors import. Full analysis has
  no errors; unrelated existing warnings/deprecation/style notices remain.
- Focused Laravel suite: 9 tests passed, 108 assertions, including five-minute
  grace boundaries, 12-minute lateness, rescheduling, duplicate prevention,
  protected GPS/Sync Logs reads, general throttling and exposed retry headers.
- Legacy backend suite failures reproduced on the untouched checkout are listed
  above; this change does not claim those unrelated tests are fixed.
- No commits, pushes, deployments, production migrations, or scheduler launches
  were performed. Live acceptance testing remains part of the later deployment.
- Production JavaScript web build succeeded locally at build/review-web; it was not published.
