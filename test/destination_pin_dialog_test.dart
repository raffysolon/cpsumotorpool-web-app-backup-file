import 'package:cpsumotorpooladmin/widgets/destination_pin_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('map controller stays usable during the dialog exit animation', (
    tester,
  ) async {
    const pin = LatLng(10.5, 123.4);
    LatLng? saved;
    LatLng? returned;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                returned = await showDestinationPinDialog(
                  context,
                  destination: 'Campus',
                  initialPin: pin,
                  save: (point) async {
                    saved = point;
                  },
                );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    await tester.tap(find.text('Save pin'));
    await tester.pump();
    expect(saved, pin);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(() => map.mapController!.move(pin, 18), returnsNormally);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(returned, pin);
  });
}
