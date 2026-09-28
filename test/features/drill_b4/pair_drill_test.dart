import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/pair_drill.dart';
import 'package:fluenough/features/drill/pair_fixture.dart';
import 'package:fluenough/features/gallery/gallery_entry.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/ui/widgets/feedback_banner.dart';
import 'package:fluenough/ui/widgets/incoming.dart';
import 'package:fluenough/ui/widgets/play_button.dart';

import '../../support/harness.dart';

final MinimalPair first = pairFixtureRounds.first.pair;

AppState pairOn([FixedTtsEngine? tts]) => AppState.test(
  features: FeatureRegistry.all(),
  tts: tts ?? FixedTtsEngine(const <String>{'hi'}),
);

FeedbackBanner banner(WidgetTester tester) =>
    tester.widget<FeedbackBanner>(find.byType(FeedbackBanner));

Future<void> choose(WidgetTester tester, PairSound sound) async {
  await tester.tap(find.text(sound.target));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('play speaks the sound being asked, at the learner rate', (
    tester,
  ) async {
    usePhone(tester);
    final tts = FixedTtsEngine(const <String>{'hi'});
    final state = await pumpScreen(
      tester,
      const PairDrill(),
      state: pairOn(tts),
    );
    expect(pairFixtureRounds.first.heard, first.b);

    await tester.tap(find.byType(PlayButton));
    await tester.pumpAndSettle();
    expect(tts.spoken, hasLength(1));
    expect(tts.spoken.single.text, first.b.target);
    expect(tts.spoken.single.bcp47, pairFixtureLanguage.ttsTag);
    expect(tts.spoken.single.rate, state.settings.ttsRate());
  });

  testWidgets('choosing the sound played says so, with the contrast', (
    tester,
  ) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester, const PairDrill(), state: pairOn());
    final l10n = l10nOf(tester);
    expect(find.text(l10n.drillPairQuestion), findsOneWidget);
    for (final sound in <PairSound>[first.a, first.b]) {
      expect(find.text(sound.reading), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          l10n.drillPairOption(sound.target, sound.reading),
        ),
        findsOneWidget,
      );
    }
    expect(find.text(first.contrast), findsNothing);

    await choose(tester, first.b);
    expect(banner(tester).kind, FeedbackKind.correct);
    expect(banner(tester).title, l10n.feedbackPairCorrect(first.b.reading));
    expect(banner(tester).detail, l10n.feedbackPairHeard(first.b.target));
    expect(find.text(first.contrast), findsOneWidget);
    final options = tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(options, hasLength(2));
    expect(options.every((b) => b.onPressed == null), isTrue);

    await tester.tap(find.text(l10n.commonContinue));
    await tester.pumpAndSettle();
    expect(find.text(l10n.drillPositionShort(2, 2)), findsOneWidget);
    expect(find.text(pairFixtureRounds[1].pair.a.target), findsOneWidget);
    expect(find.byType(FeedbackBanner), findsNothing);
    semantics.dispose();
  });

  testWidgets('choosing the other says what it was, and what you heard', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(tester, const PairDrill(), state: pairOn());
    final l10n = l10nOf(tester);

    await choose(tester, first.a);
    expect(banner(tester).kind, FeedbackKind.wrong);
    expect(banner(tester).title, l10n.feedbackPairWrong(first.b.reading));
    expect(banner(tester).detail, l10n.feedbackPairHeard(first.b.target));
    expect(find.text(first.contrast), findsOneWidget);
  });

  testWidgets('is disabled while its feature is incoming', (tester) async {
    usePhone(tester);
    final tts = FixedTtsEngine(const <String>{'hi'});
    await pumpScreen(tester, const PairDrill(), state: AppState.test(tts: tts));
    final l10n = l10nOf(tester);
    expect(
      tester.widget<PlayButton>(find.byType(PlayButton)).onPressed,
      isNull,
    );
    expect(find.text(l10n.incomingBadge), findsOneWidget);

    await tester.tap(find.byType(PlayButton));
    await tester.tap(find.byType(IncomingFeature));
    await tester.pump();
    expect(tts.spoken, isEmpty);
    expect(find.text(l10n.incomingSnackBar), findsOneWidget);
    expect(find.byType(FeedbackBanner), findsNothing);
  });

  testWidgets('every state fits at 1.0 and 2.0, light and dark', (
    tester,
  ) async {
    usePhone(tester);
    final app = AppState.test();
    await app.load();
    for (final scale in <double>[1.0, 2.0]) {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      for (final GalleryEntry entry in <GalleryEntry>[
        ...pairGalleryEntries,
        ...pairGalleryStates,
      ]) {
        for (final dark in <bool>[false, true]) {
          await pumpScreen(
            tester,
            GalleryPreview(key: UniqueKey(), entry: entry, dark: dark),
            state: app,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.id} $scale $dark',
          );
          expect(find.byType(PairDrill), findsOneWidget);
        }
      }
    }
  });

  testWidgets('shows the sound played and a wrong pick in the dark theme', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const PairDrill(picked: PairSide.a),
      state: pairOn(),
      themeMode: ThemeMode.dark,
    );
    final scheme = Theme.of(tester.element(find.text(first.a.target)))
        .colorScheme;
    expect(scheme.brightness, Brightness.dark);
    Color? fill(PairSound sound) => tester
        .widget<OutlinedButton>(
          find.ancestor(
            of: find.text(sound.target),
            matching: find.byType(OutlinedButton),
          ),
        )
        .style!
        .backgroundColor!
        .resolve(const <WidgetState>{WidgetState.disabled});
    expect(fill(first.b), scheme.primaryContainer);
    expect(fill(first.a), scheme.errorContainer);
  });
}
