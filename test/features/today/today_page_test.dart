import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/features/today/today_fixtures.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/ui/widgets/deck_tile.dart';

import '../../support/harness.dart';

Future<AppState> pumpToday(WidgetTester tester, {AppState? state}) =>
    pumpScreen(tester, const TodayPage(), state: state);

/// Aro's fixture state: twelve days of reviews ending yesterday.
Future<AppState> fixtureState({String profile = 'aro'}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(app, currentProfileId: profile);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the due count, minutes and skill tiles come from the session', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpToday(tester, state: await fixtureState());
    final l10n = l10nOf(tester);

    final queue = state.buildSession(const DrillRequest.today());
    expect(queue.length, greaterThan(0));
    final numbers = TodayNumbers.of(state);
    expect(numbers.due, queue.length);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text && w.data == '${queue.length}' && w.style?.fontSize == 72,
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.todayCardsDue(queue.length)), findsOneWidget);
    expect(find.text(l10n.todayMinutes(numbers.minutes)), findsOneWidget);

    final byMode = queue.countByMode();
    for (final (skill, label) in <(Skill, String)>[
      (Skill.recognition, l10n.skillRecognition),
      (Skill.production, l10n.skillProduction),
      // The grammar drill ships (#14).
      (Skill.grammar, l10n.skillGrammar),
    ]) {
      expect(
        find.bySemanticsLabel(
          l10n.todaySkillSemantics(label, byMode[skill.mode] ?? 0),
        ),
        findsOneWidget,
        reason: skill.name,
      );
    }
  });

  testWidgets('the header greets by time of day, with or without a name', (
    tester,
  ) async {
    usePhone(tester);
    await pumpToday(tester);
    final l10n = l10nOf(tester);
    final evening = DateTime(2026, 9, 28, 19);
    expect(find.text(l10n.todayGreetingEvening), findsOneWidget);
    expect(
      find.text(DateFormat.MMMMEEEEd('en').format(evening)),
      findsOneWidget,
    );

    expect(
      greetingFor(l10n, DateTime(2026, 9, 28, 9), null),
      l10n.todayGreetingMorning,
    );
    expect(
      greetingFor(l10n, DateTime(2026, 9, 28, 13), 'Aro'),
      l10n.todayGreetingAfternoonName('Aro'),
    );
    expect(
      greetingFor(l10n, DateTime(2026, 9, 28, 2), 'Aro'),
      l10n.todayGreetingEveningName('Aro'),
    );

    await pumpToday(tester, state: await fixtureState());
    expect(find.text(l10n.todayGreetingEveningName('Aro')), findsOneWidget);
  });

  testWidgets('Start review opens a drill of today\'s session', (tester) async {
    usePhone(tester);
    final settings = SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
    );
    await pumpToday(
      tester,
      state: await withReviewsDue(
        (progress) => AppState.test(settings: settings, progress: progress),
        const <String>['hi'],
      ),
    );
    await tapVisible(tester, find.text(l10nOf(tester).todayStartReview));
    final drill = tester.widget<DrillPage>(find.byType(DrillPage));
    expect(drill.request.deckIds, isNull);
    expect(drill.request.newOnly, isFalse);
    expect(drill.request.language, isNull, reason: 'one language');
  });

  testWidgets('with several languages, Start begins with the first alone', (
    tester,
  ) async {
    usePhone(tester);
    final settings = SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['bn', 'hi'],
    );
    final state = await pumpToday(
      tester,
      state: await withReviewsDue(
        (progress) => AppState.test(settings: settings, progress: progress),
        const <String>['bn', 'hi'],
      ),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.todayStartReview), findsNothing);
    final bengali = state.todayLanguages.first;
    expect(bengali.code, 'bn', reason: 'the order they were chosen in');
    await tapVisible(tester, find.text(l10n.todayStartLanguage(bengali.name)));
    final drill = tester.widget<DrillPage>(find.byType(DrillPage));
    expect(drill.request.language, 'bn');
    expect(drill.request.deckIds, isNull);
  });

  testWidgets('a unit placed as known gives its place in Your decks to the '
      'next one (ADR-0013)', (tester) async {
    usePhone(tester);
    final settings = SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      placedDecks: const <String>{
        'hi-en-first-words',
        'hi-en-grammar-sentences',
      },
    );
    await pumpToday(tester, state: AppState.test(settings: settings));
    final shown = <String>[
      for (final tile in tester.widgetList<DeckTile>(find.byType(DeckTile)))
        tile.entry.id,
    ];
    expect(shown, <String>[
      'hi-en-sound-differences',
      'hi-en-grammar-differences',
      'hi-en-questions',
    ]);
  });

  testWidgets('See all switches the shell to the Decks tab', (tester) async {
    usePhone(tester);
    final state = await pumpApp(tester);
    expect(state.shellTab.value, ShellTab.today);
    await tapVisible(tester, find.text(l10nOf(tester).todaySeeAll));
    expect(state.shellTab.value, ShellTab.decks);
  });

  testWidgets('Your decks lists up to three decks, each opening its screen', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpToday(tester);
    final tiles = find.byType(DeckTile);
    expect(tiles, findsNWidgets(state.profileDecks.length.clamp(0, 3)));
    final first = tester.widget<DeckTile>(tiles.first).entry;
    // The decks Today is teaching from come first (ADR-0013).
    expect(state.isPending(first), isTrue);
    await tapVisible(tester, tiles.first);
    expect(
      tester.widget<DeckDetailPage>(find.byType(DeckDetailPage)).deckId,
      first.id,
    );
  });

  testWidgets('the not-saved banner shows only while progress is in memory', (
    tester,
  ) async {
    usePhone(tester);
    await pumpToday(tester);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.commonNotSavedTitle), findsOneWidget);
    expect(find.text(l10n.commonNotSavedBody), findsOneWidget);

    await pumpToday(tester, state: AppState.test(progress: _SavedProgress()));
    expect(find.text(l10n.commonNotSavedTitle), findsNothing);
  });

  testWidgets('with no voice, Listening says so and opens Voices', (
    tester,
  ) async {
    usePhone(tester);
    await pumpToday(
      tester,
      state: await withReviewsDue(
        (progress) => AppState.test(progress: progress),
        const <String>['es'],
      ),
    );
    final l10n = l10nOf(tester);
    final tile = find.bySemanticsLabel(
      l10n.todaySkillNoVoice(l10n.skillListening),
    );
    expect(tile, findsOneWidget);
    expect(find.text(l10n.commonNoVoice), findsOneWidget);

    await tapVisible(tester, find.text(l10n.commonNoVoice));
    expect(find.byType(VoicesPage), findsOneWidget);
  });

  testWidgets('with a voice, Listening counts its cards instead', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpToday(
      tester,
      state: await withReviewsDue(
        (progress) => AppState.test(
          tts: FixedTtsEngine(const <String>{'es', 'hi'}),
          progress: progress,
        ),
        const <String>['es', 'hi'],
      ),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.commonNoVoice), findsNothing);
    final n = TodayNumbers.of(state).bySkill[Skill.listening]!;
    expect(
      find.bySemanticsLabel(l10n.todaySkillSemantics(l10n.skillListening, n)),
      findsOneWidget,
    );
  });

  testWidgets('with everything answered, Today is all done', (tester) async {
    usePhone(tester);
    final state = await fixtureState();
    await state.load();
    finishToday(state);
    await pumpToday(tester, state: state);
    final l10n = l10nOf(tester);

    expect(find.text(l10n.todayAllDoneTitle), findsOneWidget);
    expect(find.text(l10n.todayAllDoneBody), findsOneWidget);
    expect(find.text(l10n.todayStartReview), findsNothing);
    // Today now counts towards the streak.
    expect(find.text(l10n.todayStreak(13)), findsOneWidget);
  });

  testWidgets('the streak and each day of the week come from the history', (
    tester,
  ) async {
    usePhone(tester);
    final state = await fixtureState();
    await pumpToday(tester, state: state);
    final l10n = l10nOf(tester);

    expect(find.text(l10n.todayStreak(12)), findsOneWidget);
    expect(find.text(l10n.todayNewWords(0)), findsOneWidget);

    // The fixture practised every day before today: six ticks, then today.
    final name = DateFormat.EEEE('en');
    final today = dateOnly(state.now());
    for (var back = 6; back >= 0; back--) {
      final day = addDays(today, -back);
      final status = back == 0 ? 'today' : 'done';
      expect(
        find.bySemanticsLabel(l10n.todayWeekDay(name.format(day), status)),
        findsOneWidget,
        reason: '$day',
      );
    }
  });

  testWidgets('a first day has no streak and every day unpractised', (
    tester,
  ) async {
    usePhone(tester);
    await pumpToday(tester);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.todayStreak(0)), findsOneWidget);
    final name = DateFormat.EEEE('en');
    final yesterday = addDays(dateOnly(DateTime(2026, 9, 28)), -1);
    expect(
      find.bySemanticsLabel(l10n.todayWeekDay(name.format(yesterday), 'other')),
      findsOneWidget,
    );
  });

  testWidgets('switch profile is incoming', (tester) async {
    usePhone(tester);
    await pumpToday(tester);
    final l10n = l10nOf(tester);
    final node = find.bySemanticsLabel(
      l10n.incomingSemanticsLabel(l10n.todaySwitchProfile),
    );
    expect(node, findsOneWidget);
    await tapVisible(tester, node);
    expect(find.text(l10n.incomingSnackBar), findsOneWidget);
    // The bundled decks have no facts file yet, so no fact card either.
    expect(find.text(l10n.todayFactTitle), findsNothing);
  });

  testWidgets('a profile with no decks in its languages is sent to Decks', (
    tester,
  ) async {
    usePhone(tester);
    const nobody = Profile(id: 'fr', name: 'Fr', languages: <String>{'fr'});
    final state = await pumpApp(
      tester,
      state: AppState.test(
        profiles: const <Profile>[nobody],
        currentProfileId: 'fr',
      ),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.todayNoDecks), findsOneWidget);
    expect(find.text(l10n.todayStartReview), findsNothing);
    expect(find.text(l10n.todayYourDecks), findsNothing);
    await tapVisible(tester, find.text(l10n.todayBrowseDecks));
    expect(state.shellTab.value, ShellTab.decks);
  });

  test('minutes estimate the session at the design\'s rate', () {
    TodayNumbers withDue(int due) => TodayNumbers(
      hasDecks: true,
      due: due,
      bySkill: const <Skill, int>{},
      noVoice: false,
      streak: 0,
      newWords: 0,
      week: const <WeekDay>[],
    );
    expect(withDue(0).minutes, 0);
    expect(withDue(1).minutes, 1);
    expect(withDue(12).minutes, 4);
    expect(withDue(41).minutes, 14);
  });

  testWidgets('a catalog that failed offers Try again, which reloads it', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpScreen(
      tester,
      const TodayPage(),
      state: AppState.test(decks: FailOnceDeckSource()),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.commonDecksFailed), findsOneWidget);

    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();
    expect(state.status, CatalogStatus.ready);
    expect(find.text(l10n.commonDecksFailed), findsNothing);
    expect(find.byType(DeckTile), findsWidgets);
  });
}

/// Progress that says it outlives the app, as the database's does.
class _SavedProgress extends MemoryProgress {
  @override
  bool get persists => true;
}
