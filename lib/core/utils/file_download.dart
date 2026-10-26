// ─── lib/core/utils/file_download.dart ───────────────────────────────────────
// Cross-platform conditional export for downloading file bytes.
// ─────────────────────────────────────────────────────────────────────────────

export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
