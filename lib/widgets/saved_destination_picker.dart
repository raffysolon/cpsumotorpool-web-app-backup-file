import 'package:flutter/material.dart';

class SavedDestinationPicker extends StatelessWidget {
  const SavedDestinationPicker({
    super.key,
    required this.destinations,
    required this.controller,
  });

  final Future<List<Map<String, dynamic>>> destinations;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: destinations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Saved destinations unavailable. Enter a destination below.',
            );
          }
          final places = snapshot.data ?? const [];
          if (places.isEmpty) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<String>(
              tooltip: 'Choose a saved destination',
              onSelected: (name) => controller.value = TextEditingValue(
                text: name,
                selection: TextSelection.collapsed(offset: name.length),
              ),
              itemBuilder: (_) => [
                for (final place in places)
                  PopupMenuItem(
                    value: place['name'] as String,
                    child: Text(place['name'] as String),
                  ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('Choose saved destination'),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
