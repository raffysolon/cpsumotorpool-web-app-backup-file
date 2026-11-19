// ignore_for_file: implementation_imports
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:cpsumotorpooladmin/main.dart';
import 'package:cpsumotorpooladmin/pages/feautures/auth/Login.dart';
import 'package:cpsumotorpooladmin/widgets/active_vehicles_map.dart';

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
      'auth_token': 'test-only',
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

  testWidgets('unauthenticated app opens login without exposing fleet data', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'CPSU MotorPool',
    );
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ActiveVehiclesMap), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
