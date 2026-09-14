// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'package:cpsumotorpooladmin/data/active_vehicles.dart';
import 'package:cpsumotorpooladmin/widgets/active_vehicles_map.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// === Map page: full active vehicle map view ===
class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  // --- Map page layout: responsive heading, map, and vehicle list ---
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/map',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = constraints.maxWidth < 700 ? 16.0 : 28.0;
          final mapHeight = (constraints.maxHeight - 210).clamp(220.0, 1400.0);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(title: 'Map'),
                const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Active Vehicles',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            Text(
                              '3 on trip',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: mapHeight,
                            width: double.infinity,
                            child: const ActiveVehiclesMap(initialZoom: 12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final vehicle in activeVehicles)
                              Chip(
                                avatar: const CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Icon(
                                    Icons.local_shipping_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                label: Text(
                                  '${vehicle.plate} · ${vehicle.driver}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: const Color(0xFFF0FDF4),
                                side: BorderSide.none,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
