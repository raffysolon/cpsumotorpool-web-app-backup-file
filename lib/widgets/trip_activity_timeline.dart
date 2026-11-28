import 'package:flutter/material.dart';

import '../services/trip_service.dart';
import '../utils/philippine_time.dart';

class TripActivityTimeline extends StatefulWidget {
  const TripActivityTimeline({super.key, required this.tripId});

  final int tripId;

  @override
  State<TripActivityTimeline> createState() => _TripActivityTimelineState();
}

class _TripActivityTimelineState extends State<TripActivityTimeline> {
  late var _activity = TripService.getTripActivity(widget.tripId);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _activity,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unable to load trip activity.'),
            TextButton(
              onPressed: () => setState(
                () => _activity = TripService.getTripActivity(widget.tripId),
              ),
              child: const Text('Retry activity'),
            ),
          ],
        );
      }

      final activity = snapshot.requireData;
      final events = (activity['events'] as List).cast<Map<String, dynamic>>();
      if (events.isEmpty) return const Text('No trip activity recorded yet.');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in events) _event(context, event),
          if (activity['decision_time_missing'] == true)
            const Text('The approval or denial time was not recorded.'),
        ],
      );
    },
  );

  Widget _event(BuildContext context, Map<String, dynamic> event) {
    final (label, icon) = switch (event['action']) {
      'submitted' => ('Trip request submitted', Icons.send_outlined),
      'admin_created' => (
        'Trip created and assigned',
        Icons.assignment_outlined,
      ),
      'approved' => ('Trip approved', Icons.check_circle_outline),
      'denied' => ('Trip denied', Icons.cancel_outlined),
      'outbound_started' => (
        'Outbound trip started',
        Icons.directions_car_outlined,
      ),
      'outbound_arrived' => ('Arrived at destination', Icons.place_outlined),
      'return_started' => ('Return trip started', Icons.u_turn_left),
      'completed' => ('Trip completed', Icons.flag_outlined),
      _ => ('Trip created', Icons.assignment_outlined),
    };
    final name = (event['actor_name'] as String?)?.trim();
    final role = switch (event['actor_role']) {
      'admin' => 'Admin',
      'driver' => 'Driver',
      _ => null,
    };
    final actor = name == null || name.isEmpty
        ? role == null
              ? 'Person not recorded'
              : '$role name not recorded'
        : role == null
        ? name
        : '$name ($role)';
    final time = formatPhilippineTimestamp(event['occurred_at'] as String?);
    final lateMinutes = event['late_minutes'] as num?;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(actor, style: theme.textTheme.bodySmall),
                if (time != null) Text(time, style: theme.textTheme.bodySmall),
                if (lateMinutes != null && lateMinutes > 0)
                  Text(
                    '$lateMinutes min late',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
