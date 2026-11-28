import 'package:flutter/material.dart';
import '../services/trip_service.dart';

class SavedDestinationPicker extends StatelessWidget {
  const SavedDestinationPicker({super.key, required this.controller});

  final TextEditingController controller;

  Future<void> _choose(BuildContext context) async {
    final places = TripService.getSavedDestinations();
    final name = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Saved destinations'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: places,
          builder: (_, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                'Could not load saved destinations. Reopen to retry or type a destination.',
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.isEmpty) {
              return const Text(
                'No saved destinations yet. You can type a destination.',
              );
            }
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final place in snapshot.data!)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place['name'] as String),
                      onTap: () =>
                          Navigator.pop(dialog, place['name'] as String),
                    ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (context.mounted && name != null) {
      controller.value = TextEditingValue(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => _choose(context),
      icon: const Icon(Icons.place_outlined),
      label: const Text('Choose saved destination'),
    ),
  );
}
