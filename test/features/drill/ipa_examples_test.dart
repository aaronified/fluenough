// An IPA card's examples (ADR-0041): each marked as having the card's sound
// or not, in the voice of its own language, those of languages learned first.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/drill/ipa_examples.dart';

import '../../support/harness.dart';
import '../../support/ipa_course.dart';

CardExample example(String target, String language, {bool sounds = true}) =>
    CardExample(
      target: target,
      native: target,
      language: language,
      sounds: sounds,
    );

void main() {
  test(
    'the examples of a language learned come first, otherwise as written',
    () {
      final examples = <CardExample>[
        example('hot', 'en'),
        example('pato', 'es'),
        example('go', 'en', sounds: false),
        example('kal', 'hi'),
      ];
      expect(
        IpaExamples.ordered(examples, <String>{
          'hi',
          'es',
        }).map((e) => e.target),
        <String>['pato', 'kal', 'hot', 'go'],
      );
      expect(
        IpaExamples.ordered(examples, <String>{}).map((e) => e.target),
        <String>['hot', 'pato', 'go', 'kal'],
      );
    },
  );

  testWidgets('says which example has the sound and which does not, and '
      'plays each in its own language\'s voice', (tester) async {
    usePhone(tester);
    final tts = FixedTtsEngine(<String>{'en'});
    final state = ipaApp(<String>['es', 'ipa'], scope: null, tts: tts);
    addTearDown(state.dispose);
    await state.load();
    final card = state
        .deckById('ipa-en-basics')!
        .cards
        .firstWhere((c) => c.id == 'ipa-0002');
    await pumpScreen(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: IpaExamples(
            card: card,
            language: state.deckOf(card)!.language,
          ),
        ),
      ),
      state: state,
    );
    expect(find.text('Has this sound'), findsNWidgets(2));
    expect(find.text('Does not have this sound'), findsOneWidget);
    expect(find.text('/hɒt/'), findsOneWidget);
    // Spanish, a language learned, comes first; the phone has no Spanish
    // voice, so it has no speaker, and the English words have one each.
    // Each word shows twice, as its translation says it too.
    final order = <String>{
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (<String>['pato', 'hot', 'go'].contains(t.data)) t.data!,
    }.toList();
    expect(order, <String>['pato', 'hot', 'go']);
    expect(find.byTooltip('Play pato'), findsNothing);
    await tester.tap(find.byTooltip('Play go'));
    await tester.pump();
    expect(tts.spoken.map((s) => (s.text, s.bcp47)), <(String, String)>[
      ('go', 'en'),
    ]);
  });
}
