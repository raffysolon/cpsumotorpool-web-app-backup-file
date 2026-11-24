import 'package:cpsumotorpooladmin/utils/driver_trip_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scheduledTrip = {
    'status': 'approved',
    'effective_status': 'scheduled',
    'scheduled_departure': '2026-11-24T13:00:00Z',
    'movements': [
      {
        'movement_no': 1,
        'status': 'scheduled',
        'scheduled_departure': '2026-11-24T13:00:00Z',
      },
    ],
  };

  test('approved unstarted trips display as scheduled', () {
    expect(DriverTripLifecycle.displayStatus(scheduledTrip), 'Scheduled');
    expect(DriverTripLifecycle.hasActuallyStarted(scheduledTrip), isFalse);
  });

  test(
    'start eligibility matches the backend ten-minute and same-day rules',
    () {
      expect(
        DriverTripLifecycle.canStart(
          scheduledTrip,
          now: DateTime.utc(2026, 11, 24, 12, 49),
        ),
        isFalse,
      );
      expect(
        DriverTripLifecycle.canStart(
          scheduledTrip,
          now: DateTime.utc(2026, 11, 24, 12, 50),
        ),
        isTrue,
      );
      final naiveSchedule = {
        ...scheduledTrip,
        'scheduled_departure': '2026-11-24 21:00:00',
        'movements': [
          {
            'movement_no': 1,
            'status': 'scheduled',
            'scheduled_departure': '2026-11-24 21:00:00',
          },
        ],
      };
      expect(
        DriverTripLifecycle.canStart(
          naiveSchedule,
          now: DateTime.utc(2026, 11, 24, 12, 50),
        ),
        isTrue,
      );
      expect(
        DriverTripLifecycle.canStart(
          scheduledTrip,
          now: DateTime.utc(2026, 11, 25, 12, 50),
        ),
        isFalse,
      );
    },
  );

  test('GPS activity alone does not count as a started trip', () {
    final movingButUnstarted = {...scheduledTrip, 'gps_moving': true};

    expect(
      DriverTripLifecycle.canStart(
        movingButUnstarted,
        now: DateTime.utc(2026, 11, 24, 12, 49),
      ),
      isFalse,
    );
    expect(DriverTripLifecycle.displayStatus(movingButUnstarted), 'Scheduled');
  });

  test('started movement prevents another trip start and shows progress', () {
    final startedTrip = {
      ...scheduledTrip,
      'status': 'active',
      'effective_status': 'active',
      'movements': [
        {
          'movement_no': 1,
          'status': 'active',
          'actual_departure_at': '2026-11-24T12:55:00Z',
        },
      ],
    };

    expect(DriverTripLifecycle.hasActuallyStarted(startedTrip), isTrue);
    expect(DriverTripLifecycle.canStart(startedTrip), isFalse);
    expect(DriverTripLifecycle.displayStatus(startedTrip), 'In Progress');
  });

  test('disabled start reason explains the ten-minute eligibility window', () {
    expect(
      DriverTripLifecycle.startDisabledReason(
        scheduledTrip,
        now: DateTime.utc(2026, 11, 24, 12, 49),
      ),
      'Start Trip is available 10 minutes before scheduled departure.',
    );
  });
}
