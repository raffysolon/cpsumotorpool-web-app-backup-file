import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/trip_service.dart';
import 'destination_pin_dialog.dart';

class SavedDestinationsDialog extends StatefulWidget {
  const SavedDestinationsDialog({super.key});

  @override
  State<SavedDestinationsDialog> createState() =>
      _SavedDestinationsDialogState();
}

class _SavedDestinationsDialogState extends State<SavedDestinationsDialog> {
  var _destinations = TripService.getSavedDestinations();

  Future<void> _edit([Map<String, dynamic>? destination]) async {
    var name = '${destination?['name'] ?? ''}';
    final form = GlobalKey<FormState>();
    final selectedName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Destination name'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: name,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'CPSU San Carlos',
            ),
            onChanged: (value) => name = value.trim(),
            validator: (_) =>
                name.trim().isEmpty ? 'Enter a destination name.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, name.trim());
              }
            },
            child: const Text('Choose pin'),
          ),
        ],
      ),
    );
    if (!mounted || selectedName == null) return;
    final point = await showDestinationPinDialog(
      context,
      destination: selectedName,
      initialPin: destination == null
          ? null
          : savedDestinationPoint(destination),
      save: (point) => TripService.saveDestination(
        selectedName,
        point.latitude,
        point.longitude,
        id: destination?['id'] as int?,
      ),
    );
    if (mounted && point != null) _reload();
  }

  void _reload() =>
      setState(() => _destinations = TripService.getSavedDestinations());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Saved Destinations'),
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: FutureBuilder(
        future: _destinations,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return TextButton(
              onPressed: _reload,
              child: const Text('Could not load destinations. Retry'),
            );
          }
          final destinations = snapshot.requireData;
          if (destinations.isEmpty) {
            return const Text(
              'Save a campus or another frequently visited location.',
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final destination in destinations)
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text('${destination['name']}'),
                  trailing: IconButton(
                    tooltip: 'Edit destination',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(destination),
                  ),
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton.icon(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add destination'),
      ),
    ],
  );
}

LatLng savedDestinationPoint(Map<String, dynamic> destination) => LatLng(
  double.parse('${destination['latitude']}'),
  double.parse('${destination['longitude']}'),
);
