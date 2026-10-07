import 'package:flutter_test/flutter_test.dart';
import 'package:habit/app/router.dart';

void main() {
  String? go(String location, {bool signedIn = false, bool setup = false}) =>
      authRedirect(isAuthenticated: signedIn, needsSetup: setup, location: location);

  test('signed-out users are sent to sign in', () {
    expect(go(Routes.today), Routes.signIn);
    expect(go(Routes.queue), Routes.signIn);
    expect(go(Routes.newHabit), Routes.signIn);
  });

  test('public routes stay reachable when signed out', () {
    expect(go(Routes.signIn), isNull);
    expect(go(Routes.createAccount), isNull);
    expect(go(Routes.status), isNull);
  });

  test('signed-in users skip the auth screens', () {
    expect(go(Routes.signIn, signedIn: true), Routes.today);
    expect(go(Routes.createAccount, signedIn: true), Routes.today);
    expect(go(Routes.today, signedIn: true), isNull);
    expect(go(Routes.queue, signedIn: true), isNull);
  });

  test('a new account confirms its timezone (04) before anything else', () {
    expect(go(Routes.today, signedIn: true, setup: true), Routes.setup);
    expect(go(Routes.signIn, signedIn: true, setup: true), Routes.setup);
    expect(go(Routes.setup, signedIn: true, setup: true), isNull);
  });
}
