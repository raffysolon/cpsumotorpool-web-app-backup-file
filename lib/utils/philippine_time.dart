String? formatPhilippineTimestamp(
  String? value, {
  bool naiveTimestampIsUtc = false,
}) {
  if (value == null || value.trim().isEmpty) return null;

  final timestamp = value.trim().replaceFirst(' ', 'T');
  final hasOffset = RegExp(
    r'(?:[zZ]|[+-]\d{2}(?::?\d{2})?)$',
  ).hasMatch(timestamp);
  final normalized = hasOffset
      ? timestamp
      : '$timestamp${naiveTimestampIsUtc ? 'Z' : '+08:00'}';
  final parsed = DateTime.tryParse(normalized);
  if (parsed == null) return value;

  final local = parsed.toUtc().add(const Duration(hours: 8));
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final period = local.hour < 12 ? 'AM' : 'PM';

  return '${months[local.month - 1]} ${local.day}, ${local.year} '
      '$hour:${twoDigits(local.minute)} $period PHT';
}
