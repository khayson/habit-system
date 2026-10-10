/// Opens a web page outside the app's own screens. Pure seam: the url_launcher implementation
/// lives in url_launcher_opener.dart and tests use a fake.
abstract interface class UrlOpener {
  /// True when a browser view or browser app took the page. Never throws.
  Future<bool> open(Uri url);
}
