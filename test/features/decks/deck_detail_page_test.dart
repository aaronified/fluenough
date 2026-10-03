import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/decks/deck_detail_page.dart';
import 'package:fluenough/features/decks/deck_facts.dart';
import 'package:fluenough/features/decks/unreviewed_notice.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/grammar_drill.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/skill_visuals.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:fluenough/ui/widgets/incoming.dart';
import 'package:fluenough/ui/widgets/mode_pill.dart';

import '../../support/harness.dart';

const String spanish = 'es-en-core-100';
const String hiragana = 'ja-en-hiragana';
const String grammar = 'es-en-grammar-present-ar';

Future<AppState> pumpDeck(
  WidgetTester tester,
  String deckId, {
  AppState? state,
  Set<String> tags = const <String>{},
}) => pumpScreen(
  tester,
  DeckDetailPage(deckId: deckId, initialTags: tags),
  state: state,
);

AppState withSpanishVoice() =>
    AppState.test(tts: FixedTtsEngine(const <String>{'es'}));

Finder skillRow(AppLocalizations l10n, Skill skill) =>
    find.widgetWithText(GroupedTile, skill.label(l10n));

/// Taps [finder] after scrolling it into view.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with a voice: header, counts, a live row per skill, facts', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpDeck(tester, spanish, state: withSpanishVoice());
    final l10n = l10nOf(tester);
    final entry = state.deckById(spanish)!;
    final language = entry.language;

    expect(
      find.text(
        l10n.deckHeaderLine(
          language.name,
          language.iso639_3,
          l10n.deckKindVocabulary,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.commonCardCount(entry.itemCount)), findsOneWidget);
    expect(find.text(entry.deck.name), findsOneWidget);

    final counts = state.countsFor(entry);
    expect(counts.fresh, greaterThan(0));
    expect(find.text(l10n.deckDue), findsOneWidget);
    expect(find.text('${counts.fresh}'), findsWidgets);

    for (final skill in <Skill>[
      Skill.recognition,
      Skill.production,
      Skill.listening,
    ]) {
      final n = state
          .buildSession(DrillRequest.deck(spanish, skill: skill))
          .items
          .length;
      expect(
        find.descendant(
          of: skillRow(l10n, skill),
          matching: find.byType(FilledButton),
        ),
        findsOneWidget,
        reason: skill.name,
      );
      expect(
        find.bySemanticsLabel(l10n.deckStartSkill(skill.label(l10n), n)),
        findsOneWidget,
      );
    }
    expect(find.text(l10n.deckSetUpVoice), findsNothing);
    expect(find.byType(IncomingBadge), findsNothing);

    await tester.scrollUntilVisible(find.text(l10n.deckId), 200);
    expect(find.text(entry.deck.license), findsOneWidget);
    expect(find.text(l10n.deckSourceBundled), findsOneWidget);
    expect(find.text(l10n.deckVoiceInstalled(language.ttsTag)), findsOneWidget);
    expect(find.text(spanish), findsOneWidget);
    expect(
      find.text(l10n.deckReviewAll(counts.due + counts.fresh)),
      findsOneWidget,
    );
  });

  testWidgets('never shows a card id', (tester) async {
    usePhone(tester);
    // Tall enough that the lazy list builds every section.
    tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
    final state = await pumpDeck(tester, spanish);
    expect(find.byType(DeckFacts), findsOneWidget);
    final ids = state.deckById(spanish)!.cards.map((c) => c.id).toSet();
    final shown = tester
        .widgetList<Text>(find.byType(Text, skipOffstage: false))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '');
    for (final text in shown) {
      for (final id in ids) {
        expect(text, isNot(contains(id)));
      }
    }
  });

  testWidgets('without a voice: listening is muted, says why, and Set up '
      'opens Voices', (tester) async {
    usePhone(tester);
    final state = await pumpDeck(tester, hiragana);
    final l10n = l10nOf(tester);
    final language = state.deckById(hiragana)!.language;

    final listening = skillRow(l10n, Skill.listening);
    expect(
      find.descendant(
        of: listening,
        matching: find.text(l10n.deckNoVoice(language.name)),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ModePill>(
            find.descendant(of: listening, matching: find.byType(ModePill)),
          )
          .muted,
      isTrue,
    );
    expect(
      find.descendant(of: listening, matching: find.byType(FilledButton)),
      findsNothing,
    );
    // The other skills stay live.
    expect(
      find.descendant(
        of: skillRow(l10n, Skill.recognition),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );

    // A script deck says Script, though its kind is vocab.
    expect(
      find.text(
        l10n.deckHeaderLine(
          language.name,
          language.iso639_3,
          l10n.deckKindScript,
        ),
      ),
      findsOneWidget,
    );

    await tapVisible(tester, find.text(l10n.deckSetUpVoice));
    expect(find.byType(VoicesPage), findsOneWidget);
  });

  testWidgets('speaking is listed where it is switched on; a language heard '
      'only online says so, and Set up opens Voices', (tester) async {
    usePhone(tester);
    // Lists only Japanese on the device, so Spanish can only be heard
    // online, which the learner has not allowed.
    final speech = FixedSpeechEngine(
      onDevice: <String>{'ja'},
      online: <String>{'es'},
    );
    final state = AppState.test(
      tts: FixedTtsEngine(const <String>{'es'}),
      speech: speech,
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: Skill.values.toSet(),
      ),
    );
    await state.load();
    await state.startSpeech();
    await pumpDeck(tester, spanish, state: state);
    final l10n = l10nOf(tester);

    final speaking = skillRow(l10n, Skill.speaking);
    await tester.ensureVisible(speaking);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: speaking,
        matching: find.text(l10n.deckSpeechOnlineOnly('Spanish')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: speaking, matching: find.byType(FilledButton)),
      findsNothing,
    );

    // Allowed, the row is live.
    state.settings.allowOnlineSpeech('es', true);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: speaking, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    state.settings.allowOnlineSpeech('es', false);
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.descendant(of: speaking, matching: find.text(l10n.deckSetUpVoice)),
    );
    expect(find.byType(VoicesPage), findsOneWidget);
  });

  testWidgets('speaking says the phone cannot recognise the language until '
      'the recogniser is set up', (tester) async {
    usePhone(tester);
    final state = AppState.test(
      tts: FixedTtsEngine(const <String>{'es'}),
      speech: FixedSpeechEngine(onDevice: <String>{'es'}),
      settings: SettingsNotifier(
        spokenLanguages: const <String>['en'],
        learningChosen: true,
        enabledSkills: Skill.values.toSet(),
      ),
    );
    await pumpDeck(tester, spanish, state: state);
    final l10n = l10nOf(tester);
    final speaking = skillRow(l10n, Skill.speaking);
    await tester.ensureVisible(speaking);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: speaking,
        matching: find.text(l10n.deckNoSpeech('Spanish')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a skill button starts that skill on this deck', (tester) async {
    usePhone(tester);
    await pumpDeck(tester, spanish, state: withSpanishVoice());
    final l10n = l10nOf(tester);

    await tapVisible(
      tester,
      find.descendant(
        of: skillRow(l10n, Skill.production),
        matching: find.byType(FilledButton),
      ),
    );
    final request = tester.widget<DrillPage>(find.byType(DrillPage)).request;
    expect(request.deckIds, <String>{spanish});
    expect(request.skill, Skill.production);
    expect(request.tags, isEmpty);
  });

  testWidgets('chosen tags narrow what Review all due starts', (tester) async {
    usePhone(tester);
    final state = await pumpDeck(tester, spanish);
    final l10n = l10nOf(tester);
    final entry = state.deckById(spanish)!;
    final counts = state.countsFor(entry);
    await tester.scrollUntilVisible(find.text(l10n.deckOnlyTags), 200);

    await tapVisible(tester, find.widgetWithText(FilterChip, 'food'));
    final narrowed = state
        .buildSession(DrillRequest.deck(spanish, tags: const {'food'}))
        .items
        .length;
    expect(narrowed, lessThan(counts.due + counts.fresh));
    expect(find.text(l10n.deckReviewAll(narrowed)), findsOneWidget);

    await tester.tap(find.text(l10n.deckReviewAll(narrowed)));
    await tester.pumpAndSettle();
    final request = tester.widget<DrillPage>(find.byType(DrillPage)).request;
    expect(request.deckIds, <String>{spanish});
    expect(request.skill, isNull);
    expect(request.tags, <String>{'food'});
  });

  testWidgets('a grammar deck: its cells previewed, its row live', (
    tester,
  ) async {
    usePhone(tester);
    final state = await pumpDeck(tester, grammar);
    final l10n = l10nOf(tester);
    final entry = state.deckById(grammar)!;
    final pattern = entry.deck.pattern!;

    expect(entry.cards, hasLength(entry.itemCount), reason: 'expanded (#2)');
    expect(find.text(l10n.commonCardCount(entry.itemCount)), findsOneWidget);
    expect(
      find.text(
        l10n.deckHeaderLine(
          entry.language.name,
          entry.language.iso639_3,
          l10n.deckKindGrammar,
        ),
      ),
      findsOneWidget,
    );

    // The grammar drill ships (#14), so its row is live.
    final row = skillRow(l10n, Skill.grammar);
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byType(IncomingBadge)),
      findsNothing,
    );

    final first = pattern.entries.first;
    await tester.scrollUntilVisible(
      find.text(l10n.deckGrammarCell(first.lemma, pattern.slots.first)),
      200,
    );
    expect(find.text(first.forms[pattern.slots.first]!), findsOneWidget);

    // Its row's button opens the live grammar drill.
    await tapVisible(
      tester,
      find.descendant(of: row, matching: find.byType(FilledButton)),
    );
    expect(find.text(l10n.incomingSnackBar), findsNothing);
    expect(find.byType(DrillPage), findsOneWidget);
    expect(find.byType(GrammarDrill), findsOneWidget);
  });

  testWidgets('a deck no speaker has checked says so, and Report a mistake '
      'opens a new GitHub issue about that deck while mail is incoming', (
    tester,
  ) async {
    usePhone(tester);
    final links = FixedLinks();
    final state = await pumpDeck(
      tester,
      'te-en-market',
      state: AppState.test(links: links),
    );
    final l10n = l10nOf(tester);
    final entry = state.deckById('te-en-market')!;
    expect(entry.deck.tags, contains(UnreviewedNotice.tag));

    expect(find.text(l10n.deckUnreviewed('Telugu')), findsOneWidget);
    await tapVisible(tester, find.text(l10n.deckUnreviewedReport));
    await tester.tap(find.text(l10n.reportOpenGitHub));
    await tester.pumpAndSettle();
    final url = Uri.parse(links.asked.single);
    expect(url.path, '/aaronified/fluenough/issues/new');
    expect(url.queryParameters['body'], contains('Showing: te-en-market'));
  });

  testWidgets('a checked deck shows no such notice', (tester) async {
    usePhone(tester);
    await pumpDeck(tester, spanish);
    expect(find.byType(UnreviewedNotice), findsNothing);
  });
}
