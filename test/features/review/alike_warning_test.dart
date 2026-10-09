import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/review/alike_warning.dart';

import '../../support/harness.dart';
import '../../support/review_fixture.dart';

/// The sound-alike warning on the drill card (docs/plans/offensive-words.md):
/// only once the word is shown or answered, never before, and never naming
/// the rude word without adult content.
void main() {
  testWidgets('seen words: after the answer is shown, not before', (
    tester,
  ) async {
    usePhone(tester);
    final request = DrillRequest.deck(wordsDeck, skill: Skill.recognition);
    await pumpScreen(
      tester,
      DrillPage(
        request: request,
        preset: const DrillPreset(target: 'విధవ'),
      ),
      state: await reviewState(),
    );
    expect(find.byType(AlikeWarning), findsNothing);

    await pumpScreen(
      tester,
      DrillPage(
        key: UniqueKey(),
        request: request,
        preset: const DrillPreset(target: 'విధవ', reveal: true),
      ),
      state: await reviewState(),
    );
    final l10n = l10nOf(tester);
    expect(find.byType(AlikeWarning), findsOneWidget);
    expect(find.text(l10n.alikeCarefulSpeaking), findsOneWidget);
    expect(find.text(l10n.alikeSpeakingRude), findsOneWidget);
    expect(find.text(l10n.alikeHidden), findsOneWidget);
    expect(find.textContaining('వెధవ'), findsNothing);
  });

  testWidgets('written words: after the answer is checked, not before', (
    tester,
  ) async {
    usePhone(tester);
    final request = DrillRequest.deck(wordsDeck, skill: Skill.production);
    await pumpScreen(
      tester,
      DrillPage(
        request: request,
        preset: const DrillPreset(target: 'విధవ'),
      ),
      state: await reviewState(),
    );
    expect(find.byType(AlikeWarning), findsNothing);

    await pumpScreen(
      tester,
      DrillPage(
        key: UniqueKey(),
        request: request,
        preset: const DrillPreset(target: 'విధవ', typed: 'విధవ', check: true),
      ),
      state: await reviewState(),
    );
    expect(find.byType(AlikeWarning), findsOneWidget);
  });

  testWidgets('a word like no rude word has no warning', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.deck(wordsDeck, skill: Skill.recognition),
        preset: const DrillPreset(target: 'అమ్మ', reveal: true),
      ),
      state: await reviewState(),
    );
    expect(find.byType(AlikeWarning), findsNothing);
  });

  testWidgets('with adult content on, the warning names the rude word and its '
      'reading', (tester) async {
    usePhone(tester);
    final state = await reviewState();
    await pumpScreen(
      tester,
      Scaffold(
        body: AlikeWarning.forCard(
          state,
          state.deckById(wordsDeck)!.cards.first,
          state.deckById(wordsDeck)!.language,
        ).single,
      ),
      state: state,
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.alikeHidden), findsOneWidget);

    await pumpScreen(
      tester,
      Scaffold(
        body: AlikeWarning(
          kind: AlikeKind.sound,
          named: state.deckById(rudeDeck)!.cards.single,
          language: state.deckById(rudeDeck)!.language,
          care: 'Keep the short i.',
        ),
      ),
      state: state,
    );
    expect(find.text(l10n.alikeHidden), findsNothing);
    expect(
      find.text(l10n.reviewAlikeSounds('వెధవ', 'vedhava')),
      findsOneWidget,
    );
    expect(find.text('Keep the short i.'), findsOneWidget);
  });

  testWidgets('a look-alike says to take care when writing', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const Scaffold(body: AlikeWarning(kind: AlikeKind.look)),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.alikeCarefulWriting), findsOneWidget);
    expect(find.text(l10n.alikeWritingRude), findsOneWidget);
  });
}
