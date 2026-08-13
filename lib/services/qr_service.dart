/// Thin helper around QR payload interpretation.
/// Live camera scanning is handled in the scan screen via `mobile_scanner`.
class QrService {
  bool looksLikeUrl(String payload) {
    final uri = Uri.tryParse(payload);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool looksLikeBirPayload(String payload) {
    final lower = payload.toLowerCase();
    return lower.contains('tin') ||
        lower.contains('bir') ||
        lower.contains('invoice') ||
        (lower.contains('or') && lower.contains('='));
  }
}
