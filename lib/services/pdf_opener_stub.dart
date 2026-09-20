import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'pdf_window_handle.dart';

PdfWindowHandle? openPdfWindow() => null;

Future<void> openPdfInWindow(
  PdfWindowHandle window,
  List<int> bytes,
  int tripId,
) async {
  await openPdf(bytes, tripId);
}

Future<void> openPdf(List<int> bytes, int tripId) async {
  final file = File('${Directory.systemTemp.path}/trip_ticket_$tripId.pdf');
  await file.writeAsBytes(bytes, flush: true);

  final result = await OpenFilex.open(file.path);
  if (result.type == ResultType.done) {
    return;
  }

  try {
    final fallback = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        "Start-Process -FilePath \"${file.path.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}\"",
      ],
    );

    if (fallback.exitCode != 0) {
      throw ProcessException(
        'powershell',
        const [],
        fallback.stderr.toString(),
      );
    }

    return;
  } catch (_) {
    try {
      final fallback = await Process.run(
        'cmd',
        ['/c', 'start', '', file.path],
      );

      if (fallback.exitCode != 0) {
        throw ProcessException(
          'cmd',
          const [],
          fallback.stderr.toString(),
        );
      }

      return;
    } catch (_) {
      throw Exception(result.message.isNotEmpty ? result.message : 'Unable to open the trip ticket PDF.');
    }
  }
}

Future<void> downloadPdf(List<int> bytes, int tripId) async {
  await openPdf(bytes, tripId);
}
