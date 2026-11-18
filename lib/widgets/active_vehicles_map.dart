import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/active_vehicles.dart';
import '../services/gps_service.dart';
import 'app_shell.dart';

// === Vehicle with its latest GPS location ===

class VehicleTrackingData {
  const VehicleTrackingData({required this.vehicle, required this.location});

  final TrackedVehicle vehicle;
  final GpsLocation location;
}

// === Active Vehicles Map ===

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

  Timer? _refreshTimer;

  List<VehicleTrackingData> _trackedVehicles = [];

  bool _isLoading = true;
  bool _isFetching = false;
  bool _mapReady = false;
  bool _hasCentered = false;

  String? _errorMessage;

  int _registeredVehicleCount = 0;

  @override
  void initState() {
    super.initState();

    _fetchGpsLocations();

    // Refresh actual GPS locations every five seconds.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchGpsLocations(),
    );
  }

  // === Retrieve actual vehicle locations ===

  Future<void> _fetchGpsLocations() async {
    // Prevent overlapping API requests.
    if (_isFetching || !mounted) return;

    _isFetching = true;

    try {
      final vehicles = await GpsService.getTrackedVehicles();

      final updatedVehicles = <VehicleTrackingData>[];

      for (final vehicle in vehicles) {
        if (!mounted) return;

        final location = await GpsService.getLatestLocation(vehicle.vehicleId);

        if (location != null) {
          updatedVehicles.add(
            VehicleTrackingData(vehicle: vehicle, location: location),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _trackedVehicles = updatedVehicles;
        _registeredVehicleCount = vehicles.length;
        _isLoading = false;
        _errorMessage = null;
      });

      _centerOnFirstVehicle();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _isFetching = false;
    }
  }

  // === Center map on the first actual GPS location ===

  void _centerOnFirstVehicle() {
    if (!_mapReady || _hasCentered || _trackedVehicles.isEmpty) {
      return;
    }

    final firstLocation = _trackedVehicles.first.location.position;

    _controller.move(firstLocation, 15);

    _hasCentered = true;
  }

  // === Map zoom controls ===

  void _zoomBy(double delta) {
    if (!_mapReady) return;

    final camera = _controller.camera;

    final next = (camera.zoom + delta).clamp(8.0, 18.0);

    _controller.move(camera.center, next);
  }

  // === Format GPS recording time ===

  String _formatRecordedAt(DateTime recordedAt) {
    final local = recordedAt.toLocal();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}:'
        '${twoDigits(local.second)}';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentCount = _trackedVehicles
        .where((vehicle) => vehicle.location.isRecent)
        .length;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: bacolodCenter,
            initialZoom: widget.initialZoom,
            minZoom: 8,
            maxZoom: 18,
            onMapReady: () {
              _mapReady = true;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _centerOnFirstVehicle();
                }
              });
            },
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

            // === Actual GPS vehicle markers ===
            MarkerLayer(
              markers: [
                for (final item in _trackedVehicles)
                  Marker(
                    point: item.location.position,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message:
                          '${item.vehicle.name}\n'
                          'Plate: ${item.vehicle.plate}\n'
                          'Device: ${item.vehicle.deviceId}\n'
                          'Latitude: ${item.location.latitude.toStringAsFixed(6)}\n'
                          'Longitude: ${item.location.longitude.toStringAsFixed(6)}\n'
                          'Satellites: ${item.location.satellites ?? 'Unknown'}\n'
                          'Last received: ${_formatRecordedAt(item.location.recordedAt)}\n'
                          'Status: ${item.location.isRecent ? 'Recent GPS' : 'Outdated GPS'}',
                      child: _VehiclePin(isRecent: item.location.isRecent),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // === Existing zoom buttons ===
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _ZoomButton(
                tooltip: 'Zoom in',
                icon: Icons.add,
                onPressed: () => _zoomBy(1),
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                tooltip: 'Zoom out',
                icon: Icons.remove,
                onPressed: () => _zoomBy(-1),
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                tooltip: 'Fit all vehicles',
                icon: Icons.center_focus_strong,
                onPressed: () {
                  if (_trackedVehicles.isEmpty || !_mapReady) {
                    return;
                  }

                  if (_trackedVehicles.length == 1) {
                    _controller.move(
                      _trackedVehicles.first.location.position,
                      15,
                    );
                  } else {
                    _controller.fitCamera(
                      CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(
                          _trackedVehicles
                              .map((item) => item.location.position)
                              .toList(),
                        ),
                        padding: const EdgeInsets.fromLTRB(56, 72, 72, 56),
                        maxZoom: 15,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),

        // === Live tracking status ===
        Positioned(
          top: 12,
          left: 12,
          right: 64,
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _errorMessage != null
                          ? Colors.red
                          : recentCount > 0
                          ? Colors.green
                          : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _isLoading
                          ? 'Loading GPS...'
                          : _errorMessage != null
                          ? 'GPS refresh failed'
                          : '$recentCount recent GPS / '
                                '$_registeredVehicleCount registered',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // === Initial loading indicator ===
        if (_isLoading) const Center(child: CircularProgressIndicator()),

        // === GPS error or empty state ===
        if (!_isLoading && (_errorMessage != null || _trackedVehicles.isEmpty))
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 6),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _errorMessage != null
                        ? Icons.warning_amber_rounded
                        : Icons.location_off,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage ?? 'No GPS locations available yet.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchGpsLocations,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),

        // === OpenStreetMap attribution ===
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            color: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 9, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}

// === Vehicle marker ===

class _VehiclePin extends StatelessWidget {
  const _VehiclePin({required this.isRecent});

  final bool isRecent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isRecent ? AppColors.primary : Colors.grey,
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

// === Existing reusable zoom button ===

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });
  final String tooltip;

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
          width: 44,
          height: 44,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 20, color: AppColors.navy),
          ),
        ),
      ),
    );
  }
}

// === Existing dashboard map card ===

class ActiveVehiclesMapCard extends StatelessWidget {
  const ActiveVehiclesMapCard({super.key, this.fillHeight = false});

  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Vehicle Tracking',
                    style: AppTypography.bodyStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                Text(
                  'GPS Monitoring',
                  style: AppTypography.bodyStyle(
                    fontSize: 13,
                    color: AppColors.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          if (fillHeight)
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  child: SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: ActiveVehiclesMap(initialZoom: 11.5),
                  ),
                ),
              ),
            )
          else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.48).clamp(
                  280.0,
                  520.0,
                ),
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
              child: const Text('Open full map'),
            ),
          ),
        ],
      ),
    );
  }
}
