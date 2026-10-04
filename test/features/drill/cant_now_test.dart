import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/drill/cant_now.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';

import '../../support/harness.dart';

/// "Can't speak now" and "Can't listen now" (#89): a pause for an hour, or
/// off for one language or everywhere, from a drill and from Settings.

const String spanish = 'es-en-core-100';
const String hindi = 'hi-en-script-vowels';
final DateTime noon = DateTime(2026, 9, 28, 12);

AppState soundState({
  SettingsNotifier? settings,
  DateTime? now,
  MemoryProgress? progress,
  FixedSpeechEngine? speech,
}) => AppState.test(
  tts: FixedTtsEngine(<String>{'es', 'hi'}),
  speech: speech ?? FixedSpeechEngine(onDevice: <String>{'es'}, granted: true),
  settings:
      settings ??
      SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: Skill.values.toSet(),
      ),
  now: now ?? noon,
  progress: progress,
);

/// Whether [deck] has anything to drill in [skill] alone.
bool drillsIn(AppState state, String deck, Skill skill) =>
    state.buildSession(DrillRequest.deck(deck, skill: skill)).items.isNotEmpty;

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a pause and the languages a skill is off for survive a restart', () {
    final settings = SettingsNotifier()
      ..pause(Skill.listening, until: noon.add(const Duration(hours: 1)))
      ..setOffFor(Skill.speaking, 'hi', true)
      ..setOffFor(Skill.speaking, 'bn', true);
    final restored = SettingsNotifier()..restore(settings.toStored());
    expect(
      restored.pausedUntil(Skill.listening),
      noon.add(const Duration(hours: 1)),
    );
    expect(restored.offFor(Skill.speaking), <String>{'hi', 'bn'});
    final junk = SettingsNotifier()
      ..restore(const <String, String>{
        'paused_until': '{"listening": "soon", "nope": 1}',
        'off_for': '{"speaking": ["hi", "Hindi", 3], "nope": ["bn"]}',
      });
    expect(junk.pausedUntil(Skill.listening), isNull);
    expect(junk.offFor(Skill.speaking), <String>{'hi'});
  });

  test(
    'a paused skill leaves sessions for the hour, then comes back',
    () async {
      final settings = SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: Skill.values.toSet(),
      )..pause(Skill.listening, until: noon.add(const Duration(hours: 1)));
      final now = soundState(settings: settings);
      addTearDown(now.dispose);
      await now.load();
      expect(now.sessionModes, isNot(contains(DrillMode.listening)));
      expect(now.sessionModes, contains(DrillMode.speaking));

      final later = soundState(
        settings: settings,
        now: noon.add(const Duration(hours: 2)),
      );
      addTearDown(later.dispose);
      await later.load();
      expect(later.sessionModes, contains(DrillMode.listening));
    },
  );

  test('a paused skill is not drilled when it is asked for by name either, '
      'as the deck page asks', () async {
    final state = soundState();
    addTearDown(state.dispose);
    await state.load();
    expect(drillsIn(state, spanish, Skill.listening), isTrue);
    state.settings.pause(
      Skill.listening,
      until: noon.add(const Duration(hours: 1)),
    );
    expect(drillsIn(state, spanish, Skill.listening), isFalse);
    expect(
      state
          .buildSession(
            DrillRequest.deck(spanish, skill: Skill.listening),
            ignorePauses: true,
          )
          .items,
      isNotEmpty,
    );
  });

  test('off for one language leaves the others', () async {
    final state = soundState();
    addTearDown(state.dispose);
    await state.load();
    // The launch check of the recogniser is not awaited by load.
    await pumpEventQueue();
    expect(drillsIn(state, spanish, Skill.listening), isTrue);
    state.settings.setOffFor(Skill.listening, 'es', true);
    expect(drillsIn(state, spanish, Skill.listening), isFalse);
    expect(drillsIn(state, hindi, Skill.listening), isTrue);
    expect(drillsIn(state, spanish, Skill.speaking), isTrue);
  });

  test('a pause does not make a deck finished, nor move the path', () async {
    final state = soundState();
    addTearDown(state.dispose);
    await state.load();
    // The launch check of the recogniser is not awaited by load.
    await pumpEventQueue();
    final deck = state.deckById(spanish)!;
    final before = state.notStudiedIn(deck);
    final units = state.pendingUnits;
    state.settings
      ..pause(Skill.listening, until: noon.add(const Duration(hours: 1)))
      ..pause(Skill.speaking, until: noon.add(const Duration(hours: 1)));
    expect(state.notStudiedIn(deck), before);
    expect(
      state.pendingUnits.map((u) => u.map((e) => e.id).toList()),
      units.map((u) => u.map((e) => e.id).toList()),
    );
  });

  test(
    'a deck with only the paused skill left is still not finished',
    () async {
      final state = AppState.test(
        tts: FixedTtsEngine(<String>{'hi'}),
        now: noon,
        decks: MemoryDeckSource(<String, String>{
          'decks/hi/hi-en-heard.yaml': '''
schema: 1
id: hi-en-heard
name: Heard
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari, tts: hi-IN }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-heard-0001, target: "घर", native: "house", modes: [listening] }
''',
        }),
      );
      addTearDown(state.dispose);
      await state.load();
      // The launch check of the recogniser is not awaited by load.
      await pumpEventQueue();
      final deck = state.deckById('hi-en-heard')!;
      expect(state.notStudiedIn(deck), 1);
      state.settings.pause(
        Skill.listening,
        until: noon.add(const Duration(hours: 1)),
      );
      expect(state.notStudiedIn(deck), 1, reason: 'a pause is not finishing');
      expect(state.isFinished(deck), isFalse);
      expect(state.pendingUnits.single.single.id, deck.id);
    },
  );

  group('on a drill', () {
    testWidgets('Pause for an hour skips this and every later listening card, '
        'unrecorded', (tester) async {
      usePhone(tester);
      final state = soundState();
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.deck(spanish, skill: Skill.listening)),
        state: state,
      );
      final l10n = l10nOf(tester);
      await tapText(tester, l10n.drillCantListen);
      await tapText(tester, l10n.cantNowPause);
      expect(
        state.settings.pausedUntil(Skill.listening),
        noon.add(const Duration(hours: 1)),
      );
      expect(state.progress.log, isEmpty);
      // Every card was listening, so the session is over.
      expect(find.text(l10n.drillCantListen), findsNothing);
    });

    testWidgets('Turn off for Spanish switches speaking off for Spanish only', (
      tester,
    ) async {
      usePhone(tester);
      final state = soundState();
      await state.load();
      // The launch check of the recogniser is not awaited by load.
      await tester.pump();
      await state.startSpeech();
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.deck(spanish, skill: Skill.speaking)),
        state: state,
      );
      final l10n = l10nOf(tester);
      await tapText(tester, l10n.drillCantSpeak);
      await tapText(tester, l10n.cantNowOffFor('Spanish'));
      expect(state.settings.offFor(Skill.speaking), <String>{'es'});
      expect(state.settings.isEnabled(Skill.speaking), isTrue);
      expect(state.progress.log, isEmpty);
      // Every card was Spanish speaking, so none is left to drill.
      expect(find.text(l10n.drillCantSpeak), findsNothing);
    });

    testWidgets('Turn off for Spanish keeps the session\'s cards in another '
        'language', (tester) async {
      usePhone(tester);
      final state = soundState();
      await state.load();
      await tester.pump();
      List<SessionItem> listening(String deck) => state
          .buildSession(DrillRequest.deck(deck, skill: Skill.listening))
          .items
          .take(2)
          .toList();
      final session = DrillSession(
        state: state,
        items: <SessionItem>[...listening(spanish), ...listening(hindi)],
      );
      addTearDown(session.dispose);
      await pumpScreen(
        tester,
        ListenableBuilder(
          listenable: session,
          builder: (context, _) => Scaffold(
            body: Column(
              children: <Widget>[
                Text(session.deck.id),
                CantNowButton(session: session),
              ],
            ),
          ),
        ),
        state: state,
      );
      final l10n = l10nOf(tester);
      expect(find.text(spanish), findsOneWidget);
      await tapText(tester, l10n.drillCantListen);
      await tapText(tester, l10n.cantNowOffFor('Spanish'));
      expect(state.settings.offFor(Skill.listening), <String>{'es'});
      expect(find.text(hindi), findsOneWidget);
      expect(state.progress.log, isEmpty);
    });

    testWidgets('Turn off everywhere switches the skill off', (tester) async {
      usePhone(tester);
      final state = soundState();
      await state.load();
      // The launch check of the recogniser is not awaited by load.
      await tester.pump();
      await state.startSpeech();
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.deck(spanish, skill: Skill.speaking)),
        state: state,
      );
      final l10n = l10nOf(tester);
      await tapText(tester, l10n.drillCantSpeak);
      await tapText(tester, l10n.cantNowOffEverywhere);
      expect(state.settings.isEnabled(Skill.speaking), isFalse);
      expect(state.progress.log, isEmpty);
      expect(find.text(l10n.drillCantSpeak), findsNothing);
    });
  });

  group('on the deck page', () {
    testWidgets('a paused skill is muted, says until when, and Resume ends '
        'the pause', (tester) async {
      usePhone(tester);
      final state = soundState();
      state.settings.pause(
        Skill.listening,
        until: noon.add(const Duration(hours: 1)),
      );
      await pumpScreen(
        tester,
        const DeckDetailPage(deckId: spanish),
        state: state,
      );
      final l10n = l10nOf(tester);
      final until = MaterialLocalizations.of(
        tester.element(find.byType(DeckDetailPage)),
      ).formatTimeOfDay(const TimeOfDay(hour: 13, minute: 0));
      final row = find.widgetWithText(GroupedTile, Skill.listening.label(l10n));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: row,
          matching: find.text(l10n.settingsPausedUntil(until)),
        ),
        findsOneWidget,
      );
      await tapText(tester, l10n.settingsResume);
      expect(state.settings.pausedUntil(Skill.listening), isNull);
      expect(
        find.descendant(of: row, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
    });

    testWidgets('a skill off for the language says so, and Turn on switches '
        'it back on', (tester) async {
      usePhone(tester);
      final state = soundState();
      state.settings.setOffFor(Skill.listening, 'es', true);
      await pumpScreen(
        tester,
        const DeckDetailPage(deckId: spanish),
        state: state,
      );
      final l10n = l10nOf(tester);
      final row = find.widgetWithText(GroupedTile, Skill.listening.label(l10n));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: row,
          matching: find.text(l10n.deckSkillOffFor('Spanish')),
        ),
        findsOneWidget,
      );
      await tapText(tester, l10n.deckTurnOn);
      expect(state.settings.offFor(Skill.listening), isEmpty);
    });
  });

  group('in Settings', () {
    testWidgets('Pause for an hour pauses the skill from Settings', (
      tester,
    ) async {
      usePhone(tester);
      final state = soundState();
      await pumpScreen(tester, const SettingsPage(), state: state);
      final l10n = l10nOf(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.cantNowPause).first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText(tester, l10n.cantNowPause);
      expect(
        state.settings.pausedUntil(Skill.listening),
        noon.add(const Duration(hours: 1)),
      );
    });

    testWidgets('a pause shows until when, and Resume ends it', (tester) async {
      usePhone(tester);
      final state = soundState();
      state.settings.pause(
        Skill.listening,
        until: noon.add(const Duration(hours: 1)),
      );
      await pumpScreen(tester, const SettingsPage(), state: state);
      final l10n = l10nOf(tester);
      final until = MaterialLocalizations.of(
        tester.element(find.byType(SettingsPage)),
      ).formatTimeOfDay(const TimeOfDay(hour: 13, minute: 0));
      await tester.scrollUntilVisible(
        find.text(l10n.settingsPausedUntil(until)),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText(tester, l10n.settingsResume);
      expect(state.settings.pausedUntil(Skill.listening), isNull);
      expect(find.text(l10n.settingsPausedUntil(until)), findsNothing);
    });

    testWidgets('Languages turns a skill off and on for one language', (
      tester,
    ) async {
      usePhone(tester);
      final state = soundState();
      await pumpScreen(tester, const SettingsPage(), state: state);
      final l10n = l10nOf(tester);
      final rows = find.text(l10n.settingsSkillLanguages);
      await tester.scrollUntilVisible(
        rows.first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.settingsSkillOnForAll), findsWidgets);
      await tapText(tester, l10n.settingsSkillLanguages);
      await tapText(tester, 'Spanish');
      expect(state.settings.offFor(Skill.listening), <String>{'es'});
      await tapText(tester, l10n.commonDone);
      expect(find.text(l10n.settingsSkillOffFor('Spanish')), findsOneWidget);
    });
  });
}
