import 'package:cpsumotorpooladmin/utils/philippine_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats explicit UTC timestamps in Philippine time', () {
    expect(
      formatPhilippineTimestamp('2026-11-24T11:00:00.000000Z'),
      'Nov 24, 2026 7:00 PM PHT',
    );
  });

  test('parses naive timestamps according to their API field convention', () {
    expect(
      formatPhilippineTimestamp(
        '2026-11-24 11:00:00',
        naiveTimestampIsUtc: true,
      ),
      'Nov 24, 2026 7:00 PM PHT',
    );
    expect(
      formatPhilippineTimestamp('2026-11-24 19:00:00'),
      'Nov 24, 2026 7:00 PM PHT',
    );
  });

  test(
    'last seen and UTC heartbeat values remain consistent in the registry',
    () {
      final lastSeen = formatPhilippineTimestamp('2026-11-24 20:33:00');
      final lastHeartbeat = formatPhilippineTimestamp(
        '2026-11-24 12:33:00',
        naiveTimestampIsUtc: true,
      );

      expect(lastSeen, 'Nov 24, 2026 8:33 PM PHT');
      expect(lastHeartbeat, lastSeen);
    },
  );

  test('keeps malformed API timestamps visible', () {
    expect(formatPhilippineTimestamp('unknown timestamp'), 'unknown timestamp');
  });
}
