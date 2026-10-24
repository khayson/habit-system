import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a file to the system share sheet so the person chooses where to keep it (A48), from a
/// temporary folder the caller deletes afterwards. A seam: tests use a fake.
abstract interface class FileSharer {
  /// Where a file to share is written first.
  Future<Directory> temporaryRoot();

  Future<void> share(String path);
}

class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<Directory> temporaryRoot() => getTemporaryDirectory();

  @override
  Future<void> share(String path) => SharePlus.instance.share(ShareParams(files: [XFile(path)]));
}
