import 'package:flutter/material.dart';

/// Shared inbox row: mutations are shown only after the server accepts them.
class NotificationItem extends StatefulWidget {
  const NotificationItem({
    super.key,
    required this.notification,
    required this.onAcknowledge,
    this.onDelete,
  });
  final Map<String, dynamic> notification;
  final Future<void> Function(int) onAcknowledge;
  final Future<void> Function(int)? onDelete;

  @override
  State<NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<NotificationItem> {
  bool _busy = false;
  bool _sending = false;
  bool _read = false;
  bool _deleted = false;
  String? _error;

  bool get isRead => _read || widget.notification['is_read'] == true;

  Future<void> _act(bool delete) async {
    final id = int.tryParse('${widget.notification['id']}');
    if (_busy || id == null) return;
    setState(() {
      _busy = true;
      _sending = !delete;
      _error = null;
    });
    try {
      if (delete) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete notification?'),
            content: const Text(
              'This removes it from your notifications. Your trip records will not be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        setState(() => _sending = true);
        await widget.onDelete!(id);
        if (mounted) setState(() => _deleted = true);
      } else {
        await widget.onAcknowledge(id);
        if (mounted) setState(() => _read = true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = delete
              ? 'Unable to delete notification. Please try again.'
              : 'Unable to mark as read. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const SizedBox.shrink();
    final high = widget.notification['priority'] == 'high';
    final date = (widget.notification['created_at'] ?? '').toString();
    final parsed = DateTime.tryParse(date)?.toLocal();
    final dateLabel = parsed == null
        ? (date.isEmpty ? 'Just now' : date)
        : '${parsed.month}/${parsed.day}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    final accent = high ? Colors.red.shade800 : const Color(0xFF1F8A3D);
    return Material(
      color: isRead ? Colors.transparent : const Color(0xFFF0F8F2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy || isRead ? null : () => _act(false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  high
                      ? Icons.warning_amber_rounded
                      : isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active_outlined,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (!isRead)
                          const Text(
                            'NEW',
                            style: TextStyle(
                              color: Color(0xFF176E30),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        if (high)
                          Text(
                            'HIGH PRIORITY',
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        Tooltip(
                          message: date.isEmpty ? 'Just now' : date,
                          child: Text(
                            dateLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${widget.notification['message'] ?? 'Notification'}',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: const Color(0xFF1F2933),
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              if (_busy && _sending)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<String>(
                  enabled: !_busy,
                  tooltip: 'Notification actions',
                  onSelected: (value) => _act(value == 'delete'),
                  itemBuilder: (_) => [
                    if (!isRead)
                      const PopupMenuItem(
                        value: 'read',
                        child: Text('Mark as read'),
                      ),
                    if (widget.onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
