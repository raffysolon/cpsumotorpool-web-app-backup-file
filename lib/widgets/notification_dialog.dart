import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'notification_item.dart';

class NotificationDialog extends StatefulWidget {
  const NotificationDialog({
    super.key,
    required this.notifications,
    required this.onAcknowledge,
    this.onDelete,
    this.loadNotifications,
  });

  final List<Map<String, dynamic>> notifications;
  final Future<void> Function(int id) onAcknowledge;
  final Future<void> Function(int id)? onDelete;
  final Future<List<Map<String, dynamic>>> Function()? loadNotifications;

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  final Set<int> _deleted = {};
  List<Map<String, dynamic>>? _loaded;
  String? _error;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.loadNotifications != null) {
      _refresh();
      _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    if (_loading || widget.loadNotifications == null) return;
    _loading = true;
    try {
      final items = await widget.loadNotifications!();
      if (mounted) {
        setState(() {
          _loaded = items;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to refresh notifications. Please retry.',
        );
      }
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get notifications =>
      (_loaded ?? widget.notifications)
          .where((item) => !_deleted.contains(int.tryParse('${item['id']}')))
          .toList();

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final width = math.min(920.0, screenSize.width * 0.92);
    final horizontalInset = (screenSize.width - width) / 2;
    final verticalInset = screenSize.height * 0.08;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      constraints: const BoxConstraints(maxWidth: 920),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: const Key('notification-dialog-surface'),
        width: width,
        height: screenSize.height * 0.84,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Color(0xFF1F2933),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close notifications',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_error != null)
              ListTile(
                title: Text(_error!),
                trailing: TextButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ),
            Expanded(
              child: notifications.isEmpty && _error != null
                  ? const SizedBox.shrink()
                  : notifications.isEmpty
                  ? const _EmptyNotifications()
                  : Scrollbar(
                      thumbVisibility: screenSize.width >= 700,
                      child: ListView.separated(
                        key: const Key('notification-list'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) => NotificationItem(
                          key: ValueKey(notifications[index]['id']),
                          notification: notifications[index],
                          onAcknowledge: widget.onAcknowledge,
                          onDelete: widget.onDelete == null
                              ? null
                              : (id) async {
                                  await widget.onDelete!(id);
                                  if (mounted) setState(() => _deleted.add(id));
                                },
                        ),
                      ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(88, 48),
                    foregroundColor: const Color(0xFF176E30),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: Colors.blueGrey.shade300,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'No notifications yet',
              style: TextStyle(
                color: Color(0xFF1F2933),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'New updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
