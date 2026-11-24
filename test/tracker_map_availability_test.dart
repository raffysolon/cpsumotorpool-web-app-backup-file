import 'package:cpsumotorpooladmin/models/tracker_availability.dart';
import 'package:cpsumotorpooladmin/services/gps_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps tracker heartbeat availability independent from GPS freshness',
    () {
      final trackedVehicle = TrackedVehicle.fromJson({
        'vehicle_id': 1,
        'device_id': 'TRACKER-1',
        'vehicle_plate': 'ABC-123',
        'vehicle_name': 'Test vehicle',
        'availability_status': 'unreachable',
        'is_online': true,
      });
      final location = GpsLocation(
        id: 1,
        vehicleId: 1,
        latitude: 10,
        longitude: 122,
        recordedAt: DateTime.utc(2026, 11, 24, 11, 0),
      );

      expect(
        trackedVehicle.availabilityStatus,
        TrackerAvailability.unreachable,
      );
      expect(
        location.isRecentAt(DateTime.utc(2026, 11, 24, 11, 0, 30)),
        isTrue,
      );
    },
  );
}
