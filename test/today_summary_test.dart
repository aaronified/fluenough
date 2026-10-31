// Today's saved summary (#857, #875): the last skill-tile numbers are kept
// small and plain, read back at launch to draw the tiles while the catalog
// loads, and replaced by the live numbers once it is ready.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app.dart' show capTextScale;
import 'package:fluenough/app/app_scope.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/app/stored_settings.dart';
import 'package:fluenough/app/today_summary.dart';
import 'package:fluenough/core/data/database.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/features/today/due_card.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/theme.dart';

import 'support/harness.dart';
import 'support/two_script_course.dart';

/// A deck source whose list waits until [open] is called: a catalog that is
/// still loading.
class _GatedSource extends MemoryDeckSource {
  _GatedSource(super.files);

  final Completer<void> _gate = Completer<void>();

  void open() => _gate.complete();

  @override
  Future<List<String>> list() async {
    await _gate.future;
    return super.list();
  }
}

SettingsNotifier _settings({String learning = 'hi'}) => SettingsNotifier(
  spokenLanguages: const <String>['en'],
  learningLanguages: <String>[learning],
  learningChosen: true,
);

MemoryProgress _dueProgress() {
  final progress = MemoryProgress();
  final long = DateTime(2026, 7, 1, 9);
  void review(String deck, String card, DrillMode mode) => progress.record(
    deckId: deck,
    cardId: card,
    mode: mode,
    grade: 4,
    now: long,
  );
  review('hi-en-letters', 'hi-en-letters-0001', DrillMode.recognition);
  review('hi-en-urdu-letters', 'hi-en-urdu-letters-0001', DrillMode.production);
  review('hi-en-words', 'hi-en-words-0001', DrillMode.recognition);
  review('hi-en-words', 'hi-en-words-0002', DrillMode.production);
  return progress;
}

/// The numbers drawn on the skill tiles, in order.
List<String> _tileTexts(WidgetTester tester) => <String>[
  for (final t in tester.widgetList<Text>(
    find.descendant(of: find.byType(DueCard), matching: find.byType(Text)),
  ))
    t.data ?? '',
];

const TodaySummary _sample = TodaySummary(
  hasDecks: true,
  due: 4,
  bySkill: <Skill, int>{Skill.recognition: 1, Skill.production: 1},
  dueIn: <Skill, int>{Skill.recognition: 2, Skill.production: 1},
  revisable: <Skill, int>{Skill.listening: 7},
  script: (count: 2, due: 2, revisable: 0),
  noVoice: false,
  streak: 3,
  newWords: 5,
);

void main() {
  const stamp = '1|0.7.0|hi|recognition';

  group('the saved summary', () {
    test('round-trips as plain text, one entry per language', () {
      var saved = TodaySummaries.write(
        saved: null,
        stamp: stamp,
        language: 'hi',
        summary: _sample,
      );
      saved = TodaySummaries.write(
        saved: saved,
        stamp: stamp,
        language: 'te',
        summary: const TodaySummary(
          hasDecks: true,
          due: 0,
          bySkill: <Skill, int>{},
          dueIn: <Skill, int>{},
          revisable: <Skill, int>{},
          script: null,
          noVoice: true,
          streak: 0,
          newWords: 0,
        ),
      );
      final hi = TodaySummaries.read(
        saved: saved,
        stamp: stamp,
        language: 'hi',
      )!;
      expect(hi.due, 4);
      expect(hi.bySkill, _sample.bySkill);
      expect(hi.dueIn, _sample.dueIn);
      expect(hi.revisable, _sample.revisable);
      expect(hi.script, (count: 2, due: 2, revisable: 0));
      expect((hi.streak, hi.newWords, hi.noVoice), (3, 5, false));
      final te = TodaySummaries.read(
        saved: saved,
        stamp: stamp,
        language: 'te',
      )!;
      expect(te.script, isNull);
      expect(te.noVoice, isTrue);
      expect(
        TodaySummaries.read(saved: saved, stamp: stamp, language: 'bn'),
        isNull,
        reason: 'a language never saved has nothing',
      );
    });

    test('another stamp is ignored, and a write under a new stamp does not '
        'keep the old languages', () {
      final saved = TodaySummaries.write(
        saved: null,
        stamp: stamp,
        language: 'hi',
        summary: _sample,
      );
      for (final other in <String>[
        '2|0.7.0|hi|recognition',
        '1|0.7.1|hi|recognition',
        '1|0.7.0|hi,te|recognition',
        '1|0.7.0|hi|recognition,listening',
      ]) {
        expect(
          TodaySummaries.read(saved: saved, stamp: other, language: 'hi'),
          isNull,
          reason: other,
        );
      }
      final rewritten = TodaySummaries.write(
        saved: saved,
        stamp: '1|0.7.1|hi|recognition',
        language: 'te',
        summary: _sample,
      );
      expect(
        TodaySummaries.read(
          saved: rewritten,
          stamp: '1|0.7.1|hi|recognition',
          language: 'hi',
        ),
        isNull,
      );
    });

    test('text that is not a summary is ignored', () {
      for (final bad in <String?>[
        null,
        '',
        'not json',
        '[]',
        '{"stamp":"$stamp"}',
        '{"stamp":"$stamp","languages":{"hi":{"due":"4"}}}',
        '{"stamp":"$stamp","languages":{"hi":{"decks":true,"due":1,'
            '"by":{"nonsense":1},"in":{},"rev":{},"script":null,'
            '"voice":false,"streak":0,"new":0}}}',
      ]) {
        expect(
          TodaySummaries.read(saved: bad, stamp: stamp, language: 'hi'),
          isNull,
          reason: '$bad',
        );
      }
    });

    test('is saved with the settings and read back', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final stored = await StoredSettings.open(db);
      expect(stored.settings.todaySummary, isNull);
      stored.settings.todaySummary = 'kept';
      await stored.flush();
      final again = await StoredSettings.open(db);
      expect(again.settings.todaySummary, 'kept');
    });

    test('writing it notifies no screen', () {
      final settings = SettingsNotifier();
      var told = 0;
      settings.addListener(() => told++);
      settings.todaySummary = 'x';
      expect(told, 0);
    });
  });

  group('AppState keeps and reads it', () {
    test('what is remembered and flushed is read by a later launch with '
        'the same languages and skills, and by none other', () async {
      final live = AppState.test(
        decks: MemoryDeckSource(twoScriptCourse()),
        progress: _dueProgress(),
        settings: _settings(),
      );
      addTearDown(live.dispose);
      await live.load();
      final numbers = TodayNumbers.of(live);
      expect(numbers.due, greaterThan(0));
      live.rememberToday(numbers.summary);
      live.flushToday();
      final text = live.settings.todaySummary!;

      AppState launch(SettingsNotifier settings) {
        final state = AppState.test(
          decks: _GatedSource(twoScriptCourse()),
          settings: settings..restore(<String, String>{'today_summary': text}),
        );
        addTearDown(state.dispose);
        return state;
      }

      final same = launch(_settings()).savedToday!;
      expect(same.due, numbers.due);
      expect(same.bySkill, numbers.bySkill);
      expect(same.dueIn, numbers.dueIn);
      expect(same.script, numbers.script);

      expect(
        launch(_settings(learning: 'te')).savedToday,
        isNull,
        reason: 'other languages',
      );
      expect(
        launch(_settings()..setSkillEnabled(Skill.listening, false)).savedToday,
        isNull,
        reason: 'other skills',
      );
    });

    test('nothing is written when it is what is saved already', () async {
      final state = AppState.test(
        decks: MemoryDeckSource(twoScriptCourse()),
        progress: _dueProgress(),
        settings: _settings(),
      );
      addTearDown(state.dispose);
      await state.load();
      var saves = 0;
      state.settings.todaySummaryChanges.addListener(() => saves++);
      for (var i = 0; i < 3; i++) {
        state.rememberToday(TodayNumbers.of(state).summary);
        state.flushToday();
      }
      expect(saves, 1);
    });
  });

  group('Today while the catalog loads', () {
    Future<void> pumpToday(WidgetTester tester, AppState state) async {
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            onGenerateRoute: AppRoutes.onGenerateRoute,
            builder: capTextScale,
            home: const TodayPage(),
          ),
        ),
      );
    }

    testWidgets('draws the saved tiles at once, ignores a tap on one, and '
        'shows the live numbers once the catalog is ready', (tester) async {
      usePhone(tester);
      // The numbers a first launch worked out.
      final first = AppState.test(
        decks: MemoryDeckSource(twoScriptCourse()),
        progress: _dueProgress(),
        settings: _settings(),
      );
      addTearDown(first.dispose);
      await first.load();
      first.rememberToday(TodayNumbers.of(first).summary);
      first.flushToday();

      // The next launch: the catalog is still being read.
      final source = _GatedSource(twoScriptCourse());
      final state = AppState.test(
        decks: source,
        progress: _dueProgress(),
        settings: _settings()
          ..restore(<String, String>{
            'today_summary': first.settings.todaySummary!,
          }),
      );
      addTearDown(state.dispose);
      final loading = state.load();
      await pumpToday(tester, state);
      await tester.pump();

      expect(state.status, CatalogStatus.loading);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(DueCard), findsOneWidget);
      final saved = _tileTexts(tester);
      expect(saved, contains('2'), reason: 'the Script tile');

      // A tap on a tile does nothing yet, and breaks nothing.
      await tester.tap(find.byType(DueCard), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(DueCard), findsOneWidget);

      source.open();
      await loading;
      await tester.pumpAndSettle();
      expect(state.status, CatalogStatus.ready);
      expect(find.byType(DueCard), findsOneWidget);
      expect(
        _tileTexts(tester),
        saved,
        reason: 'the live numbers are the ones saved, here',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws the live numbers, not the saved ones, once ready, '
        'and the spinner when nothing is saved', (tester) async {
      usePhone(tester);
      final stale = TodaySummaries.write(
        saved: null,
        stamp: TodaySummaries.stamp(
          languages: const <String>['hi'],
          enabled: <Skill>[
            for (final s in Skill.values)
              if (SettingsNotifier().isEnabled(s)) s,
          ],
        ),
        language: 'hi',
        summary: const TodaySummary(
          hasDecks: true,
          due: 90,
          bySkill: <Skill, int>{Skill.recognition: 90},
          dueIn: <Skill, int>{Skill.recognition: 90},
          revisable: <Skill, int>{},
          script: null,
          noVoice: false,
          streak: 0,
          newWords: 0,
        ),
      );
      final source = _GatedSource(twoScriptCourse());
      final state = AppState.test(
        decks: source,
        progress: _dueProgress(),
        settings: _settings()
          ..restore(<String, String>{'today_summary': stale}),
      );
      addTearDown(state.dispose);
      final loading = state.load();
      await pumpToday(tester, state);
      await tester.pump();
      expect(_tileTexts(tester), contains('90'));

      source.open();
      await loading;
      await tester.pumpAndSettle();
      expect(_tileTexts(tester), isNot(contains('90')));

      // Nothing saved: the spinner, as before.
      final blank = AppState.test(
        decks: _GatedSource(twoScriptCourse()),
        settings: _settings(),
      );
      addTearDown(blank.dispose);
      unawaited(blank.load());
      await tester.pumpWidget(const SizedBox());
      await pumpToday(tester, blank);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(DueCard), findsNothing);
    });
  });
}
