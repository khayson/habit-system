import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/profile_view.dart';
import 'package:habit/l10n/generated/app_localizations.dart';
import 'package:habit/screens/profile_screen.dart';

/// 5.2b review: Profile's Freezes row never says "auto-protect off" before the profile loads.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  ProfileState profile({required bool autoFreeze}) => ProfileState(
    name: 'Maya',
    email: null,
    city: null,
    countryCode: null,
    avatarVersion: 0,
    hasAvatar: false,
    editQueued: false,
    editNeedsAttention: false,
    autoFreeze: autoFreeze,
    photoPath: null,
    uploadPending: false,
    uploadRejected: false,
    unsynced: 0,
  );

  test('before the profile has loaded: the count alone', () {
    expect(freezesRowLine(l10n, 1, null), '1 freeze');
  });

  test('then the switch state in words', () {
    expect(freezesRowLine(l10n, 2, profile(autoFreeze: true)), '2 freezes · auto-protect on');
    expect(freezesRowLine(l10n, 1, profile(autoFreeze: false)), '1 freeze · auto-protect off');
  });

  test('no confirmed numbers yet', () {
    expect(freezesRowLine(l10n, null, null), 'Appears after the first sync');
  });
}
