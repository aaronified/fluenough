// Split out of accessibility_test.dart so that CI can spread it over its shards;
// the tests and their names are unchanged. This file holds: the screen reader never reads out the answer asked for, deck text in an interface string is read in its language: a wrong answer's feedback, a language's own name, but not a heard number's digits, a phone at 2x text draws the app at 1.4x (#505), and below the cap keeps its own size, a toast is a live region a screen reader hears.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/features/onboarding/onboarding_flow.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/snack.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'support/harness.dart';
import 'support/accessibility_shared.dart';

/// The parts of [finder]'s screen-reader label marked as another language,
/// by locale.
Map<String, String> quotedIn(WidgetTester tester, Finder finder) {
  final label = tester.getSemantics(finder).attributedLabel;
  return <String, String>{
    for (final a in label.attributes.whereType<LocaleStringAttribute>())
      label.string.substring(a.range.start, a.range.end): a.locale
          .toLanguageTag(),
  };
}

/// The nodes on the screen reader's tree whose label or value has [text].
FinderBase<SemanticsNode> readsOut(String text) => find.semantics.byPredicate(
  (node) => node.label.contains(text) || node.value.contains(text),
);

const Key _say = Key('say');

/// A screen with an app bar and a button that toasts.
class _Toasting extends StatelessWidget {
  const _Toasting();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Screen')),
    body: Center(
      child: Builder(
        builder: (context) => TextButton(
          key: _say,
          onPressed: () => showAppSnackBar(context, 'Saved'),
          child: const Text('Say'),
        ),
      ),
    ),
  );
}

void main() {
  group('the screen reader never reads out the answer asked for', () {
    void expectHidden(String answer) => expect(readsOut(answer), findsNothing);

    testWidgets('recognition: the meaning, until shown', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck(
            'es-en-core-100',
            skill: Skill.recognition,
          ),
          preset: const DrillPreset(target: 'la casa'),
        ),
      );
      final card = tester
          .widget<RecognitionDrill>(find.byType(RecognitionDrill))
          .session
          .item
          .card;
      expect(readsOut(card.target), findsAny);
      expectHidden(card.native);
      await tester.tap(find.text(l10nOf(tester).drillShowAnswer));
      await tester.pumpAndSettle();
      expect(readsOut(card.native), findsAny);
      semantics.dispose();
    });

    testWidgets('production: the word', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck('es-en-core-100', skill: Skill.production),
          preset: const DrillPreset(target: 'el niño'),
        ),
      );
      expect(readsOut('the boy'), findsAny);
      expectHidden('niño');
      semantics.dispose();
    });

    testWidgets('listening: the word, and its meaning', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        DrillPage(
          request: DrillRequest.deck('es-en-core-100', skill: Skill.listening),
          preset: const DrillPreset(target: 'el niño'),
        ),
        state: AppState.test(tts: FixedTtsEngine(<String>{'es'})),
      );
      expectHidden('niño');
      expectHidden('the boy');
      semantics.dispose();
    });

    testWidgets('number practice: the words for the digits', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final settings = SettingsNotifier()
        ..setSkillEnabled(Skill.recognition, false)
        ..setSkillEnabled(Skill.listening, false);
      await pumpScreen(
        tester,
        DrillPage(request: DrillRequest.numbers('hi-en-numbers-big')),
        state: AppState.test(settings: settings),
      );
      final card = tester
          .widget<TypedDrill>(find.byType(TypedDrill))
          .session
          .item
          .card;
      expect(readsOut(card.native), findsAny);
      expectHidden(card.target);
      semantics.dispose();
    });
  });

  testWidgets('deck text in an interface string is read in its language: '
      'a wrong answer\'s feedback, a language\'s own name, but not a heard '
      'number\'s digits', (tester) async {
    const spanish = LanguageInfo(
      code: 'es',
      iso639_3: 'spa',
      name: 'Spanish',
      script: 'latin',
    );
    final span = quotingTarget('You typed “nino”. Written: el niño', <String>[
      'niño',
      'el niño',
      'nino',
    ], spanish);
    expect(
      [
        for (final child in span.children!.cast<TextSpan>())
          (child.text, child.locale?.languageCode),
      ],
      <(String?, String?)>[
        ('You typed “', null),
        ('nino', 'es'),
        ('”. Written: ', null),
        ('el niño', 'es'),
      ],
      reason: 'the longest quote wins, and the rest stays unmarked',
    );

    usePhone(tester);
    final semantics = tester.ensureSemantics();
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.deck('es-en-core-100', skill: Skill.production),
        preset: const DrillPreset(
          target: 'el niño',
          typed: 'la mesa',
          check: true,
        ),
      ),
    );
    final l10n = l10nOf(tester);
    expect(
      quotedIn(tester, find.text(l10n.feedbackAnswer('el niño'))),
      <String, String>{'el niño': 'es'},
    );

    await pumpScreen(
      tester,
      OnboardingFlow(startAt: 'languages', choices: choices),
    );
    await tapShown(
      tester,
      find.byKey(const ValueKey<String>('onboarding-add-language')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('languages-add-search')),
      'Bengali',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('add-bn')));
    await tester.pumpAndSettle();
    // The Know sheet names the language by its own name, read in its voice.
    final bengali = find.text(l10n.spokenOption('Bengali', 'বাংলা'));
    expect(quotedIn(tester, bengali), <String, String>{'বাংলা': 'bn'});

    final settings = SettingsNotifier()
      ..setSkillEnabled(Skill.recognition, false)
      ..setSkillEnabled(Skill.production, false);
    await pumpScreen(
      tester,
      DrillPage(request: DrillRequest.numbers('hi-en-numbers-big')),
      state: AppState.test(
        tts: FixedTtsEngine(<String>{'hi'}),
        settings: settings,
      ),
    );
    final card = tester
        .widget<TypedDrill>(find.byType(TypedDrill))
        .session
        .item
        .card;
    await tester.enterText(find.byType(TextField), '1');
    await tester.pump();
    await tester.tap(find.text(l10n.drillCheck));
    await tester.pumpAndSettle();
    expect(
      quotedIn(tester, find.text(l10n.feedbackAnswer(card.native))),
      isEmpty,
    );
    semantics.dispose();
  });

  testWidgets('a phone at 2x text draws the app at 1.4x (#505), and below '
      'the cap keeps its own size', (tester) async {
    usePhone(tester, textScale: 2.0);
    await pumpApp(tester);
    TextScaler scaler() =>
        MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first));
    expect(AppSizes.maxTextScale, 1.4);
    expect(scaler().scale(10), closeTo(14, 0.001));

    usePhone(tester, textScale: 1.2);
    await tester.pumpAndSettle();
    expect(scaler().scale(10), closeTo(12, 0.001));
  });

  testWidgets('a toast is a live region a screen reader hears', (tester) async {
    addTearDown(hideAppSnackBar);
    usePhone(tester);
    final handle = tester.ensureSemantics();
    await pumpScreen(tester, const _Toasting());
    await tester.tap(find.byKey(_say));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Saved')),
      matchesSemantics(label: 'Saved', isLiveRegion: true),
    );
    handle.dispose();
  });
}
