import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/active_vehicles.dart';
import 'app_shell.dart';

// === Active Vehicles Map: reusable map and map card widgets ===
class ActiveVehiclesMap extends StatefulWidget {
  const ActiveVehiclesMap({
    super.key,
    this.initialZoom = 12,
    this.interactive = true,
  });

  final double initialZoom;
  final bool interactive;

  @override
  State<ActiveVehiclesMap> createState() => _ActiveVehiclesMapState();
}

class _ActiveVehiclesMapState extends State<ActiveVehiclesMap> {
  final MapController _controller = MapController();

  // --- Map controls: change zoom while keeping the current center ---
  void _zoomBy(double delta) {
    final camera = _controller.camera;
    final next = (camera.zoom + delta).clamp(8.0, 18.0);
    _controller.move(camera.center, next);
  }

  @override
  // --- Map layout: tiles, vehicle markers, and zoom controls ---
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: bacolodCenter,
            initialZoom: widget.initialZoom,
            minZoom: 8,
            maxZoom: 18,
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.cpsumotorpooladmin',
            ),
            MarkerLayer(
              markers: [
                for (final vehicle in activeVehicles)
                  Marker(
                    point: vehicle.position,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: '${vehicle.plate} · ${vehicle.driver}',
                      child: const _VehiclePin(),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _ZoomButton(
                icon: Icons.add,
                onPressed: () => _zoomBy(1),
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                icon: Icons.remove,
                onPressed: () => _zoomBy(-1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// === Vehicle marker: truck pin displayed on the map ===
class _VehiclePin extends StatelessWidget {
  const _VehiclePin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_shipping_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

// === Zoom control: reusable plus/minus map button ===
class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.navy),
        ),
      ),
    );
  }
}

// === Active vehicles card: dashboard map summary ===
class ActiveVehiclesMapCard extends StatelessWidget {
  const ActiveVehiclesMapCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Active Vehicles',
                    style: AppTypography.bodyStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                Text(
                  '3 on trip',
                  style: AppTypography.bodyStyle(
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
                height: (MediaQuery.sizeOf(context).height * 0.32)
                    .clamp(180.0, 320.0),
                width: double.infinity,
                child: const ActiveVehiclesMap(initialZoom: 11.5),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/map'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                textStyle: AppTypography.buttonLabel(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              child: const Text('View All'),
            ),
          ),
        ],
      ),
    );
  }
}
