import 'pdf_opener_stub.dart'
    if (dart.library.html) 'pdf_opener_web.dart' as platform;
import 'pdf_window_handle.dart';

PdfWindowHandle? openPdfWindow() {
  return platform.openPdfWindow();
}

Future<void> openPdfInWindow(
  PdfWindowHandle window,
  List<int> bytes,
  int tripId,
) {
  return platform.openPdfInWindow(window, bytes, tripId);
}

Future<void> openPdf(List<int> bytes, int tripId) {
  return platform.openPdf(bytes, tripId);
}

Future<void> downloadPdf(List<int> bytes, int tripId) {
  return platform.downloadPdf(bytes, tripId);
}
