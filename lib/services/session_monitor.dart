import '../pages/services/auth_service.dart';
import 'api_reads.dart';
import 'api_config.dart';

/// Detects revoked login tokens without treating network failures as logout.
class SessionMonitor {
  bool _checking = false;

  Future<bool> check() async {
    if (_checking) return false;
    _checking = true;
    try {
      if (await AuthService.expireIdleSession()) return true;
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) return false;
      final response = await ApiReads.get(
        ApiConfig.apiUri('user'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        timeout: const Duration(seconds: 10),
      );
      // An old response must not sign out a newly logged-in account.
      if (response.statusCode != 401 || await AuthService.getToken() != token) {
        return false;
      }
      await AuthService.logout();
      return true;
    } catch (_) {
      // Offline, rate limited, or server unavailable: keep the current session.
      return false;
    } finally {
      _checking = false;
    }
  }
}
