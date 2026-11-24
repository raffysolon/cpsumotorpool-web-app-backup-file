import 'package:flutter/material.dart';

import '../models/tracker_availability.dart';

class HeartbeatIndicator extends StatelessWidget {
  const HeartbeatIndicator({
    super.key,
    required this.status,
    this.showLabel = true,
    this.showTooltip = true,
    this.compact = false,
    this.iconSize,
  });

  final TrackerAvailability status;
  final bool showLabel;
  final bool showTooltip;
  final bool compact;
  final double? iconSize;

  Color get _color => switch (status) {
    TrackerAvailability.online => Colors.green.shade800,
    TrackerAvailability.unstable => Colors.amber.shade900,
    TrackerAvailability.unreachable => Colors.grey.shade700,
  };

  @override
  Widget build(BuildContext context) {
    final dotSize = iconSize ?? (compact ? 8.0 : 10.0);
    final dot = Container(
      key: const Key('heartbeat-status-dot'),
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        if (showLabel) ...[
          SizedBox(width: compact ? 5 : 7),
          Text(
            status.label,
            style: TextStyle(
              color: _color,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
    return Semantics(
      label: 'Tracker heartbeat status: ${status.label}',
      child: showTooltip
          ? Tooltip(
              message: 'Tracker heartbeat: ${status.label}',
              child: content,
            )
          : content,
    );
  }
}
