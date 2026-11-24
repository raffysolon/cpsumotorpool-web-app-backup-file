import 'package:cpsumotorpooladmin/utils/philippine_time.dart';

class DriverTripLifecycle {
  static bool hasActuallyStarted(Map<dynamic, dynamic> trip) {
    final outbound = _outboundMovement(trip);
    final status = (outbound?['status'] ?? '').toString().toLowerCase();
    return _hasValue(outbound?['actual_departure_at']) ||
        status == 'active' ||
        status == 'completed';
  }

  static bool isScheduled(Map<dynamic, dynamic> trip) {
    final stored = (trip['status'] ?? '').toString().trim().toLowerCase();
    final effective = (trip['effective_status'] ?? stored)
        .toString()
        .trim()
        .toLowerCase();
    return stored == 'approved' ||
        stored == 'scheduled' ||
        (stored != 'active' && effective == 'scheduled');
  }

  static String displayStatus(Map<dynamic, dynamic> trip) {
    final stored = (trip['status'] ?? '').toString().trim().toLowerCase();
    if (stored == 'completed') return 'Completed';
    if (hasActuallyStarted(trip)) return 'In Progress';
    if (isScheduled(trip)) return 'Scheduled';

    final status = stored.isEmpty
        ? (trip['effective_status'] ?? 'pending')
              .toString()
              .trim()
              .toLowerCase()
        : stored;
    return status.isEmpty
        ? 'Pending'
        : '${status[0].toUpperCase()}${status.substring(1)}';
  }

  static bool canStart(Map<dynamic, dynamic> trip, {DateTime? now}) {
    if (!isScheduled(trip) || hasActuallyStarted(trip)) return false;
    final stored = (trip['status'] ?? '').toString().trim().toLowerCase();
    if (stored.isNotEmpty && stored != 'approved' && stored != 'scheduled') {
      return false;
    }

    final outbound = _outboundMovement(trip);
    if (outbound != null) {
      final movementStatus = (outbound['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (movementStatus != 'scheduled' ||
          _hasValue(outbound['actual_departure_at'])) {
        return false;
      }
    }

    final departure = _philippineWallTime(
      outbound?['scheduled_departure']?.toString() ??
          trip['scheduled_departure']?.toString(),
    );
    if (departure == null) return false;

    final current = _asPhilippineWallTime(now ?? DateTime.now());
    final sameDate =
        departure.year == current.year &&
        departure.month == current.month &&
        departure.day == current.day;
    return sameDate &&
        !current.isBefore(departure.subtract(const Duration(minutes: 10)));
  }

  static String startDisabledReason(
    Map<dynamic, dynamic> trip, {
    DateTime? now,
  }) {
    if (hasActuallyStarted(trip)) return 'This trip has already started.';
    if (!isScheduled(trip)) {
      return 'Only approved scheduled trips can be started.';
    }

    final outbound = _outboundMovement(trip);
    if (outbound != null &&
        (outbound['status'] ?? '').toString().toLowerCase() != 'scheduled') {
      return 'This trip is not ready to start.';
    }

    final departure = _philippineWallTime(
      outbound?['scheduled_departure']?.toString() ??
          trip['scheduled_departure']?.toString(),
    );
    if (departure == null) {
      return 'The scheduled departure time is unavailable.';
    }

    final current = _asPhilippineWallTime(now ?? DateTime.now());
    final sameDate =
        departure.year == current.year &&
        departure.month == current.month &&
        departure.day == current.day;
    if (!sameDate) {
      return 'Start Trip is available on the scheduled departure date.';
    }
    if (current.isBefore(departure.subtract(const Duration(minutes: 10)))) {
      return 'Start Trip is available 10 minutes before scheduled departure.';
    }
    return '';
  }

  static Map<dynamic, dynamic>? _outboundMovement(Map<dynamic, dynamic> trip) {
    final movements = trip['movements'];
    if (movements is! List) return null;
    for (final movement in movements.whereType<Map>()) {
      if ('${movement['movement_no']}' == '1') return movement;
    }
    return null;
  }

  static bool _hasValue(Object? value) =>
      value != null && value.toString().trim().isNotEmpty;

  static DateTime? _philippineWallTime(String? value) =>
      parsePhilippineTimestamp(value);

  static DateTime _asPhilippineWallTime(DateTime value) =>
      value.toUtc().add(const Duration(hours: 8));
}
