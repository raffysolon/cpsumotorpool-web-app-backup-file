import 'dart:html' as html;

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
