import 'package:flutter/material.dart';

import 'app_shell.dart';

class DriverTripDetails extends StatelessWidget {
  const DriverTripDetails({
    super.key,
    required this.vehicle,
    required this.departure,
    required this.status,
  });

  final String vehicle;
  final String departure;
  final String status;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final details = [
          _detail('VEHICLE', vehicle),
          _detail('DEPARTURE', departure),
          _detail('STATUS', status),
        ];
        if (constraints.maxWidth < 500) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < details.length; index++) ...[
                if (index > 0) const SizedBox(height: 14),
                details[index],
              ],
            ],
          );
        }
        return Row(
          children: [for (final detail in details) Expanded(child: detail)],
        );
      },
    );
  }

  Widget _detail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.mutedDark,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .6,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        softWrap: true,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}
