// ignore_for_file: implementation_imports
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/SnycLogs.dart';
import 'package:cpsumotorpooladmin/services/gps_service.dart';
import 'package:cpsumotorpooladmin/services/gps_sync_service.dart';
import 'package:cpsumotorpooladmin/services/api_config.dart';

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
  test('sync service requests the selected page with authentication', () async {
    await http.runWithClient(
      () async {
        final result = await GpsSyncService.getLogs(2);
        expect(result['data'], isEmpty);
      },
      () => MockClient((request) async {
        expect(request.url.path, '/api/gps/sync-logs');
        expect(request.url.queryParameters['page'], '2');
        expect(request.headers['Authorization'], 'Bearer test-only');
        return http.Response('{"data":[],"last_page":2}', 200);
      }),
    );
  });
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

  testWidgets(
    'sync records paginate, retain on failure and clear on access loss',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var calls = 0;
      Object? failure;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: SyncLogs(
                loadLogs: (page) async {
                  calls++;
                  if (failure != null) throw failure!;
                  return {
                    'last_page': 2,
                    'data': [
                      {
                        'device': {'device_id': 'REAL-TRACKER-$page'},
                        'recorded_at': '2026-11-18T01:00:00Z',
                        'latitude': 10.5,
                        'longitude': 123.4,
                        'satellites': 12,
                      },
                    ],
                  };
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('REAL-TRACKER-1'), findsOneWidget);
          expect(find.text('10.5, 123.4'), findsNothing);
          await tester.tap(find.text('REAL-TRACKER-1'));
          await tester.pumpAndSettle();
          expect(find.text('2026-11-18 09:00:00 PHT'), findsOneWidget);
          expect(find.text('GPS-001'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Next'));
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
          expect(find.text('REAL-TRACKER-2'), findsOneWidget);
          expect(find.text('Page 2 of 2'), findsOneWidget);
          failure = Exception('Temporary outage');
          await tester.tap(find.text('Refresh'));
          await tester.pumpAndSettle();
          expect(find.text('Temporary outage'), findsOneWidget);
          expect(find.text('REAL-TRACKER-2'), findsOneWidget);
          final beforeHidden = calls;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          await tester.pump(const Duration(seconds: 30));
          expect(calls, beforeHidden);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          failure = const GpsAccessException('Please log in again.');
          await tester.tap(find.text('Refresh'));
          await tester.pumpAndSettle();
          expect(find.text('REAL-TRACKER-2'), findsNothing);
          expect(find.text('Please log in again.'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient(
          (request) async => http.Response(
            request.url.path.endsWith('unread-count') ? '{"count":0}' : '[]',
            200,
          ),
        ),
      );
    },
  );

  testWidgets('empty live response displays no sample records', (tester) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: SyncLogs(loadLogs: (_) async => {'data': [], 'last_page': 1}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No GPS records received yet.'), findsOneWidget);
        expect(find.byType(DataTable), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('unread-count') ? '{"count":0}' : '[]',
          200,
        ),
      ),
    );
  });
}
