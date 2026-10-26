import 'package:flutter/foundation.dart';

/// This build's version, as in pubspec.yaml (a test keeps the two equal). Stored per account
/// database so an update can replay items an older build could not decode (G5).
abstract final class AppVersion {
  static const String current = '1.0.0+1';

  /// A54: the build number (the `+N` of [current]); the server's min_app_version is compared
  /// with it.
  static const int build = 1;

  /// The download page (A54); `--dart-define=DOWNLOAD_PAGE_URL=...` for a release build.
  static const String downloadPageUrl = String.fromEnvironment(
    'DOWNLOAD_PAGE_URL',
    defaultValue: 'https://khayson.github.io/habit-system/download/',
  );

  /// Called once at start-up, beside ApiConfig.ensureSafe. A release build refuses a
  /// non-HTTPS download page.
  static void ensureSafe({bool isRelease = kReleaseMode, String url = downloadPageUrl}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) {
      throw StateError('DOWNLOAD_PAGE_URL is not a valid absolute URL.');
    }
    if (isRelease && uri.scheme != 'https') {
      throw StateError('Release builds require an https:// DOWNLOAD_PAGE_URL.');
    }
  }
}
