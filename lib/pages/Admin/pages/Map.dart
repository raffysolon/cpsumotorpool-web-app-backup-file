// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/widgets/active_vehicles_map.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/map',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = constraints.maxWidth < 700 ? 12.0 : 20.0;
          return SingleChildScrollView(
            child: SizedBox(
              height: constraints.maxHeight < 520 ? 520 : constraints.maxHeight,
              child: Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeader(
                      title: 'Map',
                      subtitle: 'Vehicle locations and GPS status',
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.all(8),
                        borderRadius: 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: const ActiveVehiclesMap(initialZoom: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _MapLegend(
                          color: AppColors.primary,
                          label: 'Recent GPS',
                        ),
                        _MapLegend(color: Colors.grey, label: 'Outdated GPS'),
                        Text(
                          'Refresh every 5 seconds',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.mutedDark),
      ),
    ],
  );
}
