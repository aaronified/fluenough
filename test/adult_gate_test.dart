// The adult gate (#628; owner, 2026-10-23: with "Adult content" off, an adult
// deck is "Hidden everywhere"): not listed, not taught, not in Today or a
// review, and it comes back when the setting is turned on.
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:flutter_test/flutter_test.dart';

const String _plain = 'es-en-plain';
const String _adult = 'es-en-rude';

String _cards(String prefix, int from, int count, {String extra = ''}) => [
  for (var i = 0; i < count; i++)
    '  - { id: es-${from + i}, target: "$prefix${i}x", native: "$prefix $i"'
        '${i == 0 ? extra : ''} }',
].join('\n');

String _deck(String id, String tags, String cards) =>
    '''
schema: 1
id: $id
name: "$id"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
$tags
cards:
$cards
''';

/// An ordinary deck with one rude card in it, and a deck of rude words.
Future<AppState> _state() async {
  final state = AppState.test(
    decks: MemoryDeckSource(<String, String>{
      'decks/es/$_plain.yaml': _deck(
        _plain,
        '',
        _cards('plain', 9100, 12, extra: ', register: "offensive"'),
      ),
      'decks/es/$_adult.yaml': _deck(
        _adult,
        'tags: ["offensive", "rated"]',
        _cards('rude', 9200, 12),
      ),
    }),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

Set<String> _ids(Iterable<SessionItem> items) => {
  for (final item in items) item.card.id,
};

const String _rudeCardInPlain = 'es-9100';

void main() {
  group('with Adult content off', () {
    test('it is off by default, and an adult deck and a rude card are not '
        'in the catalogue', () async {
      final state = await _state();
      expect(state.settings.adultContent, isFalse);
      expect(state.decks.map((d) => d.id), <String>[_plain]);
      expect(state.deckById(_adult), isNull);
      expect(state.deckById(_plain)!.cards.map((c) => c.id), hasLength(11));
      expect(
        state.deckById(_plain)!.cards.map((c) => c.id),
        isNot(contains(_rudeCardInPlain)),
      );
    });

    test('their words never come up in a lesson, and come back when it '
        'is on', () async {
      final state = await _state();
      final request = DrillRequest.lesson(language: 'es');
      for (var i = 0; i < 3; i++) {
        final ids = _ids(state.lessonFor(request));
        expect(ids, isNotEmpty);
        expect(ids.where((id) => id.startsWith('es-92')), isEmpty);
        expect(ids, isNot(contains(_rudeCardInPlain)));
      }
      expect(state.untaughtCards('es').map((c) => c.deckId).toSet(), {_plain});

      state.settings.adultContent = true;
      expect(state.decks.map((d) => d.id), <String>[_plain, _adult]);
      expect(
        state.untaughtCards('es').map((c) => c.id),
        containsAll(<String>[_rudeCardInPlain, 'es-9200']),
      );
    });

    test('a rude word already learned is left out of Today and the '
        'reviews, and is back when it is on', () async {
      final state = await _state();
      state.settings.adultContent = true;
      // Learn the words of both decks, so that each is scheduled.
      for (final deck in <String>[_adult, _plain]) {
        for (final item
            in state.buildSession(DrillRequest.untaught(deck)).items) {
          state.record(item, 1);
        }
      }
      final on = _ids(state.buildSession(const DrillRequest.today()).items);
      expect(on.where((id) => id.startsWith('es-92')), isNotEmpty);
      expect(on, contains(_rudeCardInPlain));

      state.settings.adultContent = false;
      final off = _ids(state.buildSession(const DrillRequest.today()).items);
      expect(off, isNotEmpty);
      expect(off.where((id) => id.startsWith('es-92')), isEmpty);
      expect(off, isNot(contains(_rudeCardInPlain)));
      expect(state.buildSession(DrillRequest.deck(_adult)).isEmpty, isTrue);
    });
  });
}
