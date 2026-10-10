import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/config/legal_config.dart';
import 'package:path/path.dart' as p;

/// The front-matter `version:` of a docs/legal document (`flutter test` runs from app/).
String frontMatterVersion(String file) {
  final text = File(p.join('..', 'docs', 'legal', file)).readAsStringSync();
  final front = RegExp(r'^---\r?\n(.*?)\r?\n---', dotAll: true).firstMatch(text)!.group(1)!;
  return RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(front)!.group(1)!;
}

void main() {
  test('A33: the versions sent at registration are the documents\' front-matter versions', () {
    expect(LegalVersions.terms, frontMatterVersion('terms.md'));
    expect(LegalVersions.privacy, frontMatterVersion('privacy.md'));
  });

  test('the page URLs are the base plus /terms/ and /privacy/', () {
    expect(LegalConfig.baseUrl, 'https://khayson.github.io/habit-system');
    expect(LegalConfig.termsUrl, 'https://khayson.github.io/habit-system/terms/');
    expect(LegalConfig.privacyUrl, 'https://khayson.github.io/habit-system/privacy/');
  });

  test('release build refuses a plain-HTTP legal base URL and accepts HTTPS', () {
    expect(
      () => LegalConfig.ensureSafe(isRelease: true, url: 'http://10.0.2.2:8080'),
      throwsStateError,
    );
    expect(
      () => LegalConfig.ensureSafe(isRelease: true, url: 'https://legal.example.com'),
      returnsNormally,
    );
    expect(
      () => LegalConfig.ensureSafe(isRelease: false, url: 'http://10.0.2.2:8080'),
      returnsNormally,
    );
  });

  test('a malformed URL is rejected in any mode; the default is safe for release', () {
    expect(() => LegalConfig.ensureSafe(isRelease: false, url: 'not a url'), throwsStateError);
    expect(() => LegalConfig.ensureSafe(isRelease: true), returnsNormally);
  });
}
