import 'package:flutter/foundation.dart';

/// A33: where the public Terms of Service and Privacy Policy pages live. The base URL comes
/// from `--dart-define=LEGAL_BASE_URL=...`; the default is the GitHub Pages site the
/// legal-pages workflow publishes.
abstract final class LegalConfig {
  static const String baseUrl = String.fromEnvironment(
    'LEGAL_BASE_URL',
    defaultValue: 'https://khayson.github.io/habit-system',
  );

  static String get termsUrl => '${_trimmed(baseUrl)}/terms/';
  static String get privacyUrl => '${_trimmed(baseUrl)}/privacy/';

  static String _trimmed(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// Called once at start-up, beside ApiConfig.ensureSafe. A release build refuses a
  /// non-HTTPS legal base URL.
  static void ensureSafe({bool isRelease = kReleaseMode, String url = baseUrl}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) {
      throw StateError('LEGAL_BASE_URL is not a valid absolute URL.');
    }
    if (isRelease && uri.scheme != 'https') {
      throw StateError('Release builds require an https:// LEGAL_BASE_URL.');
    }
  }
}

/// A33: the front-matter versions of docs/legal/terms.md and privacy.md this build shows and
/// sends at registration. A test fails when they drift from the documents.
abstract final class LegalVersions {
  static const String terms = '2026-10-10';
  static const String privacy = '2026-10-10';
}
