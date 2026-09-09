import 'pdf_opener_stub.dart'
    if (dart.library.html) 'pdf_opener_web.dart' as platform;

Future<void> openPdf(List<int> bytes, int tripId) {
  return platform.openPdf(bytes, tripId);
}

Future<void> downloadPdf(List<int> bytes, int tripId) {
  return platform.downloadPdf(bytes, tripId);
}
