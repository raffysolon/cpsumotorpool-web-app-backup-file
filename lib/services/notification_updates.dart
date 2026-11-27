/// Tracks new inbox entries per signed-in account without repeating alerts.
class NotificationUpdates {
  String? _account;
  Set<String> _seen = {};

  String? observe(String account, List<Map<String, dynamic>> items) {
    final ids = items.map((n) => '${n['id']}').toSet();
    if (_account != account) {
      _account = account;
      _seen = ids;
      final unread = items.where((n) => n['is_read'] != true).length;
      return unread == 0
          ? null
          : 'You have $unread unread notifications. Open the bell to view them.';
    }
    final fresh = items
        .where((n) => n['is_read'] != true && !_seen.contains('${n['id']}'))
        .toList();
    _seen.addAll(ids);
    if (fresh.isEmpty) return null;
    return fresh.length == 1
        ? '${fresh.first['message'] ?? 'New trip update'}'
        : '${fresh.length} new notifications. Open the bell to view them.';
  }
}
