// A creator's name must not give away a work the learner has not reached:
// one cited only by a card of a hidden deck, or only by an above-level work of
// a deck that is not woven into the course, is kept out of the People list and
// the timeline, though no woven item cites them.

import 'package:fluenough/features/culture/culture_deck_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/culture_world.dart';
import 'support/harness.dart';
import 'support/kinds_course.dart';

const String _source =
    'source: { author: "X", work: "Y", date: 1900, edition: "E", '
    'basis: "public-domain", author_died: 1950, jurisdiction: "ES", '
    'rights_checked: "2026-11-12" }';

const String _extraCreators = '''
  - id: "zz-oculto"
    name:
      zz: { text: "Hidden Poet" }
      en: { text: "Hidden Poet" }
    born: 1880
    died: 1950
    era: "plata"
    bio:
      en: "Only a hidden deck quotes this poet."
  - id: "zz-lejano"
    name:
      zz: { text: "Faraway Poet" }
      en: { text: "Faraway Poet" }
    born: 1890
    died: 1960
    era: "plata"
    bio:
      en: "Only an above-level work of an unwoven deck quotes this poet."
''';

Map<String, String> _world() {
  final files = cultureWorld();
  files['decks/creators/zz.yaml'] =
      '${files['decks/creators/zz.yaml']}$_extraCreators';
  return <String, String>{
    ...files,
    ...kindsDeck(
      'zz',
      'oculto',
      <KindsCard>[
        kindsCard(
          'zz-8001',
          'el verso oculto',
          'the hidden line',
          extra: 'creator: "zz-oculto"\n    $_source',
        ),
      ],
      header: 'genre: "professional"\nprofessional: "medicine"\nhidden: true\nlevel: "A1"',
    ),
    ...kindsDeck('zz', 'lejano', <KindsCard>[
      kindsCard(
        'zz-8101',
        'el verso lejano',
        'the faraway line',
        extra: 'creator: "zz-lejano"\n    $_source',
      ),
    ], header: 'genre: "professional"\nprofessional: "law"\nlevel: "B1"'),
  };
}

void main() {
  testWidgets('People names neither a hidden-deck nor an above-level creator', (
    tester,
  ) async {
    usePhone(tester);
    final state = await cultureApp(reach: 'b1', files: _world());
    await pumpScreen(
      tester,
      const CultureDeckPage(language: 'zz'),
      state: state,
    );
    expect(find.text('Miguel de Cervantes'), findsOneWidget);
    expect(find.text('Hidden Poet'), findsNothing);
    expect(find.text('Faraway Poet'), findsNothing);
  });

  test('the timeline leaves both out, spans and legacy marks', () async {
    final state = await cultureApp(reach: 'b1', files: _world());
    expect(
      state.creatorsCitedIn('zz'),
      containsAll(<String>['zz-oculto', 'zz-lejano']),
    );
    final line = state.cultureTimelineOf('zz');
    final ids = line.spans.map((s) => s.creator.id).toSet();
    expect(ids, containsAll(<String>['zz-machado', 'zz-cervantes']));
    expect(ids, isNot(contains('zz-oculto')));
    expect(ids, isNot(contains('zz-lejano')));
  });

  test('support never shows a creator a hidden deck cites', () async {
    final state = await cultureApp(reach: 'b1', files: _world());
    final shown = state.creatorsShownIn('zz', support: true);
    expect(shown, isNot(contains('zz-oculto')));
    expect(shown, isNot(contains('zz-lejano')));
  });
}
