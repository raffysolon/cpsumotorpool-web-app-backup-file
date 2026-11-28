import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/trip_service.dart';

Future<LatLng?> showDestinationPinDialog(
  BuildContext context, {
  required String destination,
  required LatLng? initialPin,
  required Future<void> Function(LatLng) save,
  Future<List<Map<String, dynamic>>>? savedDestinations,
}) async {
  var pin = initialPin;
  const mapTilerKey = String.fromEnvironment('MAPTILER_API_KEY');
  var satellite = mapTilerKey.isNotEmpty;
  final mapController = MapController();
  var saving = false;
  String? error;
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<LatLng>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => PopScope(
        canPop: !saving,
        child: AlertDialog(
          title: Text('Set destination pin: $destination'),
          scrollable: true,
          content: SizedBox(
            width: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (savedDestinations != null)
                  FutureBuilder(
                    future: savedDestinations,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          'Saved destinations are unavailable. You can still choose a pin on the map.',
                        );
                      }
                      final destinations = snapshot.data;
                      if (destinations == null || destinations.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return DropdownButton<int>(
                        isExpanded: true,
                        hint: const Text('Choose a saved destination'),
                        items: [
                          for (var i = 0; i < destinations.length; i++)
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                '${destinations[i]['name']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (index) {
                                if (index == null) return;
                                final destination = destinations[index];
                                final point = LatLng(
                                  double.parse('${destination['latitude']}'),
                                  double.parse('${destination['longitude']}'),
                                );
                                setState(() => pin = point);
                                mapController.move(point, 17);
                              },
                      );
                    },
                  ),
                if (mapTilerKey.isNotEmpty)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Street')),
                      ButtonSegment(value: true, label: Text('Satellite')),
                    ],
                    selected: {satellite},
                    onSelectionChanged: (selection) =>
                        setState(() => satellite = selection.single),
                  ),
                const Text(
                  'Use + to see street names, then tap the exact destination.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: (MediaQuery.sizeOf(context).height * 0.55)
                      .clamp(230.0, 540.0)
                      .toDouble(),
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: initialPin ?? const LatLng(10.30, 123.00),
                      initialZoom: initialPin == null ? 10 : 17,
                      minZoom: 5,
                      maxZoom: 19,
                      onTap: (_, position) {
                        if (!saving) setState(() => pin = position);
                      },
                    ),
                    children: [
                      TileLayer(
                        key: ValueKey(satellite),
                        urlTemplate: satellite
                            ? 'https://api.maptiler.com/maps/hybrid-v4/{z}/{x}/{y}.png?key=${Uri.encodeQueryComponent(mapTilerKey)}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.cpsumotorpooladmin',
                      ),
                      if (pin != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: pin!,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ColoredBox(
                          color: Colors.white,
                          child: Text(
                            satellite
                                ? '© MapTiler © OpenStreetMap contributors'
                                : '© OpenStreetMap contributors',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          elevation: 2,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final step in [1.0, -1.0])
                                IconButton(
                                  tooltip: step > 0 ? 'Zoom in' : 'Zoom out',
                                  icon: Icon(
                                    step > 0 ? Icons.add : Icons.remove,
                                  ),
                                  onPressed: () {
                                    final camera = mapController.camera;
                                    mapController.move(
                                      camera.center,
                                      (camera.zoom + step)
                                          .clamp(5.0, 19.0)
                                          .toDouble(),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving || pin == null
                  ? null
                  : () async {
                      final selected = pin!;
                      setState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await save(selected);
                        if (context.mounted &&
                            ModalRoute.of(context)?.isCurrent == true) {
                          Navigator.pop(context, selected);
                        }
                      } catch (failure) {
                        if (context.mounted) {
                          setState(() {
                            saving = false;
                            error = failure is DestinationPinException
                                ? failure.message
                                : 'Could not save the pin. Check your connection and try again.';
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save pin'),
            ),
          ],
        ),
      ),
    ),
  );
  final result = navigator.push(route);
  try {
    return await result;
  } finally {
    // The map remains mounted during the dialog's exit animation.
    await route.completed;
    mapController.dispose();
  }
}
