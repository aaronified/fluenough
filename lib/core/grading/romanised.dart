import '../models/romanisation.dart';
import 'answer_grader.dart';

/// Romanised answers (#47): what a learner types in Latin letters, compared
/// with a card's reading in its language's scheme.
///
/// Both sides are first spelled one way, by [key]: lowercase, accents
/// stripped, letters and digits only, and each spelling the romanisation file
/// lists for a sound written as the decks write it. So `kitnaa`, `Kitnā` and
/// `kitna` are one answer, as `kem chho` and `kemchho` are.
class RomanisedSpelling {
  RomanisedSpelling(Romanisation? romanisation)
    : _canonical = <String, String>{
        for (final group in romanisation?.equivalents ?? const <List<String>>[])
          for (final spelling in group) spelling: group.first,
      },
      _typed = <(String, String)>[...?romanisation?.typed]
        ..sort((a, b) => b.$1.length.compareTo(a.$1.length)) {
    _spellings = _canonical.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  /// How a reading's letters are typed, longest first (ADR-0025).
  final List<(String, String)> _typed;

  /// Each spelling a learner may type, and the decks' own for its sound.
  final Map<String, String> _canonical;

  /// [_canonical]'s spellings, longest first, so that `chh` is read before
  /// `ch`.
  late final List<String> _spellings;

  /// [text] spelled one way, to compare.
  ///
  /// Spellings are read from the left, the longest first, and each is
  /// written once: what it is written as is never read again.
  String key(String text) {
    final letters = foldDiacritics(text.toLowerCase())
        .replaceAll(RegExp('[^a-z0-9]'), '');
    final out = StringBuffer();
    var i = 0;
    outer:
    while (i < letters.length) {
      for (final spelling in _spellings) {
        if (letters.startsWith(spelling, i)) {
          out.write(_canonical[spelling]);
          i += spelling.length;
          continue outer;
        }
      }
      out.write(letters[i]);
      i++;
    }
    return out.toString();
  }

  /// [reading], in its standard's letters, as it is typed: `cāy` as
  /// `chāy`. Read from the left, the longest letters first, each once.
  String typedForm(String reading) {
    if (_typed.isEmpty) return reading;
    final out = StringBuffer();
    var i = 0;
    outer:
    while (i < reading.length) {
      for (final (letters, typed) in _typed) {
        if (reading.startsWith(letters, i)) {
          out.write(typed);
          i += letters.length;
          continue outer;
        }
      }
      out.write(reading[i]);
      i++;
    }
    return out.toString();
  }

  /// [reading] as a learner would type it, without the standard's marks:
  /// `cāy` as `chay`. For a hint, never for grading.
  String asTyped(String reading) => foldDiacritics(typedForm(reading));

  /// [given] against [readings], the canonical one first. Exact, a near
  /// miss to judge, or wrong, as [AnswerGrader] says of their [key]s;
  /// `matched` is the reading itself.
  GradedAnswer grade(String given, List<String> readings) {
    if (readings.isEmpty) {
      return const GradedAnswer(AnswerOutcome.wrong, matched: null);
    }
    // A determinative (ᵈ, ᵏⁱ) is unspoken, so a reading is right with or
    // without it: its key leaves the raised letters out, and a second key
    // keeps them as plain letters, for an answer typed `dnanna` or
    // `{d}nanna`.
    final keys = <String>[];
    final owners = <int>[];
    for (final (i, reading) in readings.indexed) {
      final typed = typedForm(reading);
      keys.add(key(typed));
      owners.add(i);
      if (_raised.hasMatch(typed)) {
        keys.add(key(typed.replaceAllMapped(_raised, (m) => _plain[m[0]]!)));
        owners.add(i);
      }
    }
    final graded = const AnswerGrader().grade(
      key(given),
      keys.first,
      alternates: keys.sublist(1),
    );
    final matched = graded.matched;
    return matched == null
        ? graded
        : GradedAnswer(
            graded.outcome,
            matched: readings[owners[keys.indexOf(matched)]],
          );
  }
}

/// The raised letters of Sumerian determinatives, and the plain letters they
/// are typed as.
const Map<String, String> _plain = <String, String>{
  'ᵈ': 'd',
  'ᵏ': 'k',
  'ˢ': 's',
  'ⁱ': 'i',
  'ᵍ': 'g',
  'ᵐ': 'm',
  'ᵘ': 'u',
  'ʳ': 'r',
  'ᵗ': 't',
  'ᵉ': 'e',
  'ⁿ': 'n',
};

final RegExp _raised = RegExp('[${_plain.keys.join()}]');
