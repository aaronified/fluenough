import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Decks download the first time a language is chosen (ADR-0037), so the
/// app is not offline from the start. Where the interface says it works
/// offline, it must say once what is downloaded. This pins the claim, not
/// the wording.
void main() {
  test('every "works offline" says it needs its decks first', () {
    final arb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, Object?>;
    final claims = <String, String>{
      for (final MapEntry(:key, :value) in arb.entries)
        if (!key.startsWith('@') &&
            value is String &&
            value.toLowerCase().contains('works') &&
            value.toLowerCase().contains('offline'))
          key: value,
    };
    expect(
      claims.keys,
      containsAll(<String>['onboardingWelcomeNote', 'settingsFooter']),
    );
    for (final MapEntry(:key, :value) in claims.entries) {
      expect(
        value.toLowerCase(),
        isNot(contains('fully offline')),
        reason: '$key promises more than the app does',
      );
      expect(
        value.toLowerCase(),
        contains('download'),
        reason: '$key says the app works offline without saying when',
      );
    }
  });
}
