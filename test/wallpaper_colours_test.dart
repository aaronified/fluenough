// Wallpaper colours (Android 12 and later): the setting is saved and
// restored, the row is drawn only where the phone gives a palette, and the
// themes follow it, with contrast and pure black on top.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/wallpaper_colours.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/ui/theme.dart';

import 'support/harness.dart';

/// WCAG contrast ratio of two colours.
double ratio(Color a, Color b) {
  final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
}

/// What a phone might draw its palette from: a purple, a blue, a pink, a
/// bright yellow, a cyan, and the greys and extremes a wallpaper can give.
const List<Color> wallpapers = <Color>[
  Color(0xFF6750A4),
  Color(0xFF4285F4),
  Color(0xFFE91E63),
  Color(0xFFFFEB3B),
  Color(0xFF00BCD4),
  Color(0xFF9E9E9E),
  Color(0xFF000000),
  Color(0xFFFFFFFF),
];

void main() {
  const wallpaper = Color(0xFFE91E63);

  group('the setting', () {
    test('is off by default, saved and restored', () {
      expect(SettingsNotifier().dynamicColour, isFalse);
      final on = SettingsNotifier()..dynamicColour = true;
      expect(on.toStored()['dynamic_colour'], 'true');
      final restored = SettingsNotifier()..restore(on.toStored());
      expect(restored.dynamicColour, isTrue);
    });

    test('a backup from before it existed restores as off', () {
      // As Backups.restore does: the stored values over the defaults, so a
      // key the backup lacks reads as its default, not as what is live.
      final live = SettingsNotifier()..dynamicColour = true;
      final old = <String, String>{'seed': 'clay', 'pure_black': 'true'};
      final defaults = SettingsNotifier();
      live.restore(<String, String>{...defaults.toStored(), ...old});
      expect(live.dynamicColour, isFalse);
      expect(live.seed, ThemeSeed.clay);
    });
  });

  group('the phone', () {
    const channel = MethodChannel('wallpaper-test');
    var asked = 0;
    setUp(() {
      asked = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            asked++;
            return call.method == 'wallpaperColour'
                ? 0xFFE91E63 - (1 << 32)
                : null;
          });
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Android gives its colour, as an opaque colour', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        await const ChannelWallpaperSource(channel: channel).read(),
        const Color(0xFFE91E63),
      );
    });

    test('iOS, desktop and the rest are never asked', () async {
      for (final platform in <TargetPlatform>[
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          await const ChannelWallpaperSource(channel: channel).read(),
          isNull,
          reason: '$platform',
        );
      }
      expect(asked, 0);
    });

    test('Android below 12, or an old MainActivity, gives none', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
      expect(
        await const ChannelWallpaperSource(channel: channel).read(),
        isNull,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(
        await const ChannelWallpaperSource(channel: channel).read(),
        isNull,
      );
    });

    test('the colour is read again when it changes', () async {
      final source = FixedWallpaperSource(null);
      final colours = WallpaperColours(source);
      var heard = 0;
      colours.addListener(() => heard++);
      await colours.refresh();
      expect(colours.available, isFalse);
      expect(heard, 0);
      source.colour = wallpaper;
      await colours.refresh();
      expect(colours.seed, wallpaper);
      expect(colours.available, isTrue);
      await colours.refresh();
      expect(heard, 1, reason: 'the same colour is not news');
      colours.dispose();
    });
  });

  group('the row', () {
    testWidgets('is not drawn where the phone gives no palette', (
      tester,
    ) async {
      usePhone(tester);
      // The web, iOS and desktop builds, and Android below 12: no colour.
      final state = AppState.test(
        settings: SettingsNotifier(dynamicColour: true),
        wallpaperSource: FixedWallpaperSource(null),
      );
      await state.wallpaper.refresh();
      await pumpScreen(tester, const AppearancePage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.appearanceWallpaper), findsNothing);
      expect(find.text(l10n.appearanceColourFollowing), findsNothing);
      // The seeds apply, whatever a restored backup says.
      expect(state.wallpaperInUse, isNull);
      expect(find.text(l10n.appearanceSeedForest), findsOneWidget);
    });

    testWidgets('is drawn on Android 12 and switches the app\'s colours', (
      tester,
    ) async {
      usePhone(tester);
      final state = AppState.test(
        settings: SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningChosen: true,
        ),
        wallpaperSource: FixedWallpaperSource(wallpaper),
      );
      await state.wallpaper.refresh();
      await pumpScreen(tester, const AppearancePage(), state: state);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.appearanceWallpaper), findsOneWidget);
      expect(find.text(l10n.appearanceWallpaperOff), findsOneWidget);
      expect(find.text(l10n.appearanceColourFollowing), findsNothing);
      expect(state.wallpaperInUse, isNull, reason: 'off: the seed colour');

      await tester.tap(find.text(l10n.appearanceWallpaper));
      await tester.pumpAndSettle();
      expect(state.settings.dynamicColour, isTrue);
      expect(state.wallpaperInUse, wallpaper);
      expect(find.text(l10n.appearanceWallpaperOn), findsOneWidget);
      expect(find.text(l10n.appearanceColourFollowing), findsOneWidget);
    });

    testWidgets('the whole app is drawn in the wallpaper colours while on', (
      tester,
    ) async {
      usePhone(tester);
      final state = AppState.test(
        settings: SettingsNotifier(
          dynamicColour: true,
          themeMode: ThemeMode.dark,
          pureBlack: true,
        ),
        wallpaperSource: FixedWallpaperSource(wallpaper),
      );
      await pumpApp(tester, state: state);
      final scheme = Theme.of(tester.element(find.byType(Scaffold).first))
          .colorScheme;
      expect(
        scheme.primary,
        ColorScheme.fromSeed(
          seedColor: wallpaper,
          brightness: Brightness.dark,
        ).primary,
      );
      expect(scheme.surface, Colors.black);
      // Off again: the chosen seed.
      state.settings.dynamicColour = false;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first))
            .colorScheme
            .primary,
        ColorScheme.fromSeed(
          seedColor: Color(ThemeSeed.forest.argb),
          brightness: Brightness.dark,
        ).primary,
      );
    });
  });

  group('the themes', () {
    test('follow the wallpaper colour, and the seed without one', () {
      expect(
        AppTheme.light(wallpaper: wallpaper).colorScheme.primary,
        ColorScheme.fromSeed(seedColor: wallpaper).primary,
      );
      expect(
        AppTheme.dark(wallpaper: wallpaper).colorScheme.primary,
        ColorScheme.fromSeed(
          seedColor: wallpaper,
          brightness: Brightness.dark,
        ).primary,
      );
      expect(
        AppTheme.light().colorScheme.primary,
        isNot(AppTheme.light(wallpaper: wallpaper).colorScheme.primary),
      );
      expect(
        AppTheme.light(seed: ThemeSeed.clay).colorScheme.primary,
        ColorScheme.fromSeed(seedColor: Color(ThemeSeed.clay.argb)).primary,
      );
    });

    test('high contrast applies to the wallpaper scheme', () {
      expect(
        AppTheme.light(
          wallpaper: wallpaper,
          highContrast: true,
        ).colorScheme.primary,
        ColorScheme.fromSeed(seedColor: wallpaper, contrastLevel: 1).primary,
      );
    });

    test('pure black goes on top of the wallpaper scheme', () {
      final plain = AppTheme.dark(wallpaper: wallpaper).colorScheme;
      final black = AppTheme.dark(
        wallpaper: wallpaper,
        pureBlack: true,
      ).colorScheme;
      expect(black.surface, Colors.black);
      expect(black.surfaceContainerLowest, Colors.black);
      expect(black.primary, plain.primary);
      expect(plain.surface, isNot(Colors.black));
      // Light ignores it.
      expect(
        AppTheme.light(wallpaper: wallpaper).colorScheme.surface,
        isNot(Colors.black),
      );
    });

    test('a translucent wallpaper colour still makes an opaque scheme', () {
      expect(
        AppTheme.light(wallpaper: const Color(0x80E91E63)).colorScheme.primary,
        AppTheme.light(wallpaper: const Color(0xFFE91E63)).colorScheme.primary,
      );
    });

    test('text stays readable on every wallpaper, light, dark, pure black '
        'and high contrast', () {
      for (final colour in wallpapers) {
        for (final high in <bool>[false, true]) {
          final themes = <String, ThemeData>{
            'light': AppTheme.light(wallpaper: colour, highContrast: high),
            'dark': AppTheme.dark(wallpaper: colour, highContrast: high),
            'black': AppTheme.dark(
              wallpaper: colour,
              highContrast: high,
              pureBlack: true,
            ),
          };
          themes.forEach((name, theme) {
            final s = theme.colorScheme;
            final pairs = <String, (Color, Color)>{
              'primary': (s.primary, s.onPrimary),
              'primaryContainer': (s.primaryContainer, s.onPrimaryContainer),
              'secondary': (s.secondary, s.onSecondary),
              'secondaryContainer': (
                s.secondaryContainer,
                s.onSecondaryContainer,
              ),
              'tertiaryContainer': (s.tertiaryContainer, s.onTertiaryContainer),
              'error': (s.error, s.onError),
              'surface': (s.surface, s.onSurface),
              'surfaceVariant on surface': (s.surface, s.onSurfaceVariant),
              'card tint': (s.surfaceContainer, s.onSurface),
              'card tint, variant text': (
                s.surfaceContainer,
                s.onSurfaceVariant,
              ),
              'inverse': (s.inverseSurface, s.onInverseSurface),
            };
            pairs.forEach((label, pair) {
              expect(
                ratio(pair.$1, pair.$2),
                greaterThanOrEqualTo(4.5),
                reason: '$label, $name, $colour, high contrast $high',
              );
            });
          });
        }
      }
    });

    test('the skill colours and pills do not depend on the wallpaper', () {
      // Each carries its own background and text, so it reads on any scheme.
      for (final colour in wallpapers) {
        expect(
          AppTheme.light(wallpaper: colour).extension<ModeColors>(),
          same(ModeColors.light),
        );
        expect(
          AppTheme.dark(
            wallpaper: colour,
            pureBlack: true,
          ).extension<ModeColors>(),
          same(ModeColors.dark),
        );
      }
      for (final modes in <ModeColors>[
        ModeColors.light,
        ModeColors.dark,
        ModeColors.lightHigh,
        ModeColors.darkHigh,
      ]) {
        for (final c in <ModeColor>[
          modes.recognition,
          modes.production,
          modes.listening,
          modes.speaking,
          modes.grammar,
          modes.reading,
          modes.pair,
          modes.gesture,
          modes.pillLeave,
          modes.pillLearn,
          modes.pillKnow,
          modes.pillVerified,
        ]) {
          expect(ratio(c.container, c.onContainer), greaterThanOrEqualTo(4.5));
        }
      }
    });
  });
}
