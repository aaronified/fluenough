import '../models/card.dart';
import '../models/reading.dart';
import 'placement_data.dart';

// Which cards may be a sentence of Find my level, and why the others may not
// (docs/placement-bad-sentences.md lists the cards a course fails). A sentence
// item asks the learner to hear or read a target sentence and pick its
// English meaning, so a card is a sentence only when both sides are one: a
// whole sentence in the course's own script, and a whole English sentence
// that means it. Language-agnostic; pure Dart.

/// Why a card is not a sentence of the course, in the words of the report.
enum SentenceFault {
  /// A reading deck's question card: its target is the passage's first
  /// sentence, but its meaning is the question's prompt, not that sentence's.
  questionCard('a reading deck question, not a sentence with its meaning'),

  /// Template or placeholder text left in the target or the meaning.
  placeholder('placeholder or template text left in the card'),

  /// Letters of two scripts in the target (a romanised word in the script).
  mixedScript('the target mixes scripts'),

  /// A course written in a native script whose card is in Latin letters.
  romanisedTarget('the target is romanised, the course is not'),

  /// The target is not spoken as the card shows it (a line break, a tab).
  spokenDiffers('the spoken text differs from the displayed target'),

  /// The meaning is a phrase or a fragment, not a sentence: it does not start
  /// like a sentence, has no end mark, or is a gloss ("to brush one's
  /// teeth").
  fragmentMeaning('the meaning is a phrase or fragment, not a sentence'),

  /// The meaning is a single word or over sixteen: not the shape of the
  /// target's three to ten words.
  meaningLength('the meaning is too short or too long for the target'),

  /// A question whose meaning is a statement or the other way round.
  moodMismatch('the target and its meaning differ in being a question'),

  /// The same target, or the same meaning, as an earlier sentence: the right
  /// option could not be told from a wrong one.
  duplicate('the same target or meaning as an earlier card');

  const SentenceFault(this.why);

  /// The reason, as the report and the log give it.
  final String why;
}

/// A card kept out of the sentences, with its fault.
class SentenceRejection {
  const SentenceRejection(this.deckId, this.cardId, this.fault, this.detail);

  final String deckId;
  final String cardId;
  final SentenceFault fault;

  /// The target and meaning as the card has them, for the report.
  final String detail;
}

final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _latinLetter = RegExp(r'\p{Script=Latin}', unicode: true);
final RegExp _placeholder = RegExp(
  r'___|\{|\}|\bTODO\b|\bXXX\b|\?\?\?|(^|\s)(…|\.\.\.)(\s|$|[.!?।。])',
);
final RegExp _questionEnd = RegExp(r'[?？؟]["”’)]*$');

// What a target's end says about its mood, conservatively. Only an explicit
// question mark counts as a question, in any script: `?`, `？`, `؟` (Arabic),
// `;` and U+037E (Greek), `՞` (Armenian, inside the last word). A final `。`
// or `।` gives no signal (Japanese and Chinese write questions with `。` or a
// particle such as か or 吗, Hindi with `।`), so it never proves a statement;
// only an ASCII full stop or `!` does.
final RegExp _targetQuestionEnd = RegExp(r'[?？؟;\u037E]["”’)]*$|՞');
final RegExp _asciiStatementEnd = RegExp(r'[.!]["”’)]*$');

/// The meaning of a sentence card as one English sentence: the first
/// alternative (up to a semicolon), without notes in brackets, and with its
/// commas kept (`shortGloss` of a word cuts at the comma, which would leave a
/// sentence's first clause).
String sentenceMeaning(String native, {String target = ''}) {
  final whole = native.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  var first = whole.split(';').first.trim();
  final end = RegExp(r'[.!?]["”’)]*$');
  // "I like it; I enjoy it." keeps the mark of its last alternative.
  if (first.isNotEmpty && !end.hasMatch(first) && end.hasMatch(whole)) {
    first = '$first${whole.substring(whole.length - 1)}';
  }
  // A meaning written with no end mark takes the target's: a question or a
  // statement.
  final t = target.trim();
  if (first.isNotEmpty && !end.hasMatch(first) && !first.startsWith('to ')) {
    if (_targetQuestionEnd.hasMatch(t)) {
      first = '$first?';
    } else if (_asciiStatementEnd.hasMatch(t)) {
      first = '$first.';
    }
  }
  // A lower-case gloss of a sentence ("what is your name?") is capitalised.
  if (first.isNotEmpty && end.hasMatch(first)) {
    first = first[0].toUpperCase() + first.substring(1);
  }
  return first;
}

/// Whether [meaning] ends as a question.
bool endsAsQuestion(String meaning) => _questionEnd.hasMatch(meaning.trim());

/// Whether [text] carries an explicit question mark, in any script.
bool targetHasQuestionMark(String text) =>
    _targetQuestionEnd.hasMatch(text.trim());

/// Why [c], a card of three to ten words, is not a sentence; null when it is.
/// [nonLatinCourse] is whether most of the course is not written in Latin
/// letters.
SentenceFault? sentenceFault(Card c, {required bool nonLatinCourse}) {
  if (c is QuestionCard) return SentenceFault.questionCard;
  final target = c.target;
  final meaning = sentenceMeaning(c.native, target: target);
  if (_placeholder.hasMatch(target) || _placeholder.hasMatch(c.native)) {
    return SentenceFault.placeholder;
  }
  if (RegExp(r'[\n\t\r]').hasMatch(target)) return SentenceFault.spokenDiffers;
  var hasLatin = false;
  var hasOther = false;
  for (final m in _letter.allMatches(target)) {
    if (_latinLetter.hasMatch(m.group(0)!)) {
      hasLatin = true;
    } else {
      hasOther = true;
    }
  }
  if (hasLatin && hasOther) return SentenceFault.mixedScript;
  if (nonLatinCourse && hasLatin && !hasOther) {
    return SentenceFault.romanisedTarget;
  }
  // The meaning starts like a sentence (a capital, a digit or a quote), and
  // ends with a mark; a gloss ("to brush one's teeth") or a clause with no
  // end does not.
  final starts = RegExp(r'^["“‘(¿¡]*[\p{Lu}\p{N}]', unicode: true);
  final ends = RegExp(r'[.!?]["”’)]*$');
  if (!starts.hasMatch(meaning) ||
      !ends.hasMatch(meaning) ||
      RegExp(r'^to\s', caseSensitive: false).hasMatch(meaning)) {
    return SentenceFault.fragmentMeaning;
  }
  final words = meaning.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  if (words < 2 || words > 16) return SentenceFault.meaningLength;
  // When in doubt the card stays: a mismatch needs an explicit question mark
  // on one side and, on the other, a plain statement ending.
  final targetQ = targetHasQuestionMark(target);
  final meaningQ = endsAsQuestion(meaning);
  if ((targetQ && !meaningQ) ||
      (!targetQ && meaningQ && _asciiStatementEnd.hasMatch(target.trim()))) {
    return SentenceFault.moodMismatch;
  }
  return null;
}

/// Whether most of the letters of [data]'s cards are not Latin.
bool isNonLatinCourse(PlacementLanguageData data) {
  var latin = 0;
  var other = 0;
  for (final deck in data.decks) {
    for (final c in deck.cards) {
      for (final m in _letter.allMatches(c.target)) {
        if (_latinLetter.hasMatch(m.group(0)!)) {
          latin++;
        } else {
          other++;
        }
      }
    }
  }
  return other > latin;
}

/// The cards of three to ten words that [data] keeps out of its sentences,
/// each with its fault, in deck order. [isSentenceShaped] is the course's own
/// test of a card being sentence-shaped (not a word card), so the report
/// holds only cards a sentence item could have used.
List<SentenceRejection> sentenceRejections(
  PlacementLanguageData data, {
  required bool Function(Card c) isSentenceShaped,
}) {
  final out = <SentenceRejection>[];
  final nonLatin = isNonLatinCourse(data);
  final targets = <String>{};
  final meanings = <String>{};
  final seen = <String>{};
  for (final deck in data.decks) {
    for (final c in deck.cards) {
      if (c.rule != null || c.isGrammarCell || c.isLetterOrDigit) continue;
      if (!seen.add(c.id)) continue;
      if (c.native.trim().isEmpty || c.practiceOnly) continue;
      if (!isSentenceShaped(c)) continue;
      var fault = sentenceFault(c, nonLatinCourse: nonLatin);
      if (fault == null) {
        final t = c.target.trim().toLowerCase();
        final m = sentenceMeaning(c.native, target: c.target).toLowerCase();
        if (!targets.add(t) || !meanings.add(m)) {
          fault = SentenceFault.duplicate;
        }
      }
      if (fault != null) {
        out.add(
          SentenceRejection(deck.id, c.id, fault, '${c.target} | ${c.native}'),
        );
      }
    }
  }
  return out;
}
