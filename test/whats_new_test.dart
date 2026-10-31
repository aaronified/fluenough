// "What's new" after an update (#944; owner, 2026-10-31): the headline of
// each CHANGELOG entry of the installed version, as bullets, shown once on
// the first launch after an update. Not on a fresh install, not for the same
// version, not when the version has nothing to list. It fits at 1.4x text,
// light and dark.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/updates/whats_new.dart';
import 'package:fluenough/features/whats_new/whats_new_prompt.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const String _changelog = '''
# Changelog

## [Unreleased]

### Added

- **Not yet released.** Detail.

## [0.7.1] - 2026-11-07

### Added

- **Situations on Today.** Six buttons open sheets of key phrases (#724).
- Reminders at a time you pick (#90): Settings > Reminders has a switch.

### Fixed

- A long press on a button without text shows a small hint. It is one word.
  A second line of the same entry.
- `tools/prepare_release.py` dates the changelog.

## [0.7.0] - 2026-10-30

### Changed

- `tools/x.py` is faster.
''';

void main() {
  group('the headline of an entry', () {
    test('is the bold lead when the entry starts with one', () {
      expect(
        headlineOf('**Situations on Today.** Six buttons (#724).'),
        'Situations on Today',
      );
    });

    test('is the text before an issue reference in older entries', () {
      expect(
        headlineOf('Situations on Today (#724): six buttons open sheets.'),
        'Situations on Today',
      );
    });

    test(
      'stops at a colon, a full stop or a spaced dash, whichever is first',
      () {
        expect(
          headlineOf('Faster start: the decks are read once.'),
          'Faster start',
        );
        expect(
          headlineOf('A hint on long press. It is one word.'),
          'A hint on long press',
        );
        expect(
          headlineOf('Corners match — one scale of radii.'),
          'Corners match',
        );
      },
    );

    test('is the whole entry when nothing ends it, without marks', () {
      expect(
        headlineOf('A [new page](https://example.org) with `code`'),
        'A new page with code',
      );
    });

    test('is cut at a word with an ellipsis when it is too long', () {
      final long = List<String>.filled(30, 'word').join(' ');
      final headline = headlineOf(long);
      expect(headline.endsWith('…'), isTrue);
      expect(headline.length, lessThanOrEqualTo(maxHeadline + 1));
    });
  });

  group('the headlines of a version', () {
    test('are those of its dated section only, in order, over every ###', () {
      expect(whatsNewHeadlines(_changelog, '0.7.1'), <String>[
        'Situations on Today',
        'Reminders at a time you pick',
        'A long press on a button without text shows a small hint',
      ]);
    });

    test('leave out developer entries and an undated Unreleased', () {
      expect(whatsNewHeadlines(_changelog, '0.7.0'), isEmpty);
      expect(whatsNewHeadlines(_changelog, '0.7.2'), isEmpty);
    });

    test('are empty for something that is not a version', () {
      expect(whatsNewHeadlines(_changelog, 'dev'), isEmpty);
    });
  });

  group('whether it is an update', () {
    test('is only an earlier stored version', () {
      expect(isNewVersionSinceSeen('0.7.0', '0.7.1'), isTrue);
      expect(isNewVersionSinceSeen('0.6.9', '0.7.0'), isTrue);
      expect(isNewVersionSinceSeen(null, '0.7.1'), isFalse);
      expect(isNewVersionSinceSeen('0.7.1', '0.7.1'), isFalse);
      expect(isNewVersionSinceSeen('0.8.0', '0.7.1'), isFalse);
      expect(isNewVersionSinceSeen('junk', '0.7.1'), isFalse);
    });
  });

  group('the sheet at launch', () {
    Future<SettingsNotifier> pump(
      WidgetTester tester, {
      String? seen,
      String version = '0.7.1',
      String changelog = _changelog,
      double textScale = 1.0,
      ThemeMode themeMode = ThemeMode.light,
      void Function()? onLoad,
    }) async {
      usePhone(tester, textScale: textScale);
      final settings = SettingsNotifier()..lastSeenVersion = seen;
      await pumpScreen(
        tester,
        WhatsNewPrompt(
          version: version,
          loadChangelog: () async {
            onLoad?.call();
            return changelog;
          },
          child: const Scaffold(body: Text('shell')),
        ),
        state: AppState.test(settings: settings),
        themeMode: themeMode,
      );
      return settings;
    }

    testWidgets('lists the headlines, the version and one button', (
      tester,
    ) async {
      final settings = await pump(tester, seen: '0.7.0');
      final l10n = l10nOf(tester);
      expect(find.text(l10n.whatsNewTitle), findsOneWidget);
      expect(find.text(l10n.whatsNewVersion('0.7.1')), findsOneWidget);
      expect(find.text('Situations on Today'), findsOneWidget);
      expect(find.text('Reminders at a time you pick'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(settings.lastSeenVersion, '0.7.1');

      await tester.tap(find.text(l10n.whatsNewDone));
      await tester.pumpAndSettle();
      expect(find.text(l10n.whatsNewTitle), findsNothing);
    });

    testWidgets('shows once per version', (tester) async {
      final settings = await pump(tester, seen: '0.7.0');
      await tester.tap(find.text(l10nOf(tester).whatsNewDone));
      await tester.pumpAndSettle();
      // The next launch, on what the last one stored.
      await pump(tester, seen: settings.lastSeenVersion);
      expect(find.text(l10nOf(tester).whatsNewTitle), findsNothing);
    });

    testWidgets('is not shown on a fresh install, which stores the version', (
      tester,
    ) async {
      var loaded = false;
      final settings = await pump(tester, onLoad: () => loaded = true);
      expect(find.text(l10nOf(tester).whatsNewTitle), findsNothing);
      expect(settings.lastSeenVersion, '0.7.1');
      expect(loaded, isFalse);
    });

    testWidgets('is not shown for the same version', (tester) async {
      final settings = await pump(tester, seen: '0.7.1');
      expect(find.text(l10nOf(tester).whatsNewTitle), findsNothing);
      expect(settings.lastSeenVersion, '0.7.1');
    });

    testWidgets('is skipped, and the version stored, when nothing is listed', (
      tester,
    ) async {
      final settings = await pump(tester, seen: '0.6.0', version: '0.7.0');
      expect(find.text(l10nOf(tester).whatsNewTitle), findsNothing);
      expect(settings.lastSeenVersion, '0.7.0');
    });

    for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('fits at 1.4x text, ${mode.name}', (tester) async {
        final long =
            '''
## [0.7.1] - 2026-11-07

${List<String>.generate(12, (i) => '- **Headline number $i is rather long, as a learner might read it on a narrow phone.** Detail.').join('\n')}
''';
        await pump(
          tester,
          seen: '0.7.0',
          changelog: long,
          textScale: 1.4,
          themeMode: mode,
        );
        expect(find.byType(FilledButton), findsOneWidget);
        expect(tester.takeException(), isNull);
        final button = tester.getRect(find.byType(FilledButton));
        final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(button.bottom, lessThanOrEqualTo(screen.height));
        expect(button.left, greaterThanOrEqualTo(0));
        expect(button.right, lessThanOrEqualTo(screen.width));
      });
    }
  });
}
