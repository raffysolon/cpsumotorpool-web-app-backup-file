import 'dart:async';

import 'package:flutter/material.dart';

class AppNotification {
  AppNotification._();

  static final ValueNotifier<AppNotice?> _activeNotice =
      ValueNotifier<AppNotice?>(null);
  static Timer? _dismissTimer;

  static void show(BuildContext context, SnackBar snackBar) {
    if (!context.mounted) return;
    final message = _extractText(snackBar.content).trim();
    showMessage(
      message.isEmpty ? 'Please try again.' : message,
      isSuccess: _isSuccess(snackBar.backgroundColor, message),
      isError: _isError(snackBar.backgroundColor, message),
    );
  }

  static void showMessage(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    _dismissTimer?.cancel();
    _activeNotice.value = AppNotice(
      message: message,
      isSuccess: isSuccess,
      isError: isError,
    );
    _dismissTimer = Timer(const Duration(seconds: 4), dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeNotice.value = null;
  }

  static String _extractText(Widget widget) {
    if (widget is Text) {
      return widget.data ?? widget.textSpan?.toPlainText() ?? '';
    }
    if (widget is RichText) return widget.text.toPlainText();
    if (widget is Flex) {
      return widget.children
          .map(_extractText)
          .where((text) => text.isNotEmpty)
          .join(' ');
    }
    if (widget is Wrap) {
      return widget.children
          .map(_extractText)
          .where((text) => text.isNotEmpty)
          .join(' ');
    }
    return '';
  }

  static bool _isError(Color? color, String message) {
    if (color != null && color.r > color.g * 1.25) return true;
    final lower = message.toLowerCase();
    return lower.startsWith('unable') ||
        lower.startsWith('cannot') ||
        lower.startsWith('invalid') ||
        lower.startsWith('error');
  }

  static bool _isSuccess(Color? color, String message) {
    if (_isError(color, message)) return false;
    if (color != null && color.g > color.r * 1.25) return true;
    final lower = message.toLowerCase();
    return lower.startsWith('success') ||
        lower.contains('successfully') ||
        lower.startsWith('trip approved') ||
        lower.startsWith('trip denied') ||
        lower.startsWith('trip started') ||
        lower.startsWith('trip ended') ||
        lower.startsWith('saved') ||
        lower.startsWith('updated') ||
        lower.startsWith('created') ||
        lower.startsWith('deleted') ||
        lower.endsWith('is ready.');
  }

  static Widget host({required Widget child}) {
    return ValueListenableBuilder<AppNotice?>(
      valueListenable: _activeNotice,
      builder: (context, notice, _) => Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (notice != null) _NoticeBanner(notice: notice),
        ],
      ),
    );
  }
}

class AppNotice {
  const AppNotice({
    required this.message,
    required this.isSuccess,
    required this.isError,
  });

  final String message;
  final bool isSuccess;
  final bool isError;
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.notice});

  final AppNotice notice;

  @override
  Widget build(BuildContext context) {
    final accent = notice.isSuccess
        ? const Color(0xFF1F8A3D)
        : notice.isError
        ? const Color(0xFFB42318)
        : const Color(0xFFB45309);

    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
                decoration: BoxDecoration(
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        notice.isSuccess
                            ? Icons.check_circle_outline_rounded
                            : notice.isError
                            ? Icons.error_outline_rounded
                            : Icons.info_outline_rounded,
                        color: accent,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            notice.isSuccess
                                ? 'All done'
                                : notice.isError
                                ? 'Something went wrong'
                                : 'Please check',
                            style: const TextStyle(
                              color: Color(0xFF1F2933),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notice.message,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      label: 'Dismiss notification',
                      button: true,
                      child: IconButton(
                        onPressed: AppNotification.dismiss,
                        icon: const Icon(Icons.close_rounded, size: 19),
                        color: const Color(0xFF6B7280),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
