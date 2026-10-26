import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/l10n/generated/app_localizations_en.dart';
import 'package:habit/widgets/error_text.dart';

import '../support/contract_fixtures.dart';

/// A58: a suspended account's sign-in reads the app's own calm line, not the server's text.
void main() {
  test('account_suspended reads the app\'s own line', () {
    final fixture = contractFixture('envelope/error_403_account_suspended.json');
    final e = AppException.fromResponse(
      fixture['status'] as int,
      materialize(fixture['body']) as Map<String, dynamic>,
    );
    expect(
      formErrorText(AppLocalizationsEn(), e),
      'This account is paused. To ask about it, contact the Habit team.',
    );
  });
}
