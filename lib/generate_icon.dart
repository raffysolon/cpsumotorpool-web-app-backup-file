import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Helper script to generate app icon with white rounded background
/// Run this with: flutter run -t lib/generate_icon.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the original icon
  final ByteData data = await rootBundle.load('assets/images/icon.jpg');
  final Uint8List bytes = data.buffer.asUint8List();
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final ui.Image originalImage = frameInfo.image;
  
  // Create the icon with rounded background
  final ui.Image iconWithBackground = await _createIconWithBackground(originalImage);
  
  // Convert to PNG and save
  final ByteData? pngBytes = await iconWithBackground.toByteData(format: ui.ImageByteFormat.png);
  if (pngBytes != null) {
    final File file = File('assets/images/icon_rounded.png');
    await file.writeAsBytes(pngBytes.buffer.asUint8List());
    print('✅ Icon with rounded background saved to: ${file.path}');
    print('Now update pubspec.yaml to use "assets/images/icon_rounded.png"');
  }
  
  exit(0);
}

Future<ui.Image> _createIconWithBackground(ui.Image originalImage) async {
  const int size = 1024;
  const double borderRadius = 180.0; // Rounded corners
  const double padding = 80.0; // Space around the icon
  
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  
  // Draw white rounded rectangle background
  final Paint backgroundPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  
  final RRect roundedRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    const Radius.circular(borderRadius),
  );
  
  canvas.drawRRect(roundedRect, backgroundPaint);
  
  // Draw the original icon centered with padding
  final Rect destRect = Rect.fromLTWH(
    padding,
    padding,
    size - (padding * 2),
    size - (padding * 2),
  );
  
  final Rect srcRect = Rect.fromLTWH(
    0,
    0,
    originalImage.width.toDouble(),
    originalImage.height.toDouble(),
  );
  
  canvas.drawImageRect(originalImage, srcRect, destRect, Paint());
  
  // Convert to image
  final ui.Picture picture = recorder.endRecording();
  return await picture.toImage(size, size);
}
