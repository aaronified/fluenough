import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/app/stored_settings.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/match_hear_toggle.dart';
import 'package:fluenough/ui/widgets/speaker.dart';

import '../../support/harness.dart';

/// Tap to hear in match pairs (ADR-0032): its own setting, on by default and
/// remembered, switched by one speaker button on the card. While it is on, a
/// word tile tapped says its word, whatever Play words automatically says;
/// a meaning never speaks; sound off in Settings still wins.

const String spanish = 'es-en-core-100';

AppState voiced({SettingsNotifier? settings, FixedTtsEngine? tts}) =>
    AppState.test(
      tts: tts ?? FixedTtsEngine(const <String>{'es'}),
      settings: settings,
    );

/// Settings past the first launch, with [change] made.
SettingsNotifier settingsWith(void Function(SettingsNotifier s) change) {
  final s = SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningChosen: true,
  );
  change(s);
  return s;
}

Future<AppState> pumpMatch(WidgetTester tester, {required AppState state}) =>
    pumpScreen(
      tester,
      DrillPage(
        key: UniqueKey(),
        request: DrillRequest.untaught(spanish, skill: Skill.recognition),
        preset: const DrillPreset(target: 'la casa', ask: Ask.matchPairs),
      ),
      state: state,
    );

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapToggle(WidgetTester tester) async {
  await tester.tap(find.byType(MatchHearToggle));
  await tester.pumpAndSettle();
}

Finder get toggle => find.byType(MatchHearToggle);

/// What the toggle's tooltip says.
String tooltipOf(WidgetTester tester) => tester
    .widget<Tooltip>(
      find.descendant(of: toggle, matching: find.byType(Tooltip)),
    )
    .message!;

/// The toggle's icon, or null if it has none.
IconData? iconOf(WidgetTester tester) => tester
    .widget<Icon>(find.descendant(of: toggle, matching: find.byType(Icon)))
    .icon;

/// The words of the match on screen, with their meanings.
List<({String word, String meaning})> pairsOf(
  WidgetTester tester,
) => <({String word, String meaning})>[
  for (final entry
      in tester.widget<MatchDrill>(find.byType(MatchDrill)).session.item.group)
    (word: entry.card.target, meaning: entry.card.native),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the setting', () {
    test('is on by default, and independent of Play words automatically', () {
      final s = SettingsNotifier();
      expect(s.matchTapToHear, isTrue);
      expect(s.autoplay, isFalse);
      expect(s.toStored()['match_tap_to_hear'], 'true');
      // Switching one leaves the other as it was.
      s.autoplay = true;
      expect(s.matchTapToHear, isTrue);
      s.matchTapToHear = false;
      expect(s.autoplay, isTrue);
      s.autoplay = false;
      expect(s.matchTapToHear, isFalse);
    });

    test('survives toStored and restore, off as well as on', () {
      final off = SettingsNotifier()..matchTapToHear = false;
      // Saved at all: a key left out would round-trip as its default.
      expect(off.toStored()['match_tap_to_hear'], 'false');
      final restored = SettingsNotifier()..restore(off.toStored());
      expect(restored.matchTapToHear, isFalse);
      expect(restored.toStored(), off.toStored());

      final on = SettingsNotifier()..restore(SettingsNotifier().toStored());
      expect(on.matchTapToHear, isTrue);
    });

    test(
      'is on for settings stored before it existed, and when unreadable',
      () {
        expect((SettingsNotifier()..restore(const {})).matchTapToHear, isTrue);
        final s = SettingsNotifier()
          ..restore(const <String, String>{
            'autoplay': 'true',
            'match_tap_to_hear': 'sometimes',
          });
        expect(s.matchTapToHear, isTrue);
        expect(s.autoplay, isTrue);
      },
    );

    test('notifies only when it changes', () {
      final s = SettingsNotifier();
      var notified = 0;
      s.addListener(() => notified++);
      s.matchTapToHear = true;
      expect(notified, 0);
      s.matchTapToHear = false;
      expect(notified, 1);
    });

    test('is remembered between sessions, in the profile database', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final first = await StoredSettings.open(db);
      expect(first.settings.matchTapToHear, isTrue);
      first.settings.matchTapToHear = false;
      await first.flush();
      expect((await db.settingsDao.all())['match_tap_to_hear'], 'false');

      final second = await StoredSettings.open(db);
      expect(second.settings.matchTapToHear, isFalse);
      second.settings.matchTapToHear = true;
      await second.flush();

      final third = await StoredSettings.open(db);
      expect(third.settings.matchTapToHear, isTrue);
    });
  });

  group('a word tile', () {
    testWidgets('says its word when tapped, by default, whatever Play words '
        'automatically says', (tester) async {
      usePhone(tester);
      for (final autoplay in <bool>[false, true]) {
        final tts = FixedTtsEngine(const <String>{'es'});
        await pumpMatch(
          tester,
          state: voiced(
            tts: tts,
            settings: settingsWith((s) => s.autoplay = autoplay),
          ),
        );
        expect(find.byType(MatchDrill), findsOneWidget);
        expect(tts.spoken, isEmpty, reason: 'not before it is tapped');
        final pairs = pairsOf(tester);

        await tapText(tester, pairs[0].word);
        expect(tts.spoken.map((s) => s.text), <String>[
          pairs[0].word,
        ], reason: 'autoplay $autoplay');
        expect(tts.spoken.single.bcp47, startsWith('es'));

        // Every word tile does, the first tap or a later one.
        await tapText(tester, pairs[1].word);
        expect(tts.spoken.map((s) => s.text), <String>[
          pairs[0].word,
          pairs[1].word,
        ], reason: 'autoplay $autoplay');
      }
    });

    testWidgets('says nothing when tapped with the setting off, whatever '
        'Play words automatically says', (tester) async {
      usePhone(tester);
      for (final autoplay in <bool>[false, true]) {
        final tts = FixedTtsEngine(const <String>{'es'});
        await pumpMatch(
          tester,
          state: voiced(
            tts: tts,
            settings: settingsWith((s) {
              s.matchTapToHear = false;
              s.autoplay = autoplay;
            }),
          ),
        );
        for (final pair in pairsOf(tester)) {
          await tapText(tester, pair.word);
          // Selected, then tapped again to let it go.
          await tapText(tester, pair.word);
        }
        expect(tts.spoken, isEmpty, reason: 'autoplay $autoplay');
      }
    });

    testWidgets('still selects and matches in silence, then in sound once '
        'the button is switched on', (tester) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = await pumpMatch(
        tester,
        state: voiced(
          tts: tts,
          settings: settingsWith((s) => s.matchTapToHear = false),
        ),
      );
      final pairs = pairsOf(tester);
      await tapText(tester, pairs[0].word);
      await tapText(tester, pairs[0].meaning);
      expect(state.progress.log, hasLength(1), reason: 'matched');
      expect(tts.spoken, isEmpty);

      await tapToggle(tester);
      await tapText(tester, pairs[1].word);
      await tapText(tester, pairs[1].meaning);
      expect(state.progress.log, hasLength(2));
      expect(tts.spoken.map((s) => s.text), <String>[pairs[1].word]);
    });
  });

  group('a meaning tile', () {
    testWidgets('never speaks, with tap to hear on', (tester) async {
      usePhone(tester);
      for (final autoplay in <bool>[false, true]) {
        final tts = FixedTtsEngine(const <String>{'es'});
        await pumpMatch(
          tester,
          state: voiced(
            tts: tts,
            settings: settingsWith((s) => s.autoplay = autoplay),
          ),
        );
        final pairs = pairsOf(tester);
        for (final pair in pairs) {
          await tapText(tester, pair.meaning);
          // Selected, then let go.
          await tapText(tester, pair.meaning);
        }
        expect(tts.spoken, isEmpty, reason: 'autoplay $autoplay');

        // Meaning first, then its word: only the word is said.
        await tapText(tester, pairs[0].meaning);
        await tapText(tester, pairs[0].word);
        expect(tts.spoken.map((s) => s.text), <String>[pairs[0].word]);
      }
    });
  });

  group('the button', () {
    testWidgets('is one speaker toggle on the card, on to begin with, and '
        'not the drill speaker', (tester) async {
      usePhone(tester);
      await pumpMatch(tester, state: voiced());
      expect(toggle, findsOneWidget);
      expect(find.byType(Speaker), findsNothing);
      expect(iconOf(tester), Icons.volume_up_outlined);
      expect(tester.getSize(toggle).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
    });

    testWidgets('flips the setting, its icon, its label and its tooltip, '
        'and flips them back', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = await pumpMatch(tester, state: voiced(tts: tts));
      final l10n = l10nOf(tester);
      final settings = state.settings;

      expect(settings.matchTapToHear, isTrue);
      expect(iconOf(tester), Icons.volume_up_outlined);
      expect(tester.getSemantics(toggle).label, l10n.drillMatchHearOn);
      expect(tooltipOf(tester), l10n.drillMatchHearOn);

      await tapToggle(tester);
      expect(settings.matchTapToHear, isFalse);
      expect(iconOf(tester), Icons.volume_off_outlined);
      expect(tester.getSemantics(toggle).label, l10n.drillMatchHearOff);
      expect(tooltipOf(tester), l10n.drillMatchHearOff);

      await tapToggle(tester);
      expect(settings.matchTapToHear, isTrue);
      expect(iconOf(tester), Icons.volume_up_outlined);
      expect(tester.getSemantics(toggle).label, l10n.drillMatchHearOn);

      // Switching it is not itself a word said, and leaves Play words
      // automatically alone.
      expect(tts.spoken, isEmpty);
      expect(settings.autoplay, isFalse);
      semantics.dispose();
    });

    testWidgets('is a button for screen readers, and opens with the setting '
        'as it was left', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpMatch(
        tester,
        state: voiced(settings: settingsWith((s) => s.matchTapToHear = false)),
      );
      final l10n = l10nOf(tester);
      expect(iconOf(tester), Icons.volume_off_outlined);
      final node = tester.getSemantics(toggle);
      expect(node.label, l10n.drillMatchHearOff);
      expect(node.value, isEmpty);
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });

    testWidgets('a tap on a word then follows the button, both ways', (
      tester,
    ) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      await pumpMatch(tester, state: voiced(tts: tts));
      final pairs = pairsOf(tester);

      await tapText(tester, pairs[0].word);
      expect(tts.spoken, hasLength(1));
      await tapToggle(tester);
      await tapText(tester, pairs[0].word);
      await tapText(tester, pairs[0].word);
      expect(tts.spoken, hasLength(1), reason: 'off: nothing more said');
      await tapToggle(tester);
      await tapText(tester, pairs[1].word);
      expect(tts.spoken, hasLength(2), reason: 'on again');
      expect(tts.spoken.last.text, pairs[1].word);
    });
  });

  group('with sound off in Settings', () {
    testWidgets('nothing plays, the button is greyed out and says why, and '
        'tapping it changes nothing', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = await pumpMatch(
        tester,
        state: voiced(
          tts: tts,
          settings: settingsWith((s) => s.soundOn = false),
        ),
      );
      final l10n = l10nOf(tester);
      expect(toggle, findsOneWidget);
      expect(iconOf(tester), Icons.volume_off_outlined);
      final node = tester.getSemantics(toggle);
      expect(node.value, l10n.speakerMuted);
      // The setting itself is still on, and still says so.
      expect(node.label, l10n.drillMatchHearOn);

      for (final pair in pairsOf(tester)) {
        await tapText(tester, pair.word);
        await tapText(tester, pair.word);
      }
      expect(tts.spoken, isEmpty);

      await tapToggle(tester);
      expect(find.text(l10n.speakerSoundOff), findsOneWidget);
      expect(state.settings.matchTapToHear, isTrue, reason: 'not flipped');
      expect(tts.spoken, isEmpty);
      semantics.dispose();
    });

    testWidgets('tapping a word speaks again once sound is back on', (
      tester,
    ) async {
      usePhone(tester);
      final tts = FixedTtsEngine(const <String>{'es'});
      final state = await pumpMatch(
        tester,
        state: voiced(
          tts: tts,
          settings: settingsWith((s) => s.soundOn = false),
        ),
      );
      final pairs = pairsOf(tester);
      await tapText(tester, pairs[0].word);
      expect(tts.spoken, isEmpty);
      state.settings.soundOn = true;
      await tester.pumpAndSettle();
      expect(iconOf(tester), Icons.volume_up_outlined);
      await tapText(tester, pairs[1].word);
      expect(tts.spoken.map((s) => s.text), <String>[pairs[1].word]);
    });
  });

  testWidgets('with no voice for the language there is no button, and tiles '
      'still work', (tester) async {
    usePhone(tester);
    final state = await pumpMatch(tester, state: AppState.test());
    expect(find.byType(MatchDrill), findsOneWidget);
    expect(toggle, findsNothing);
    final pairs = pairsOf(tester);
    await tapText(tester, pairs[0].word);
    await tapText(tester, pairs[0].meaning);
    expect(state.progress.log, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  group('at the largest font size, 2.0 on Android', () {
    testWidgets('the button is still 48 square, labelled, and nothing is '
        'clipped', (tester) async {
      usePhone(tester, textScale: 2.0);
      final semantics = tester.ensureSemantics();
      await pumpMatch(tester, state: voiced());
      expect(tester.takeException(), isNull);
      expect(toggle, findsOneWidget);
      expect(tester.getSize(toggle).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('the prompt stays on the card, clear of the button', (
      tester,
    ) async {
      usePhone(tester, textScale: 2.0);
      await pumpMatch(tester, state: voiced());
      final l10n = l10nOf(tester);
      final prompt = tester.getRect(find.text(l10n.drillMatchPrompt));
      final button = tester.getRect(toggle);
      expect(
        prompt.overlaps(button),
        isFalse,
        reason: 'the prompt $prompt, the button $button',
      );
    });
  });
}
