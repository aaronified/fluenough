import '../models/grammar_pattern.dart';
import 'answer_grader.dart';

/// What a wrong grammar answer was, read from the lemma's own table.
enum TableMistakeKind {
  /// The form of another cell of the same row: another person, case, tense
  /// or number.
  otherCell,

  /// The word as the dictionary gives it, not inflected.
  uninflected,
}

/// A wrong answer that [readTableMistake] recognised.
class TableMistake {
  const TableMistake(this.kind, this.slots);

  final TableMistakeKind kind;

  /// For [TableMistakeKind.otherCell], the slots whose form was given (more
  /// than one when the row spells them alike), in table order. Empty for
  /// [TableMistakeKind.uninflected].
  final List<String> slots;
}

const AnswerGrader _tableGrader = AnswerGrader();

bool _same(String given, String form) =>
    _tableGrader.grade(given, form).outcome == AnswerOutcome.exact;

/// Reads a wrong [given] answer for the [asked] slot of [entry] in the
/// pattern's [slots], with no content beyond the table itself (#327).
///
/// Another cell's form is [TableMistakeKind.otherCell], naming every slot
/// that spells [given]; slots whose form is also an accepted answer for
/// [asked] are left out, since that answer would have been right. Failing
/// that, the entry's lemma is [TableMistakeKind.uninflected]. Anything else
/// is null: a plain wrong answer. Forms are compared as the grader does,
/// exactly after case, spacing and Unicode spelling, never loosely, so a
/// slip is never read as another word.
TableMistake? readTableMistake({
  required String given,
  required PatternEntry entry,
  required List<String> slots,
  required String asked,
}) {
  if (given.trim().isEmpty) return null;
  final own = entry.forms[asked];
  if (own != null && _same(given, own)) return null;
  final alternates = entry.alternatives[asked] ?? const <String>[];
  if (alternates.any((form) => _same(given, form))) return null;
  final others = <String>[];
  for (final slot in slots) {
    if (slot == asked) continue;
    final form = entry.forms[slot];
    if (form != null && _same(given, form)) others.add(slot);
  }
  if (others.isNotEmpty) {
    return TableMistake(TableMistakeKind.otherCell, others);
  }
  if (_same(given, entry.lemma)) {
    return const TableMistake(TableMistakeKind.uninflected, <String>[]);
  }
  return null;
}
