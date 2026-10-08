import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/config/app_version.dart';

void main() {
  test('AppVersion.current matches pubspec.yaml (G5 relies on it changing with releases)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(AppVersion.current, version);
  });
}
