// ignore_for_file: implementation_imports
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';
import 'package:cpsumotorpooladmin/widgets/persistent_admin_shell.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/services/api_config.dart';
import 'package:cpsumotorpooladmin/pages/Driver/pages/Dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Fonts implements AssetManifest {
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      '${ApiConfig.storageNamespace}:last_activity': DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
      '${ApiConfig.storageNamespace}:name': 'Test Admin',
      '${ApiConfig.storageNamespace}:auth_token': 'test-token',
      '${ApiConfig.storageNamespace}:role': 'admin',
    });
    GoogleFonts.config.allowRuntimeFetching = false;
    fonts.assetManifest = _Fonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final path = const StringCodec().decodeMessage(message)!;
          final file = File(
            path.startsWith('test/fonts/')
                ? path
                : 'build/unit_test_assets/$path',
          );
          return file.existsSync()
              ? ByteData.sublistView(file.readAsBytesSync())
              : null;
        });
  });

  testWidgets('driver mobile logout clears session and previous routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({
      '${ApiConfig.storageNamespace}:last_activity': DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
      '${ApiConfig.storageNamespace}:auth_token': 'driver-token',
      '${ApiConfig.storageNamespace}:role': 'driver',
      '${ApiConfig.storageNamespace}:name': 'Test Driver',
    });
    final navigator = GlobalKey<NavigatorState>();
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            routes: {
              '/': (_) => const Scaffold(body: Text('Previous route')),
              '/driver-dashboard': (_) => const DriverDashboard(),
              '/login': (_) => const Scaffold(body: Text('Login content')),
            },
          ),
        );
        navigator.currentState!.pushNamed('/driver-dashboard');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Log out'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(await AuthService.getToken(), 'driver-token');
        await tester.tap(find.byTooltip('Log out'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Log out'));
        await tester.pumpAndSettle();
        expect(find.text('Login content'), findsOneWidget);
        expect(await AuthService.getToken(), isNull);
        expect(await AuthService.getRole(), isNull);
        expect(navigator.currentState!.canPop(), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient(
        (_) async => http.Response('{"data":[],"unread_count":0}', 200),
      ),
    );
  });

  for (final width in [1280.0, 390.0]) {
    testWidgets('persistent navigation and centered collapsed logo at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      final navigation = AdminShellNavigation()..authorized = true;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [navigation],
          builder: (context, child) => PersistentAdminShell(
            navigation: navigation,
            navigatorKey: navigator,
            child: child!,
          ),
          routes: {
            '/': (_) => const AppShell(
              currentRoute: '/',
              child: Text('Dashboard content'),
            ),
            '/map': (_) => const AppShell(
              currentRoute: '/map',
              child: Text('Map content'),
            ),
            '/login': (_) => const Scaffold(body: Text('Login content')),
          },
        ),
      );
      await tester.pumpAndSettle();
      if (width < 900) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
      }
      final sidebar = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_Sidebar',
      );
      final originalState = tester.state(sidebar);
      if (width >= 900) {
        await tester.tap(find.byTooltip('Collapse sidebar'));
        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byKey(const ValueKey('sidebar-logo'))).dx,
          closeTo(tester.getCenter(find.byTooltip('Expand sidebar')).dx, 0.1),
        );
      }
      final logoX = tester
          .getCenter(find.byKey(const ValueKey('sidebar-logo')))
          .dx;
      await tester.tap(width >= 900 ? find.byTooltip('Map') : find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.text('Map content'), findsOneWidget);
      if (width < 900) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
      }
      if (width >= 900) expect(tester.state(sidebar), same(originalState));
      expect(
        tester.getCenter(find.byKey(const ValueKey('sidebar-logo'))).dx,
        logoX,
      );
      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      navigator.currentState!.pop(false);
      await tester.pumpAndSettle();
      expect(await AuthService.getToken(), 'test-token');
      if (width >= 900) expect(tester.state(sidebar), same(originalState));
      if (width < 900) {
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log out'));
      await tester.pumpAndSettle();
      expect(await AuthService.getToken(), isNull);
      expect(await AuthService.getRole(), isNull);
      expect(find.text('Login content'), findsOneWidget);
      expect(sidebar, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
    });
  }
}
