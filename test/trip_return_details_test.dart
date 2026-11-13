import 'package:flutter_test/flutter_test.dart';
import 'package:cpsumotorpooladmin/data/trip_return_details.dart';

void main() {
  test('uses the trip schedule and keeps actual times separate', () {
    final details = TripReturnDetails.fromJson({
      'return_scheduled_departure': '2026-11-08 15:00:00',
      'movements': [
        {
          'movement_no': 2,
          'scheduled_departure': '2026-11-08 14:00:00',
          'actual_departure_at': '2026-11-08 15:10:00',
          'actual_arrival_at': '2026-11-08 17:00:00',
        },
      ],
    });
    expect(details.scheduled, DateTime(2026, 11, 8, 15));
    expect(details.departed, DateTime(2026, 11, 8, 15, 10));
    expect(details.arrived, DateTime(2026, 11, 8, 17));
  });

  test(
    'reads return movement schedule when trip schedule is missing or invalid',
    () {
      for (final schedule in [null, '', 'invalid']) {
        final details = TripReturnDetails.fromJson({
          'return_scheduled_departure': schedule,
          'movements': [
            {'movement_no': 1, 'scheduled_departure': '2026-11-08 08:00:00'},
            {'movement_no': '2', 'scheduled_departure': '2026-11-08 15:00:00'},
          ],
        });
        expect(details.scheduled, DateTime(2026, 11, 8, 15));
      }
    },
  );

  test(
    'completed return without planned schedule does not invent a schedule',
    () {
      final details = TripReturnDetails.fromJson({
        'status': 'completed',
        'movements': [
          {
            'movement_no': 2,
            'actual_departure_at': '2026-11-08T07:10:00Z',
            'actual_arrival_at': '2026-11-08T09:00:00Z',
          },
        ],
      });
      expect(details.scheduled, isNull);
      expect(details.departed, DateTime.utc(2026, 11, 8, 7, 10).toLocal());
      expect(details.arrived, DateTime.utc(2026, 11, 8, 9).toLocal());
    },
  );

  test('older or malformed records leave missing return times empty', () {
    for (final movements in [
      null,
      'invalid',
      [],
      [
        null,
        {'movement_no': 1},
      ],
    ]) {
      final details = TripReturnDetails.fromJson({'movements': movements});
      expect(details.scheduled, isNull);
      expect(details.departed, isNull);
      expect(details.arrived, isNull);
    }
  });
}
