// The sentences of Find my level, over the REAL decks: a sentence item asks
// the learner to hear or read a target sentence and pick its English meaning,
// so every sentence must be a whole sentence with its own whole meaning, and
// every option a sentence of the same kind. Reading decks' question cards
// (the target is a passage's first sentence, the "meaning" is a question's
// prompt) once got in and made unanswerable questions (a Hindustani notice
// about water for the birds, with no option that meant it).
@Timeout(Duration(minutes: 15))
library;

import 'dart:io';

import 'package:fluenough/core/data/deck_parser.dart';
import 'package:fluenough/core/data/placement_course.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/reading.dart';
import 'package:fluenough/core/placement/item_generators.dart';
import 'package:fluenough/core/placement/placement_data.dart';
import 'package:fluenough/core/placement/sentence_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// The course as the app reads it for a run: its word decks, and the reading
/// decks too (the app's course holds them, a reading deck's questions being
/// cards).
PlacementLanguageData _courseWithReading(String language) {
  final files = <String, String>{};
  for (final e in Directory('decks/$language').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.yaml')) {
      files[e.path.substring('decks/'.length)] = e.readAsStringSync();
    }
  }
  final base = loadPlacementCourse(files, language: language).data;
  final reading = <PlacementDeck>[];
  for (final e in files.entries) {
    if (!RegExp(r'\nkind: "?reading"?').hasMatch(e.value)) continue;
    final deck = DeckParser.parse(e.value, source: e.key.split('/').last);
    if (deck.language.code == language && deck.native.code == 'en') {
      reading.add(PlacementDeck(id: deck.id, cards: deck.cards));
    }
  }
  return PlacementLanguageData(
    language: language,
    decks: <PlacementDeck>[...base.decks, ...reading],
  );
}

String _flat(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  group('the sentence gate on single cards', () {
    Card card(String target, String native, {String? reading}) => Card(
      id: 'x-1',
      deckId: 'x',
      target: target,
      native: native,
      reading: reading,
    );

    test('a whole sentence with its own meaning passes', () {
      expect(
        sentenceFault(
          card('जीरा तेल में भूनो।', 'Fry the cumin in oil.'),
          nonLatinCourse: true,
        ),
        isNull,
      );
      expect(
        sentenceFault(
          card('¿cómo te llamas?', 'what is your name?'),
          nonLatinCourse: false,
        ),
        isNull,
      );
    });

    test('a phrase gloss is not a sentence', () {
      expect(
        sentenceFault(
          card('दाँत साफ़ करना', "to brush one's teeth"),
          nonLatinCourse: true,
        ),
        SentenceFault.fragmentMeaning,
      );
      expect(
        sentenceFault(
          card('todos los días', 'every day'),
          nonLatinCourse: false,
        ),
        SentenceFault.fragmentMeaning,
      );
    });

    test('template text, romanised or mixed targets and a question that '
        'means a statement are kept out', () {
      expect(
        sentenceFault(
          card('मेरा नाम … है।', 'My name is …'),
          nonLatinCourse: true,
        ),
        SentenceFault.placeholder,
      );
      expect(
        sentenceFault(
          card('mera naam Ravi hai.', 'My name is Ravi.'),
          nonLatinCourse: true,
        ),
        SentenceFault.romanisedTarget,
      );
      expect(
        sentenceFault(
          card('मेरा naam रवि है।', 'My name is Ravi.'),
          nonLatinCourse: true,
        ),
        SentenceFault.mixedScript,
      );
      expect(
        sentenceFault(
          card('तुम कहाँ रहते हो?', 'You live there.'),
          nonLatinCourse: true,
        ),
        SentenceFault.moodMismatch,
      );
    });

    test('a meaning that lacks its end mark takes the target\'s', () {
      expect(
        sentenceMeaning("I don't understand", target: 'Tôi không hiểu.'),
        "I don't understand.",
      );
      expect(
        sentenceMeaning('I like it; I enjoy it.', target: 'x'),
        'I like it.',
      );
    });
  });

  for (final language in <String>['hi', 'es']) {
    group('the sentence items over the real $language decks', () {
      late PlacementLanguageData data;
      late GenContext cx;
      setUpAll(() {
        data = _courseWithReading(language);
        cx = GenContext(data, seed: 1);
      });

      test('no reading deck question is a sentence, and the sentences are '
          'those of the gate', () {
        final questions = <String>{
          for (final d in data.decks)
            for (final c in d.cards)
              if (c is QuestionCard) c.id,
        };
        expect(questions, isNotEmpty);
        expect(
          cx.sentences.where((s) => questions.contains(s.card.id)),
          isEmpty,
        );
        expect(cx.sentences, isNotEmpty);
      });

      for (final format in <String>['F5', 'F17']) {
        test('every $format item has its own translation among four '
            'sentences of one kind', () {
          final items = ItemGenerators(cx).sentencePicks(format);
          expect(items, isNotEmpty);
          for (final item in items) {
            final card = data.cardById(item.cardId)!;
            final reason = '${item.cardId} ${item.options}';
            expect(card is QuestionCard, isFalse, reason: reason);
            final own = sentenceMeaning(card.native, target: card.target);
            expect(item.options, hasLength(4), reason: reason);
            expect(item.options[item.correct], own, reason: reason);
            expect(
              item.options.map((o) => o.toLowerCase()).toSet(),
              hasLength(4),
              reason: 'duplicates: $reason',
            );
            final question = endsAsQuestion(own);
            for (final o in item.options) {
              expect(o.trim(), isNotEmpty, reason: reason);
              expect(
                RegExp(r'^["“‘(¿¡]*[\p{Lu}\p{N}]', unicode: true).hasMatch(o),
                isTrue,
                reason: 'not a sentence: "$o" in $reason',
              );
              expect(
                RegExp(r'[.!?]["”’)]*$').hasMatch(o),
                isTrue,
                reason: 'no end mark: "$o" in $reason',
              );
              expect(o.toLowerCase().startsWith('to '), isFalse, reason: o);
              expect(endsAsQuestion(o), question, reason: reason);
              expect(
                o.split(RegExp(r'\s+')).length,
                inInclusiveRange(2, 16),
                reason: reason,
              );
            }
            // What is shown and spoken is the card's own target.
            expect(_flat(item.prompt), _flat(card.target), reason: reason);
          }
        });
      }

      test('the Hindustani notice about birds is not a sentence item', () {
        if (language != 'hi') return;
        final birds = data.decks
            .expand((d) => d.cards)
            .whereType<QuestionCard>()
            .where((c) => c.target.contains('पक्षियों के लिए पानी रखें'))
            .toList();
        expect(birds, isNotEmpty);
        for (final item in <String>['F5', 'F17']) {
          final asked = ItemGenerators(cx)
              .sentencePicks(item)
              .map((i) => i.cardId)
              .toSet();
          expect(asked.intersection(birds.map((c) => c.id).toSet()), isEmpty);
        }
      });
    });
  }

  test('no sentence of any language fails the gate, and the audit keeps a '
      'reason for each card it leaves out', () {
    final languages = <String>[
      for (final e in Directory('decks').listSync())
        if (e is Directory &&
            RegExp(r'^[a-z]{2,3}$').hasMatch(e.path.split('/').last))
          e.path.split('/').last,
    ];
    expect(languages, containsAll(<String>['es', 'hi', 'bn']));
    for (final language in languages) {
      final data = _courseWithReading(language);
      final cx = GenContext(data, seed: 1);
      final nonLatin = isNonLatinCourse(data);
      for (final s in cx.sentences) {
        expect(s.card is QuestionCard, isFalse, reason: s.card.id);
        expect(
          sentenceFault(s.card, nonLatinCourse: nonLatin),
          isNull,
          reason: '$language ${s.card.id} ${s.text}',
        );
        expect(
          s.english,
          sentenceMeaning(s.card.native, target: s.card.target),
          reason: s.card.id,
        );
        expect(_flat(s.text), _flat(s.card.target), reason: s.card.id);
      }
      expect(
        cx.sentences
            .map((s) => s.card.id)
            .toSet()
            .intersection(cx.rejectedSentences.keys.toSet()),
        isEmpty,
        reason: language,
      );
    }
  });

  test('the prompt of a sentence pick, written or heard, asks for its '
      'meaning', () {
    final arb = File('lib/l10n/app_en.arb').readAsStringSync();
    expect(
      arb,
      contains('"findLevelSentenceMeaning": "What does this sentence mean?"'),
    );
    expect(arb, isNot(contains('sounds right')));
    final view = File('lib/features/placement/v3_question_view.dart')
        .readAsStringSync();
    expect(view, contains("'F5' || 'F17' => l10n.findLevelSentenceMeaning"));
  });
}
