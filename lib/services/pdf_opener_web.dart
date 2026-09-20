import 'dart:html' as html;
import 'pdf_window_handle.dart';

class _WebPdfWindowHandle implements PdfWindowHandle {
  _WebPdfWindowHandle(this._window);

  final html.WindowBase _window;

  @override
  void setLocation(String url) {
    _window.location.href = url;
  }

  @override
  void close() {
    _window.close();
  }
}

PdfWindowHandle? openPdfWindow() {
  final dynamic window = html.window.open('', '_blank');
  return window == null
      ? null
      : _WebPdfWindowHandle(window as html.WindowBase);
}

Future<void> openPdfInWindow(
  PdfWindowHandle window,
  List<int> bytes,
  int tripId,
) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  window.setLocation(url);
}

Future<void> openPdf(List<int> bytes, int tripId) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

Future<void> downloadPdf(List<int> bytes, int tripId) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = 'trip_ticket_$tripId.pdf'
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}
