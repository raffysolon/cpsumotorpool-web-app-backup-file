enum TrackerAvailability {
  online('Online'),
  unstable('Unstable'),
  unreachable('Unreachable');

  const TrackerAvailability(this.label);

  final String label;

  factory TrackerAvailability.fromApi(Map<String, dynamic> device) {
    return switch (device['availability_status']) {
      'online' => TrackerAvailability.online,
      'unstable' => TrackerAvailability.unstable,
      'unreachable' => TrackerAvailability.unreachable,
      _ => device['is_online'] == true || device['is_online'] == 1
          ? TrackerAvailability.online
          : TrackerAvailability.unreachable,
    };
  }
}
