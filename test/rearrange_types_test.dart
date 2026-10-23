// Rearrange is eligible by the card's data: how many words its target has,
// not what kind of card it is (ADR-0039, #522 step 5).
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/question_type.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:flutter_test/flutter_test.dart';

Card card(String target, {String? pos, List<String>? words}) => Card(
  id: 'x-0001',
  deckId: 'x-en-core',
  target: target,
  native: 'meaning',
  pos: pos,
  words: words,
);

bool _yes(SessionItem item) => true;
const context = QuestionContext(canChoose: _yes);

Ask? production(Card card) => questionTypeFor(
  SessionItem(card: card, mode: DrillMode.production, state: null),
  context,
)?.ask;

void main() {
  test('a target of three words or more is rearranged, whatever its pos', () {
    for (final pos in <String?>[null, 'noun', 'verb', 'phrase', 'sentence']) {
      expect(
        production(card('yo soy Ana', pos: pos)),
        Ask.rearrange,
        reason: 'pos $pos',
      );
    }
  });

  test('two words are rearranged only as a phrase; one word never is', () {
    expect(production(card('muy bien', pos: 'phrase')), Ask.rearrange);
    expect(production(card('buenos días', pos: 'noun')), isNot(Ask.rearrange));
    expect(production(card('hola', pos: 'phrase')), isNot(Ask.rearrange));
  });

  test('the words a deck gives count, for a script written without spaces', () {
    expect(
      production(card('我听不懂', words: <String>['我', '听', '不懂'])),
      Ask.rearrange,
    );
    expect(production(card('我听不懂')), isNot(Ask.rearrange));
  });

  test('only production is asked by rearranging', () {
    final item = SessionItem(
      card: card('yo soy Ana'),
      mode: DrillMode.recognition,
      state: null,
    );
    expect(rearrangeType.eligible(item, context), isTrue);
    expect(rearrangeType.skill, DrillMode.production);
    expect(questionTypeFor(item, context)?.ask, isNot(Ask.rearrange));
  });
}
