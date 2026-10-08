/// This build's version, as in pubspec.yaml (a test keeps the two equal). Stored per account
/// database so an update can replay items an older build could not decode (G5).
abstract final class AppVersion {
  static const String current = '0.1.0+1';
}
