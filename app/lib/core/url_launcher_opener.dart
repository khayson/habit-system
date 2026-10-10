import 'package:url_launcher/url_launcher.dart';

import 'url_opener.dart';

/// [UrlOpener] over url_launcher: an in-app browser view first, then the browser app.
class UrlLauncherOpener implements UrlOpener {
  const UrlLauncherOpener();

  @override
  Future<bool> open(Uri url) async {
    for (final mode in const [LaunchMode.inAppBrowserView, LaunchMode.externalApplication]) {
      try {
        if (await launchUrl(url, mode: mode)) return true;
      } on Object {
        // No handler for this mode (or the platform refused): try the next one.
      }
    }
    return false;
  }
}
