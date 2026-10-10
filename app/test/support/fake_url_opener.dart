import 'package:habit/core/url_opener.dart';

/// Records every URL asked for and answers with [result].
class FakeUrlOpener implements UrlOpener {
  bool result;
  final opened = <Uri>[];

  FakeUrlOpener({this.result = true});

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return result;
  }
}
