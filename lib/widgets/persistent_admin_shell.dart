import 'package:flutter/material.dart';

import 'app_shell.dart';

/// Tracks page routes only: dialogs must not hide or recreate the sidebar.
class AdminShellNavigation extends NavigatorObserver with ChangeNotifier {
  static const routes = {
    '/',
    '/trip-request',
    '/approval-letter',
    '/active-trips',
    '/map',
    '/vehicles',
    '/devices',
    '/coordinator-assignments',
    '/trip-history',
    '/sync-logs',
    '/settings',
  };

  String? currentRoute;
  bool authorized = false;
  bool _scheduled = false;
  bool _disposed = false;

  bool get visible => authorized && routes.contains(currentRoute);

  void authorize() {
    authorized = true;
    _notifyAfterFrame();
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (topRoute is! PageRoute) return;
    currentRoute = topRoute.settings.name;
    if (!routes.contains(currentRoute)) authorized = false;
    _notifyAfterFrame();
  }

  void _notifyAfterFrame() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Lives above the route Navigator, so only page content participates in routes.
class PersistentAdminShell extends StatelessWidget {
  const PersistentAdminShell({
    super.key,
    required this.navigation,
    required this.navigatorKey,
    required this.child,
  });

  final AdminShellNavigation navigation;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => _ShellOverlay(
    child: ListenableBuilder(
      listenable: navigation,
      builder: (context, _) => AdminShellScope(
        hosted: navigation.visible,
        currentRoute: navigation.currentRoute,
        authorize: navigation.authorize,
        child: navigation.visible
            ? AppShell(
                persistentHost: true,
                navigatorKey: navigatorKey,
                currentRoute:
                    const {
                      '/trip-request',
                      '/approval-letter',
                    }.contains(navigation.currentRoute)
                    ? '/active-trips'
                    : navigation.currentRoute!,
                child: child,
              )
            : child,
      ),
    ),
  );
}

/// Tooltips in the sidebar need an overlay above the page Navigator.
class _ShellOverlay extends StatefulWidget {
  const _ShellOverlay({required this.child});
  final Widget child;
  @override
  State<_ShellOverlay> createState() => _ShellOverlayState();
}

class _ShellOverlayState extends State<_ShellOverlay> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);
  @override
  void didUpdateWidget(_ShellOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
