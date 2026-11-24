import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/active_vehicles.dart';
import '../models/tracker_availability.dart';
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
    this.loadVehicles = GpsService.getTrackedVehicles,
    this.loadLocation = GpsService.getLatestLocation,
  });

  final double initialZoom;
  final bool interactive;
  final Future<List<TrackedVehicle>> Function() loadVehicles;
  final Future<GpsLocation?> Function(int) loadLocation;

  @override
  State<ActiveVehiclesMap> createState() => _ActiveVehiclesMapState();
}

class _ActiveVehiclesMapState extends State<ActiveVehiclesMap>
    with WidgetsBindingObserver {
  bool _isVisible = true;
  final MapController _controller = MapController();

  Timer? _refreshTimer;

  List<VehicleTrackingData> _trackedVehicles = [];

  bool _isLoading = true;
  bool _isFetching = false;
  bool _mapReady = false;
  bool _hasCentered = false;

  String? _errorMessage;
  DateTime? _lastSuccessfulRefresh;

  int _registeredVehicleCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchGpsLocations());

    // Refresh actual GPS locations every five seconds.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchGpsLocations(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isVisible = state == AppLifecycleState.resumed;
    if (_isVisible) _fetchGpsLocations();
  }

  // === Retrieve actual vehicle locations ===

  Future<void> _fetchGpsLocations() async {
    // Prevent overlapping API requests.
    if (_isFetching ||
        !mounted ||
        !_isVisible ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }

    _isFetching = true;

    try {
      final vehicles = await widget.loadVehicles();

      final updatedVehicles = <VehicleTrackingData>[];
      final failures = <String>[];

      for (final vehicle in vehicles) {
        if (!mounted) return;

        try {
          final location = await widget.loadLocation(vehicle.vehicleId);
          if (location != null) {
            updatedVehicles.add(
              VehicleTrackingData(vehicle: vehicle, location: location),
            );
          }
        } on GpsAccessException {
          rethrow;
        } catch (error) {
          failures.add(
            '${vehicle.plate}: ${error.toString().replaceFirst('Exception: ', '')}',
          );
          // Retain this vehicle's last known position during transient failures.
          for (final previous in _trackedVehicles) {
            if (previous.vehicle.vehicleId == vehicle.vehicleId) {
              updatedVehicles.add(
                VehicleTrackingData(
                  vehicle: vehicle,
                  location: previous.location,
                ),
              );
              break;
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _trackedVehicles = updatedVehicles;
        _registeredVehicleCount = vehicles.length;
        _isLoading = false;
        _errorMessage = failures.isEmpty ? null : failures.join('\n');
        if (failures.isEmpty) _lastSuccessfulRefresh = DateTime.now();
      });

      _centerOnFirstVehicle();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        if (error is GpsAccessException) {
          _trackedVehicles = [];
          _registeredVehicleCount = 0;
          _lastSuccessfulRefresh = null;
          _hasCentered = false;
        }
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

  String _tripStatus(GpsLocation location) {
    if (!location.tripContextAvailable) return 'Trip assignment unavailable';
    final trip = location.trip;
    if (trip == null) return 'No scheduled or active trip';
    return 'Trip #${trip.id}: ${trip.status}\n'
        'Scheduled: ${_formatRecordedAt(trip.scheduledDeparture)}'
        '${trip.departureOverdue ? '\nNot started — 5-minute grace period passed' : ''}'
        '${trip.actualDeparture == null ? '' : '\nStarted: ${_formatRecordedAt(trip.actualDeparture!)}'}'
        '${trip.lateMinutes == null ? '' : '\nLate: ${trip.lateMinutes} minute(s)'}';
  }

  String _formatRecordedAt(DateTime recordedAt) {
    final local = recordedAt.toUtc().add(const Duration(hours: 8));

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}:'
        '${twoDigits(local.second)} PHT';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recentCount = _trackedVehicles
        .where((vehicle) => vehicle.location.isRecent)
        .length;
    final onlineCount = _trackedVehicles
        .where(
          (vehicle) =>
              vehicle.vehicle.availabilityStatus == TrackerAvailability.online,
        )
        .length;
    final unstableCount = _trackedVehicles
        .where(
          (vehicle) =>
              vehicle.vehicle.availabilityStatus ==
              TrackerAvailability.unstable,
        )
        .length;
    final unreachableCount = _trackedVehicles
        .where(
          (vehicle) =>
              vehicle.vehicle.availabilityStatus ==
              TrackerAvailability.unreachable,
        )
        .length;
    DateTime? latestGps;
    for (final item in _trackedVehicles) {
      if (latestGps == null || item.location.recordedAt.isAfter(latestGps)) {
        latestGps = item.location.recordedAt;
      }
    }

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
                          'Tracker heartbeat: ${item.vehicle.availabilityStatus.label}\n'
                          'GPS freshness: ${item.location.isRecent ? 'Recent GPS' : 'Outdated GPS'}\n'
                          '${_tripStatus(item.location)}',
                      child: _VehiclePin(
                        isRecent: item.location.isRecent,
                        availabilityStatus: item.vehicle.availabilityStatus,
                      ),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                        if (latestGps != null)
                          Text(
                            'Latest GPS: ${_formatRecordedAt(latestGps)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedDark,
                            ),
                          ),
                        Text(
                          'Mapped tracker heartbeat: $onlineCount online, '
                          '$unstableCount unstable, '
                          '$unreachableCount unreachable',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedDark,
                          ),
                        ),
                        if (_lastSuccessfulRefresh != null)
                          Text(
                            'Last successful refresh: ${_formatRecordedAt(_lastSuccessfulRefresh!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedDark,
                            ),
                          ),
                      ],
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
  const _VehiclePin({required this.isRecent, required this.availabilityStatus});

  final bool isRecent;
  final TrackerAvailability availabilityStatus;

  Color get _availabilityColor => switch (availabilityStatus) {
    TrackerAvailability.online => Colors.green.shade800,
    TrackerAvailability.unstable => Colors.amber.shade900,
    TrackerAvailability.unreachable => Colors.grey.shade800,
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
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
          child: const Center(
            child: Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: _availabilityColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
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
