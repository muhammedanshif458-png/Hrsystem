// ─── lib/core/utils/file_download_stub.dart ──────────────────────────────────
// Non-web fallback stub for file downloads (used during unit tests and CLI).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:typed_data';

void downloadBytes(Uint8List bytes, String fileName, {String? mimeType}) {
  // No-op in test/headless VM environments
}
