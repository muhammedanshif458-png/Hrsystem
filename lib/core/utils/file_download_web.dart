// ─── lib/core/utils/file_download_web.dart ──────────────────────────────────
// Web implementation of file download using browser Blob and AnchorElement.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:html' as html;
import 'dart:typed_data';

void downloadBytes(Uint8List bytes, String fileName, {String? mimeType}) {
  final effectiveMimeType = mimeType ??
      (fileName.toLowerCase().endsWith('.pdf')
          ? 'application/pdf'
          : fileName.toLowerCase().endsWith('.png')
              ? 'image/png'
              : fileName.toLowerCase().endsWith('.jpg') ||
                      fileName.toLowerCase().endsWith('.jpeg')
                  ? 'image/jpeg'
                  : 'application/octet-stream');

  final blob = html.Blob([bytes], effectiveMimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
