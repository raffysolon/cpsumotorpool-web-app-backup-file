import 'dart:math' as math;

import 'package:flutter/material.dart';

class NotificationDialog extends StatelessWidget {
  const NotificationDialog({
    super.key,
    required this.notifications,
    required this.onAcknowledge,
  });

  final List<Map<String, dynamic>> notifications;
  final Future<void> Function(int id) onAcknowledge;

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
            Expanded(
              child: notifications.isEmpty
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
                        itemBuilder: (context, index) => _NotificationItem(
                          notification: notifications[index],
                          onAcknowledge: onAcknowledge,
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

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.notification,
    required this.onAcknowledge,
  });

  final Map<String, dynamic> notification;
  final Future<void> Function(int id) onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final id = _notificationId(notification['id']);
    final message = (notification['message'] ?? 'Notification').toString();
    final createdAt = (notification['created_at'] ?? '').toString();
    final isHighPriority = notification['priority'] == 'high';
    final accent = isHighPriority
        ? Colors.red.shade800
        : const Color(0xFF1F8A3D);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: id == null
            ? null
            : () async {
                try {
                  await onAcknowledge(id);
                } finally {
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isHighPriority
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isHighPriority)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'HIGH PRIORITY',
                              style: TextStyle(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        Tooltip(
                          message: createdAt.isEmpty
                              ? _relativeTime(createdAt)
                              : createdAt,
                          child: Text(
                            _relativeTime(createdAt),
                            style: TextStyle(
                              color: Colors.blueGrey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      softWrap: true,
                      style: const TextStyle(
                        color: Color(0xFF1F2933),
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _notificationId(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _relativeTime(String value) {
    if (value.isEmpty) return 'Just now';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${date.month}/${date.day}';
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
