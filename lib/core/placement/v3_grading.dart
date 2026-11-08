import '../grading/canonical.dart';
import '../grading/diacritics.dart';
import 'item_registry.dart';
import 'joint_model.dart' show AnswerOutcome;

// How a V3 run grades what the learner gave (wiki/Plan-Placement-V3.md, step
// 7). Pure Dart: no Flutter, no storage.
//
// An answer is never graded as the screen happened to receive it. Typed,
// said and tiled answers are first brought to one spelling ([answerKey]):
//   - the same letter typed as different code points is one letter (a
//     Devanagari nukta letter as one code point or as a base and a nukta; a
//     vowel sign typed after its consonant either way; the zero-width
//     joiners, which change a conjunct's shape and never its letters), by
//     [canonical];
//   - case and the spaces and marks around a word are ignored;
//   - accents are ignored as a review ignores them ([foldDiacritics]): a
//     Latin accent, the Arabic vowel marks, and a nukta left off (the learner
//     typed the right word on a keyboard without the mark: that is spelling,
//     which a placement is not asking about).
// A vowel sign (matra) is never ignored: another matra is another word.

/// [text] reduced to the key two spellings of one answer share.
String answerKey(String text) {
  final buffer = StringBuffer();
  for (final rune in canonical(text).runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    // Letters and combining marks and digits stay; spaces, hyphens,
    // apostrophes and punctuation go.
    if (_keeps(lower.runes.first)) buffer.write(lower);
  }
  return foldDiacritics(buffer.toString());
}

bool _keeps(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return true;
  if (rune >= 0x61 && rune <= 0x7a) return true;
  if (rune < 0x80) return false;
  // Latin-1 punctuation and spaces.
  if (rune < 0xc0) return false;
  // General punctuation and the Devanagari danda.
  if (rune >= 0x2000 && rune <= 0x206f && rune != 0x200c && rune != 0x200d) {
    return false;
  }
  if (rune == 0x0964 || rune == 0x0965) return false;
  return true;
}

/// Whether [typed] is one of [accepted] after normalisation. A short article
/// (one word of at most four letters, the first) may be there on one side and
/// not the other (`el lunes` for `lunes`, `niño` for `el niño`); no other word
/// is ever dropped, so a part of a phrase is not the
/// phrase (`días` is not `buenos días`).
bool matchesAccepted(String typed, Iterable<String> accepted) {
  final given = answerKey(typed);
  if (given.isEmpty) return false;
  final words = typed.trim().split(RegExp(r'\s+'));
  for (final a in accepted) {
    final key = answerKey(a);
    if (key.isEmpty) continue;
    if (given == key) return true;
    final acceptedParts = a.trim().split(RegExp(r'\s+'));
    // A short article in front of one side and not the other.
    if (words.length == acceptedParts.length + 1 &&
        words.first.runes.length <= 4 &&
        answerKey(words.skip(1).join(' ')) == key) {
      return true;
    }
    if (acceptedParts.length == words.length + 1 &&
        acceptedParts.first.runes.length <= 4 &&
        answerKey(acceptedParts.skip(1).join(' ')) == given) {
      return true;
    }
  }
  return false;
}

/// The outcome of a typed answer to an F7 item (the word) or an F21 item (the
/// unit left out of it; the whole word typed is right as well).
AnswerOutcome gradeTyped(RegItem item, String typed) {
  if (item.format == 'F21') {
    if (matchesAccepted(typed, item.accepted)) return AnswerOutcome.right;
    // The whole word typed.
    final whole = item.answerTiles.join();
    return answerKey(typed) == answerKey(whole) && answerKey(whole).isNotEmpty
        ? AnswerOutcome.right
        : AnswerOutcome.wrong;
  }
  return matchesAccepted(typed, item.accepted)
      ? AnswerOutcome.right
      : AnswerOutcome.wrong;
}

/// The outcome of a said answer: right if any of the recogniser's
/// [alternatives] is an accepted answer.
AnswerOutcome gradeSaid(RegItem item, Iterable<String> alternatives) {
  for (final heard in alternatives) {
    if (matchesAccepted(heard, item.accepted)) return AnswerOutcome.right;
  }
  return AnswerOutcome.wrong;
}

/// The outcome of the picked option [index] of a pick item.
AnswerOutcome gradePick(RegItem item, int index) =>
    index == item.correct ? AnswerOutcome.right : AnswerOutcome.wrong;

/// The outcome of tiles placed in the order [placed] (indexes into
/// [RegItem.tiles]). A word built from tiles is right when it spells the
/// word (or an accepted spelling of it); a sentence when its tokens are the
/// answer's in order.
AnswerOutcome gradeTiles(RegItem item, List<int> placed) {
  if (placed.any((i) => i < 0 || i >= item.tiles.length)) {
    return AnswerOutcome.wrong;
  }
  final given = <String>[for (final i in placed) item.tiles[i]];
  if (item.format == 'F4') {
    final built = given.join();
    return matchesAccepted(built, item.accepted) ||
            answerKey(built) == answerKey(item.answerTiles.join())
        ? AnswerOutcome.right
        : AnswerOutcome.wrong;
  }
  if (given.length != item.answerTiles.length) return AnswerOutcome.wrong;
  for (var i = 0; i < given.length; i++) {
    if (answerKey(given[i]) != answerKey(item.answerTiles[i])) {
      return AnswerOutcome.wrong;
    }
  }
  return AnswerOutcome.right;
}

/// The outcome of "yes, I know this word" ([yes]) on a yes/no item: yes is
/// right for a real word and, as the model reads a pseudoword's yes, a false
/// alarm; both are reported as [AnswerOutcome.right] (yes) and
/// [AnswerOutcome.wrong] (no), as the model expects.
AnswerOutcome gradeYesNo({required bool yes}) =>
    yes ? AnswerOutcome.right : AnswerOutcome.wrong;
