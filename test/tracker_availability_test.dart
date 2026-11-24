import 'package:cpsumotorpooladmin/models/tracker_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the backend heartbeat availability states', () {
    expect(
      TrackerAvailability.fromApi({'availability_status': 'online'}),
      TrackerAvailability.online,
    );
    expect(
      TrackerAvailability.fromApi({'availability_status': 'unstable'}),
      TrackerAvailability.unstable,
    );
    expect(
      TrackerAvailability.fromApi({'availability_status': 'unreachable'}),
      TrackerAvailability.unreachable,
    );
  });

  test(
    'falls back to the legacy online flag when the API omits availability',
    () {
      expect(
        TrackerAvailability.fromApi({'is_online': true}),
        TrackerAvailability.online,
      );
      expect(
        TrackerAvailability.fromApi({'is_online': 1}),
        TrackerAvailability.online,
      );
      expect(
        TrackerAvailability.fromApi({'is_online': false}),
        TrackerAvailability.unreachable,
      );
    },
  );

  test('prefers availability status over the legacy online flag', () {
    expect(
      TrackerAvailability.fromApi({
        'availability_status': 'unstable',
        'is_online': true,
      }),
      TrackerAvailability.unstable,
    );
    expect(
      TrackerAvailability.fromApi({
        'availability_status': 'unreachable',
        'is_online': true,
      }),
      TrackerAvailability.unreachable,
    );
  });
}
