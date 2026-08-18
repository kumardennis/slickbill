import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

Future<String> saveCsvLocally({
  required Uint8List bytes,
  required String filename,
}) async {
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
