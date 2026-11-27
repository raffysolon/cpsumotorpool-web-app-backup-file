# CPSU Motorpool — changes handoff

Date: November 26, 2026 (Asia/Manila)

## Purpose and current status

This handoff covers the fixes made after importing the friend's backend and driver app repositories, plus the web password-email notification improvement.

The identified backend failures have been fixed and the checks listed below passed locally. Changes have not been committed, pushed, or deployed by this work. Production migrations and live verification are still required. Passing local tests does not verify Render, Vercel, Gmail delivery, or physical tracker operation.

## Repositories and branches

| Local folder | Current local branch | Tracking source |
| --- | --- | --- |
| `D:\cpsumotorpoolbackend` | `friend/backend-main` | `friend/main` in `unknownthedreamer/cpsu-motorpool-backend` |
| `D:\cpsumotorpooldriverapp` | `friend/tracker-integration` | `friend/feature/tracker-integration` in `unknownthedreamer/cpsu-motorpool-driver-app` |
| `D:\cpsumotorpooladmin` | `feature/live-gps-map` | `origin/feature/live-gps-map` in `raffysolon/cpsumotorpool-web-app-backup-file` |

The backend and mobile app retain their original `origin` remotes pointing to the owner's `raffysolon` repositories. `friend` is a separate remote. Check the destination before pushing; a plain push on a friend-tracking branch is not the intended way to publish to the owner's repository.

The backend's previous `feature/tracker-integration` branch was preserved. The friend's backend was imported with a separate Git history; do not force-push or overwrite `main` just to bypass a history conflict.

Before switching the mobile app, two existing local changes were saved in a Git stash named `Backup local driver app changes before friend tracker integration 2026-11-26`. Those older changes were not automatically reapplied. Review them separately before deciding whether any should be retained.

## Backend: restored missing tracker implementation

The imported backend referenced tracker classes and database columns that were missing from its uploaded files. The initial suite reported **77 tests, 30 errors, and 1 failure**. Many failures shared the same missing dependencies.

The following files were restored from the preserved local `feature/tracker-integration` branch. They are existing implementation recovered from that branch, not a replacement architecture.

### Runtime code

- `app/Console/Commands/ProvisionTrackerCredential.php`
- `app/Enums/TrackerCallerType.php`
- `app/Http/Middleware/TrackerAuthentication.php`
- `app/Services/TrackerAvailability.php`
- `app/Services/VehicleMovementMonitor.php`

These restore tracker/gateway authentication and permissions, credential provisioning, online-status calculation, and vehicle movement monitoring used by the existing code.

### Database migrations

- `2026_11_24_000003_add_unique_device_sequence_to_gps_locations.php`
- `2026_11_24_000004_add_tracker_credentials_to_device_registry.php`
- `2026_11_24_000005_add_last_heartbeat_received_at_to_devices.php`
- `2026_11_24_000006_create_tracker_movement_states_and_notification_priority.php`
- `2026_11_24_000007_add_movement_gps_query_index.php`

All are under `database/migrations/`. They restore the device-sequence constraint, tracker credentials, heartbeat receipt timestamp, movement-state table, notification priority, and movement-query index.

These migrations were applied to the **isolated local SQLite test database only**. No production database migration was run.

The device-sequence migration deliberately stops if duplicate non-null sequences already exist for a device. If production encounters this condition, review the records rather than deleting data or removing the uniqueness protection.

### Restored tests and documentation

- `tests/Feature/TrackerAuthenticationTest.php`
- `tests/Feature/TrackerAuthorizationTest.php`
- `tests/Feature/TrackerCredentialCommandTest.php`
- `tests/Feature/VehicleMovementMonitorTest.php`
- `docs/tracker-availability.md`
- `docs/tracker-credential-cutover.md`

Review the credential cutover document before connecting real hardware. The restored authorization distinguishes individual trackers from the Raspberry Pi gateway; a successful API health check does not prove a hardware packet has the correct credentials, upload source, or replay metadata.

## Admin and driver web: clear reset-email confirmation

Changed files:

- `lib/pages/Admin/pages/Settings.dart`
- `lib/pages/Driver/pages/Settings.dart`
- `test/password_settings_test.dart`

After a successful change-password email request, both settings pages explicitly show a green success notification:

> Password reset email sent. Check your inbox or spam folder to continue.

Previously the message was interpreted as a neutral/orange notice. No backend request contract was changed for these web pages. The password is still changed using the email link, not by clicking the send-email button.

The regression test now uses the current namespaced storage keys, mocks shared preferences, and verifies the updated success message and icon.

The admin `pubspec.lock` already had local changes before this work; it was not intentionally rewritten as part of the notification fix.

## Driver mobile app: align password settings with backend

Changed files:

- `lib/pages/settings.dart`
- `lib/services/auth_service.dart`
- `test/password_reset_email_test.dart` (new)

Previously the app asked for a new password and reported `Password changed successfully`, although the backend sends a reset email instead of immediately changing the password.

The corrected flow:

1. Ask for the current password only.
2. Explain that the new password is chosen through the emailed link.
3. Send `PUT /api/change-password` with only `current_password`.
4. Show a green reset-email success notification after a successful response.
5. Display the backend's rejection message on failure, and avoid updating a disposed page after the request completes.

The new service tests verify the request payload and rejection handling.

`flutter pub get` was run because the previous local dependency configuration did not resolve `shared_preferences` after the repository switch. The local Flutter SDK updated four lockfile dependencies: `matcher`, `meta`, `test_api`, and `vector_math`. Review the `pubspec.lock` diff when committing. Git also reported the generated macOS plugin registrant as modified with a line-ending warning; it did not appear as a substantive content change in the diff summary.

## Local test setup

A separate PHP 8.3 runtime was installed under the admin project's ignored `.dart_tool/local-php83` folder because the existing PHP installation was 8.0 and the backend requires PHP 8.2 or newer.

Local-only files:

- Backend `.env.local-testing`
- Backend `database/local-testing.sqlite`
- Admin `.dart_tool/start-local-backend.ps1`
- Admin `.dart_tool/start-local-web.ps1`
- Admin `.dart_tool/seed-local-backend.php`

These are machine-local testing helpers, not deployment files. Do not commit the local environment, database, runtime binaries, test credentials, or logs.

Start the backend in one PowerShell terminal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\cpsumotorpooladmin\.dart_tool\start-local-backend.ps1"
```

Start the web app in another:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\cpsumotorpooladmin\.dart_tool\start-local-web.ps1"
```

Web URL: `http://localhost:8080`. Backend API: `http://localhost:8000/api`.

The web launcher sets `API_BASE_URL=http://localhost:8000/api`. The backend launcher selects the separate local-testing environment. The normal backend `.env` was preserved and points to Supabase, so do not substitute a plain server or migration command without confirming the selected environment.

Local email uses the log mailer: no actual Gmail delivery is performed. Do not start a second server on a port already in use.

## Verification completed

| Check | Result |
| --- | --- |
| Full backend PHPUnit suite, isolated SQLite | **113 passed, 638 assertions** |
| Driver mobile Flutter suite | **3 passed** |
| Admin/driver web password settings tests | **3 passed** |
| Static analysis of changed mobile service, settings, and new test | **No issues** |
| Local admin login and authenticated user request | Passed |
| Local devices, notifications, and trips GET endpoints | **HTTP 200** |
| Local web server | **HTTP 200** |

Backend command used:

```powershell
& 'D:\cpsumotorpooladmin\.dart_tool\local-php83\php.exe' vendor/phpunit/phpunit/phpunit
```

Run that from the backend folder. The repository's test bootstrap isolates the test database and mail configuration.

Flutter commands used through the installed Flutter tools snapshot were equivalent to:

```text
# From the mobile app folder
flutter test --no-pub --reporter expanded

# From the admin/web folder
flutter test test/password_settings_test.dart --no-pub --reporter expanded
```

Not verified in this work: a full admin/web test suite, production PostgreSQL migrations, live Gmail delivery, Render/Vercel deployment, Android APK/AAB release build, and physical GPS/LoRa/LTE traffic.

## Deployment handoff

1. Review and commit the intended changes in each repository, including the restored backend files currently listed as untracked.
2. Integrate into the owner's repository using the correct `origin` remote and reviewable branches. Resolve the backend's separate history deliberately; do not force-push over the existing main branch.
3. Deploy the backend with the restored migrations. In the intended production environment, inspect migration status and run the normal Laravel deployment migration command (`php artisan migrate --force`). Do not use `migrate:fresh` or reset production data.
4. Verify tracker credential/gateway configuration against `docs/tracker-credential-cutover.md`.
5. Deploy the web app configured for the production backend, not localhost.
6. Build the updated driver APK/AAB separately; mobile distribution is not a Vercel web deployment.
7. Verify live login, unique device registration, trip lifecycle, notifications, and actual reset-email delivery. Test tracker traffic separately with the real hardware.

The local fixes are ready for review and deployment preparation. Production verification remains a separate step.

## Follow-up: November 27 — mobile-browser logout

- Driver app updates were pushed to `raffysolon/cpsu-motorpool-driver-app` main at `6ce3096`.
- In the admin web shell, close the mobile drawer before opening the logout dialog so it cannot cover the dialog or intercept taps. Complete navigation using the surviving Navigator rather than the drawer's disposed context.
- In the driver web dashboard, clear the stored session before navigating to login, and remove earlier routes so Back cannot return to the authenticated screens.
- Changed web files: `lib/widgets/app_shell.dart`, `lib/pages/Driver/pages/Dashboard.dart`, and `test/persistent_admin_shell_test.dart`.
- Three widget tests passed, covering phone-sized driver logout and desktop/mobile admin logout, cancellation, and session cleanup. Physical-device/browser verification after deployment remains necessary.

## Follow-up: notification inbox controls

- Admin web, driver web, and the mobile driver inbox now show a green unread background and `NEW` label. High-priority labels remain visible.
- Each item offers `Mark as read` and `Delete`; deletion requires confirmation. Successful reads leave the inbox open. Failed requests retain the item and show an inline retry message.
- The shared `notification_item.dart` component is included in both Flutter repositories. Mobile notification counts refresh when returning to the dashboard.
- The driver web dashboard no longer replaces real notifications with synthetic trip-summary entries. Web mappings now preserve `is_read` from the API.
- Backend: added authenticated `DELETE /api/notifications/{notification}` with owner checks. Deletion dismisses the notification using `dismissed_at` and marks it read; it does not delete trips or discard event keys needed to prevent duplicate automated alerts.
- Deploy the backend migration `2026_11_27_000001_add_dismissed_at_to_notifications.php` before the updated clients. Existing notifications are preserved because the added column is nullable.
- Verified locally: backend **116 tests / 669 assertions**, web notification tests **8 passed**, mobile suite **7 passed**. The migration was applied only to the local test database; production deployment has not been performed for this feature.
