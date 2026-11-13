/// Return schedule and recorded movement times are separate facts.
class TripReturnDetails {
  const TripReturnDetails({this.scheduled, this.departed, this.arrived});

  final DateTime? scheduled;
  final DateTime? departed;
  final DateTime? arrived;

  factory TripReturnDetails.fromJson(Map<String, dynamic> trip) {
    final movements = trip['movements'];
    Map<dynamic, dynamic> returning = const {};
    if (movements is List) {
      for (final movement in movements.whereType<Map>()) {
        if ('${movement['movement_no']}' == '2') {
          returning = movement;
          break;
        }
      }
    }

    DateTime? parse(dynamic value) =>
        DateTime.tryParse(value?.toString() ?? '')?.toLocal();

    return TripReturnDetails(
      scheduled:
          parse(trip['return_scheduled_departure']) ??
          parse(returning['scheduled_departure']),
      departed: parse(returning['actual_departure_at']),
      arrived: parse(returning['actual_arrival_at']),
    );
  }
}
