import 'dart:ui';

import 'package:flutter/material.dart';

class InteractionLoadingOverlay extends StatelessWidget {
  const InteractionLoadingOverlay({super.key, required this.message});

  final String message;

  static final ValueNotifier<String?> activeMessage = ValueNotifier<String?>(
    null,
  );

  static void show(String message) {
    activeMessage.value = message;
  }

  static void hide() {
    activeMessage.value = null;
  }

  static Widget coverApp(Widget child) {
    return ValueListenableBuilder<String?>(
      valueListenable: activeMessage,
      builder: (context, message, _) => Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (message != null) InteractionLoadingOverlay(message: message),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: const ColoredBox(color: Color(0x550F172A)),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 38,
                      height: 38,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF1F8A3D),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1F2933),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
