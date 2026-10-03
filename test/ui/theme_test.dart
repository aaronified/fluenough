import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/ui/theme.dart';

/// WCAG's contrast ratio between [a] and [b].
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  test('high contrast has its own mode colours, at the contrast ModeColors '
      'claims, on every seed', () {
    for (final seed in ThemeSeed.values) {
      for (final (theme, modes) in <(ThemeData, ModeColors)>[
        (AppTheme.light(seed: seed, highContrast: true), ModeColors.lightHigh),
        (AppTheme.dark(seed: seed, highContrast: true), ModeColors.darkHigh),
      ]) {
        expect(theme.extension<ModeColors>(), same(modes));
        final scheme = theme.colorScheme;
        for (final skill in Skill.values) {
          final colour = modes.forSkill(skill);
          final where = '${seed.name} ${scheme.brightness.name} ${skill.name}';
          expect(
            contrast(colour.container, colour.onContainer),
            greaterThanOrEqualTo(9),
            reason: where,
          );
          // Every surface a mode pill is drawn on: the drill's header and
          // card, Today's due rows and the grouped lists.
          for (final surface in <Color>[
            scheme.surface,
            scheme.surfaceContainerLowest,
            scheme.surfaceContainerLow,
            scheme.surfaceContainer,
            scheme.surfaceContainerHigh,
          ]) {
            expect(
              contrast(colour.container, surface),
              greaterThanOrEqualTo(6),
              reason: where,
            );
          }
        }
      }
    }
  });

  test('standard contrast keeps the design\'s mode colours', () {
    expect(AppTheme.light().extension<ModeColors>(), same(ModeColors.light));
    expect(AppTheme.dark().extension<ModeColors>(), same(ModeColors.dark));
  });

  test('pure black makes only the dark background black, on every seed', () {
    for (final seed in ThemeSeed.values) {
      for (final high in <bool>[false, true]) {
        final black = AppTheme.dark(
          seed: seed,
          highContrast: high,
          pureBlack: true,
        );
        final grey = AppTheme.dark(seed: seed, highContrast: high);
        expect(black.scaffoldBackgroundColor, Colors.black);
        expect(black.colorScheme.surface, Colors.black);
        // Cards and bars keep their tones, so they still stand out.
        expect(
          black.colorScheme.surfaceContainerLow,
          grey.colorScheme.surfaceContainerLow,
        );
        expect(
          contrast(black.colorScheme.onSurface, Colors.black),
          greaterThanOrEqualTo(7),
        );
      }
    }
  });
}
