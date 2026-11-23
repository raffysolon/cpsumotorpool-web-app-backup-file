// ignore_for_file: implementation_imports
import 'dart:io';
import 'package:cpsumotorpooladmin/widgets/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cpsumotorpooladmin/pages/Admin/pages/Settings.dart';
import 'package:cpsumotorpooladmin/pages/Driver/pages/Settings.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';

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
  tearDown(AppNotification.dismiss);
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

  for (final role in ['admin', 'driver']) {
    testWidgets(
      '$role settings sends email and toggles current password visibility',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({
          'auth_token': 'test-token',
          'role': role,
        });
        var requests = 0;
        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) =>
                    AppNotification.host(child: child!),
                home: role == 'admin'
                    ? const Settings()
                    : const DriverSettings(),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(TextField), findsOneWidget);
            expect(
              tester.widget<TextField>(find.byType(TextField)).obscureText,
              isTrue,
            );
            await tester.ensureVisible(find.byTooltip('Show password'));
            await tester.tap(find.byTooltip('Show password'));
            await tester.pump();
            expect(
              tester.widget<TextField>(find.byType(TextField)).obscureText,
              isFalse,
            );
            await tester.tap(find.byTooltip('Hide password'));
            await tester.pump();
            expect(
              tester.widget<TextField>(find.byType(TextField)).obscureText,
              isTrue,
            );
            await tester.enterText(
              find.byType(TextField),
              'Current-password123!',
            );
            await tester.ensureVisible(find.text('Send password reset email'));
            await tester.tap(find.text('Send password reset email'));
            await tester.pumpAndSettle();
            expect(requests, 1);
            expect(
              find.text(
                'Check your registered email to finish changing your password.',
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            AppNotification.dismiss();
            await tester.pumpWidget(const SizedBox());
          },
          () => MockClient((request) async {
            if (request.url.path.endsWith('/change-password')) {
              requests++;
              expect(request.method, 'PUT');
              expect(request.headers['Authorization'], 'Bearer test-token');
              expect(request.body, contains('current_password'));
              expect(request.body, isNot(contains('email')));
              expect(request.body, isNot(contains('new_password')));
              return http.Response('{}', 200);
            }
            if (request.url.path.endsWith('/user')) {
              return http.Response(
                '{"name":"Test User","email":"test@example.com","role":"$role"}',
                200,
              );
            }
            return http.Response('{"data":[],"unread_count":0}', 200);
          }),
        );
      },
    );
  }
  test('password email errors are reported to the caller', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    await http.runWithClient(
      () async {
        await expectLater(
          AuthService.changePassword('wrong'),
          throwsA(
            isA<LoginException>().having(
              (error) => error.message,
              'message',
              'The current password is incorrect.',
            ),
          ),
        );
      },
      () => MockClient(
        (_) async => http.Response(
          '{"message":"The current password is incorrect."}',
          422,
        ),
      ),
    );
  });
}
