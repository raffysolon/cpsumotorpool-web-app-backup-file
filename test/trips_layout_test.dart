// ignore_for_file: implementation_imports
import 'package:cpsumotorpooladmin/services/api_config.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cpsumotorpooladmin/pages/Admin/pages/Activetrip.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/AdminCreateTripTicket.dart'
    show AdminCreateTripTicketPage;
import 'package:cpsumotorpooladmin/pages/Admin/pages/TripRequest.dart';
import 'package:cpsumotorpooladmin/widgets/trips_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TestFontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    'test/fonts/Play-Regular.ttf',
    'test/fonts/Play-Bold.ttf',
  ];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final textFont = FontLoader('Play')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('test/fonts/Play-Regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await Future.wait([textFont.load(), icons.load()]);
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      '${ApiConfig.storageNamespace}:auth_token': 'test-only',
      'name': 'Admin User',
    });
    GoogleFonts.config.allowRuntimeFetching = false;
    fonts.assetManifest = _TestFontManifest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final path = const StringCodec().decodeMessage(message)!;
          final file = File(
            path.startsWith('test/fonts/')
                ? path
                : 'build/unit_test_assets/$path',
          );
          if (!file.existsSync()) return null;
          return ByteData.sublistView(file.readAsBytesSync());
        });
  });

  for (final width in [390.0, 1536.0]) {
    for (final entry in <String, Widget>{
      'requests': const TripRequest(),
      'active': const ActiveTrip(),
      'tickets': const AdminCreateTripTicketPage(),
    }.entries) {
      testWidgets('${entry.key} has one heading and fits width $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await http.runWithClient(
          () async {
            const boundaryKey = Key('page-capture');
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  fontFamily: 'Play',
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF1F8A3D),
                  ),
                ),
                home: RepaintBoundary(key: boundaryKey, child: entry.value),
              ),
            );
            // Allow mocked requests, asset loading, and entrance animations to finish.
            await tester.pumpAndSettle();
            await tester.runAsync(() => GoogleFonts.pendingFonts());
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.textContaining('Province of Negros'), findsNothing);
            expect(find.text('Scheduled and Active Trips'), findsNothing);
            final heading = find.descendant(
              of: find.byType(TripsShell),
              matching: find.text('Trips'),
            );
            // Desktop also has the sidebar label; the content itself has one heading.
            expect(heading, width >= 900 ? findsNWidgets(2) : findsOneWidget);
            expect(find.byType(TripsTabs), findsOneWidget);
            if (width >= 900 && entry.key == 'active') {
              await tester.tap(find.byTooltip('Collapse sidebar'));
              await tester.pumpAndSettle();
              expect(find.byTooltip('Expand sidebar'), findsOneWidget);
              expect(find.text('Dashboard'), findsNothing);
              expect(find.byTooltip('Dashboard'), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.tap(find.byTooltip('Expand sidebar'));
              await tester.pumpAndSettle();
              expect(find.text('Dashboard'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
            if (width < 900 && entry.key == 'active') {
              await tester.tap(find.byTooltip('Open navigation menu'));
              await tester.pumpAndSettle();
              expect(find.byTooltip('Close menu'), findsOneWidget);
              await tester.tap(find.byTooltip('Close menu'));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }

            expect(find.text('Trip Requests'), findsOneWidget);
            expect(find.text('Scheduled & Active'), findsOneWidget);
            expect(find.text('Trip Tickets'), findsOneWidget);
            if (entry.key == 'tickets') {
              expect(find.text('Create Trip Ticket'), findsOneWidget);
            }
            if (const bool.fromEnvironment('CAPTURE_LAYOUT')) {
              await tester.runAsync(() async {
                final boundary = tester.renderObject<RenderRepaintBoundary>(
                  find.byKey(boundaryKey),
                );
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'build/trips-review/${entry.key}-${width.toInt()}.png',
                );
                file.parent.createSync(recursive: true);
                file.writeAsBytesSync(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          },
          () => MockClient((request) async {
            expect(request.method, 'GET');
            return http.Response(
              '{"data":[]}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
      });
    }
  }
}
