import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/trip_service.dart';
import 'app_shell.dart';

class RecordedTripRoute extends StatefulWidget {
  const RecordedTripRoute({super.key, required this.tripId});

  final int tripId;

  @override
  State<RecordedTripRoute> createState() => _RecordedTripRouteState();
}

class _RecordedTripRouteState extends State<RecordedTripRoute> {
  late var _route = TripService.getRecordedRoute(widget.tripId);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _route,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unable to load the recorded route.'),
            TextButton(
              onPressed: () => setState(
                () => _route = TripService.getRecordedRoute(widget.tripId),
              ),
              child: const Text('Retry'),
            ),
          ],
        );
      }

      final route = snapshot.requireData;
      final legs = (route['legs'] as List).cast<Map<String, dynamic>>();
      final lines = <Polyline>[];
      final markers = <Marker>[];
      final points = <LatLng>[];
      var hasOutbound = false;
      var hasReturn = false;
      for (final leg in legs) {
        final samples = (leg['points'] as List).cast<Map<String, dynamic>>();
        if (samples.isEmpty) continue;
        final outbound = leg['movement_no'] == 1;
        if (outbound) {
          hasOutbound = true;
        } else {
          hasReturn = true;
        }
        final label = outbound ? 'Outbound' : 'Return';
        final color = outbound ? AppColors.primaryDark : Colors.blue.shade800;
        var segment = <LatLng>[];
        DateTime? previousTime;
        for (final sample in samples) {
          final point = LatLng(
            (sample['latitude'] as num).toDouble(),
            (sample['longitude'] as num).toDouble(),
          );
          final time = DateTime.parse(sample['recorded_at'] as String);
          if (previousTime != null &&
              time.difference(previousTime) > const Duration(minutes: 2)) {
            _addSegment(segment, color, lines, markers);
            segment = [];
          }
          points.add(point);
          segment.add(point);
          previousTime = time;
        }
        _addSegment(segment, color, lines, markers);
        final first = samples.first;
        markers.add(
          _marker(
            LatLng(
              (first['latitude'] as num).toDouble(),
              (first['longitude'] as num).toDouble(),
            ),
            color,
            Icons.trip_origin,
            '$label first GPS point',
          ),
        );
        if (samples.length > 1) {
          markers.add(
            _marker(points.last, color, Icons.flag, '$label last GPS point'),
          );
        }
      }

      if (points.isEmpty) {
        return Text(switch (route['reason']) {
          'vehicle_missing' => 'This trip has no recorded vehicle.',
          'actual_times_missing' =>
            'Actual departure and arrival times are unavailable for this trip.',
          _ => 'No GPS points have been uploaded for this trip yet.',
        });
      }

      final distinct = points.toSet();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: points.first,
                  initialZoom: 15,
                  initialCameraFit: distinct.length > 1
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(points),
                          padding: const EdgeInsets.all(36),
                          maxZoom: 16,
                        )
                      : null,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.cpsumotorpooladmin',
                  ),
                  PolylineLayer(polylines: lines),
                  MarkerLayer(markers: markers),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: ColoredBox(
                      color: Colors.white,
                      child: Text('© OpenStreetMap contributors'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              if (hasOutbound)
                const Text(
                  'Outbound',
                  style: TextStyle(color: AppColors.primaryDark),
                ),
              if (hasReturn)
                Text('Return', style: TextStyle(color: Colors.blue.shade800)),
            ],
          ),
          Text(
            lines.isEmpty
                ? 'Only isolated GPS points were recorded.'
                : 'The line breaks where more than two minutes passed between GPS readings.',
          ),
        ],
      );
    },
  );

  void _addSegment(
    List<LatLng> points,
    Color color,
    List<Polyline> lines,
    List<Marker> markers,
  ) {
    if (points.length == 1) {
      markers.add(
        _marker(points.single, color, Icons.circle, 'Recorded GPS point'),
      );
    } else {
      lines.add(Polyline(points: points, color: color, strokeWidth: 4));
    }
  }

  Marker _marker(LatLng point, Color color, IconData icon, String label) =>
      Marker(
        point: point,
        child: Tooltip(
          message: label,
          child: Icon(icon, color: color, semanticLabel: label),
        ),
      );
}
