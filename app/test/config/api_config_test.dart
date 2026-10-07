import 'package:flutter_test/flutter_test.dart';
import 'package:habit/config/api_config.dart';

void main() {
  test('release build refuses a plain-HTTP API', () {
    expect(
      () => ApiConfig.ensureSafe(isRelease: true, url: 'http://10.0.2.2:8000/api/v1'),
      throwsStateError,
    );
  });

  test('release build accepts HTTPS', () {
    expect(
      () => ApiConfig.ensureSafe(isRelease: true, url: 'https://api.example.com/api/v1'),
      returnsNormally,
    );
  });

  test('debug build may use the emulator host over HTTP', () {
    expect(
      () => ApiConfig.ensureSafe(isRelease: false, url: 'http://10.0.2.2:8000/api/v1'),
      returnsNormally,
    );
  });

  test('a malformed URL is rejected in any mode', () {
    expect(() => ApiConfig.ensureSafe(isRelease: false, url: 'not a url'), throwsStateError);
  });

  test('the compiled-in default is valid for debug', () {
    expect(() => ApiConfig.ensureSafe(isRelease: false), returnsNormally);
  });
}
