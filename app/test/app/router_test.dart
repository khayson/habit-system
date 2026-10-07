import 'package:flutter_test/flutter_test.dart';
import 'package:habit/app/router.dart';

void main() {
  test('signed-out users are sent to a public route', () {
    expect(authRedirect(isAuthenticated: false, location: Routes.today), Routes.status);
  });

  test('public routes stay reachable when signed out', () {
    expect(authRedirect(isAuthenticated: false, location: Routes.status), isNull);
  });

  test('signed-in users are not redirected', () {
    expect(authRedirect(isAuthenticated: true, location: Routes.today), isNull);
    expect(authRedirect(isAuthenticated: true, location: Routes.status), isNull);
  });
}
