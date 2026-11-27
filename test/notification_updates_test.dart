import 'package:flutter_test/flutter_test.dart';
import 'package:cpsumotorpooladmin/services/notification_updates.dart';

void main() {
  test('alerts once for new unread entries and separates accounts', () {
    final updates = NotificationUpdates();
    final first = <String, dynamic>{'id': 1, 'is_read': false, 'message': 'Trip approved'};
    expect(updates.observe('driver-1', [first]), contains('1 unread'));
    expect(updates.observe('driver-1', [first]), isNull);
    expect(updates.observe('driver-1', [first, {'id': 2, 'is_read': false, 'message': 'New trip'}]), 'New trip');
    expect(updates.observe('driver-1', [first, {'id': 3, 'is_read': true}]), isNull);
    expect(updates.observe('driver-2', [first]), contains('1 unread'));
  });
}
