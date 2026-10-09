import 'dart:math' as math;

import '../data/course_path.dart' show Milestone;
import '../grading/diacritics.dart';
import 'deck_index.dart';

/// The languages a learner can choose to learn, as the language picker
/// shows them (#211, `docs/plans/language-picker.md`): read from the deck
/// index, or from the decks on the phone, and free of Flutter so that it is
/// tested in milliseconds.
///
/// Nothing here is stored. A course's completeness is worked out each time
/// from its path's B1 plan and the words its decks have, so it follows the
/// decks as they are written.

/// One unit of a course's B1 plan, as completeness counts it.
class B1Unit {
  const B1Unit({
    this.planned = false,
    this.words,
    this.milestone,
    this.grammar = const <String>[],
    this.has,
  });

  /// [unit] of the index, for a course taught from [native].
  factory B1Unit.fromIndex(IndexUnit unit, String native) => B1Unit(
    planned: unit.planned,
    words: unit.words,
    milestone: milestoneNamed(unit.milestone),
    grammar: unit.grammar,
    has: unit.planned ? null : unit.has[native],
  );

  /// Planned, and not written yet.
  final bool planned;

  /// Its planned size in words; null where the plan gives none.
  final int? words;

  /// The level that ends with it.
  final Milestone? milestone;

  /// Its grammar topics, taught or planned.
  final List<String> grammar;

  /// The words the course's decks have in it: distinct vocabulary cards,
  /// script decks and grammar tables left out. Null when the course has no
  /// deck in it: planned, or written only for other native languages.
  final int? has;

  /// Whether the course teaches it: it is written, with a deck in the
  /// course's native language.
  bool get written => !planned && has != null;
}

/// A course's stage of writing (owner, 2026-10-09): **Alpha** until every
/// A1 unit of its plan is written, **Beta** until every B1 unit is, and
/// [complete] after, which carries no tag. A course whose path has no B1
/// plan cannot show that its A1 units are written, so it is Alpha.
enum CourseStage { alpha, beta, complete }

/// [name], `A1`, `A2` or `B1`, as a [Milestone]; null for anything else.
Milestone? milestoneNamed(String? name) => switch (name) {
  'A1' => Milestone.a1,
  'A2' => Milestone.a2,
  'B1' => Milestone.b1,
  _ => null,
};

/// How much of a course is written toward B1, from its path's B1 plan and
/// the words its decks have (`language-picker.md`, "What the data needs").
class B1Progress {
  const B1Progress._({
    required this.hasPlan,
    required this.plannedWords,
    required this.writtenWords,
    required this.courseWords,
    required this.grammarTopics,
    required this.grammarWritten,
    required this.stage,
    required this._upToB1,
  });

  /// What [units], a course's path in order, say: completeness is
  /// Σ min(words a unit has, its planned words) ÷ Σ planned words, over the
  /// units up to the one marked B1. A unit not written counts 0.
  factory B1Progress.of(List<B1Unit> units) {
    int? at(Milestone m) {
      for (final (i, unit) in units.indexed) {
        if (unit.milestone == m) return i;
      }
      return null;
    }

    final b1 = at(Milestone.b1);
    final a1 = at(Milestone.a1);
    final upToB1 = b1 == null ? const <B1Unit>[] : units.sublist(0, b1 + 1);
    var planned = 0;
    var written = 0;
    final topics = <String>{};
    final taught = <String>{};
    for (final unit in upToB1) {
      final words = unit.words ?? 0;
      planned += words;
      if (unit.written) {
        written += math.min(unit.has!, words);
        taught.addAll(unit.grammar);
      }
      topics.addAll(unit.grammar);
    }
    bool allWritten(int end) =>
        units.take(end + 1).every((u) => u.written || _unwritable(u));
    final hasPlan = b1 != null && planned > 0;
    final stage = !hasPlan || a1 == null || !allWritten(a1)
        ? CourseStage.alpha
        : !allWritten(b1)
        ? CourseStage.beta
        : CourseStage.complete;
    return B1Progress._(
      hasPlan: hasPlan,
      plannedWords: planned,
      writtenWords: written,
      courseWords: units.fold(0, (sum, u) => sum + (u.has ?? 0)),
      grammarTopics: topics.length,
      grammarWritten: taught.intersection(topics).length,
      stage: stage,
      upToB1: upToB1,
    );
  }

  // A written unit with no words counted and no deck in any native
  // language, such as one of the wildcard alone, is no unit to write.
  static bool _unwritable(B1Unit unit) =>
      !unit.planned && unit.has == null && unit.words == null;

  /// Whether the path has a B1 plan: a unit marked B1, and planned words
  /// before it. Without one the card shows the course's size instead
  /// ([courseWords]).
  final bool hasPlan;

  /// The words planned up to B1.
  final int plannedWords;

  /// The planned words written so far: each unit's words, at most its plan.
  final int writtenWords;

  /// Every word the course's decks have, plan or no plan: "Course size: 640
  /// words".
  final int courseWords;

  /// The grammar topics planned up to B1, and how many of them are taught.
  final int grammarTopics;
  final int grammarWritten;

  final CourseStage stage;

  final List<B1Unit> _upToB1;

  /// How much of B1 is written, 0–1.
  double get share => plannedWords == 0 ? 0 : writtenWords / plannedWords;

  /// [share] as a whole percent, rounded down so that 100% means all of it.
  int get percent => percentOf(share);

  /// How far a learner is toward B1, 0–1, from [learned], the words they
  /// have learned in each unit of the course's path, in order: the same
  /// sum as [share], each unit's words at most what the course has there,
  /// so that it never passes it.
  double learnedShare(List<int> learned) {
    if (plannedWords == 0) return 0;
    var sum = 0;
    for (final (i, unit) in _upToB1.indexed) {
      if (!unit.written || i >= learned.length) continue;
      final cap = math.min(unit.has!, unit.words ?? 0);
      sum += math.min(learned[i], cap);
    }
    return sum / plannedWords;
  }

  /// [share], 0–1, as a whole percent, rounded down.
  static int percentOf(double share) => (share * 100).floor().clamp(0, 100);
}

/// A native language a course is taught from, with how much of B1 its
/// decks have.
typedef CatalogNative = ({String code, String name, B1Progress progress});

/// A language the learner can choose to learn.
class CatalogLanguage {
  const CatalogLanguage({
    required this.code,
    required this.name,
    this.ownName,
    this.icon,
    this.script,
    this.scriptDecks = false,
    this.natives = const <CatalogNative>[],
    this.size = 0,
  });

  final String code;

  /// Its English name.
  final String name;

  /// Its name for itself, where known: "తెలుగు".
  final String? ownName;

  /// What its chip shows, the first letter of its own name (ADR-0027).
  final String? icon;

  /// Its script, as the decks name it: `telugu`, `latin`.
  final String? script;

  /// Whether its course has decks that teach the script.
  final bool scriptDecks;

  /// The native languages its decks teach from, each with its coverage.
  final List<CatalogNative> natives;

  /// What its files take, in bytes, for the native languages it would be
  /// learned from.
  final int size;

  /// The native language [spoken], best known first, would learn it from:
  /// the first of them it is taught from, else English, else its first
  /// (ADR-0037, as [IndexLanguage.nativesFor]).
  CatalogNative? nativeFor(List<String> spoken) {
    for (final code in spoken) {
      for (final native in natives) {
        if (native.code == code) return native;
      }
    }
    for (final native in natives) {
      if (native.code == 'en') return native;
    }
    return natives.firstOrNull;
  }

  /// The native languages it is taught from that [spoken] has, in the
  /// learner's order: those a choice is offered among.
  List<CatalogNative> spokenNatives(List<String> spoken) => <CatalogNative>[
    for (final code in spoken) ...natives.where((n) => n.code == code),
  ];

  /// Its natives, those the learner speaks first in their order, the rest
  /// after by name.
  List<CatalogNative> nativesInOrder(List<String> spoken) {
    final mine = spokenNatives(spoken);
    final rest = natives.where((n) => !spoken.contains(n.code)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return <CatalogNative>[...mine, ...rest];
  }

  /// Whether it is taught from a language the learner speaks.
  bool taughtFromSpoken(List<String> spoken) =>
      natives.any((n) => spoken.contains(n.code));

  /// The course's progress, as a learner who speaks [spoken] would take it.
  B1Progress? progressFor(List<String> spoken, {String? native}) {
    if (native != null) {
      for (final n in natives) {
        if (n.code == native) return n.progress;
      }
    }
    return nativeFor(spoken)?.progress;
  }

  /// [index]'s entry for a language: its own name from the index, else
  /// from [ownNames], and each native's progress from its units. [size] is
  /// what it would download for [spoken].
  factory CatalogLanguage.fromIndex(
    IndexLanguage index, {
    List<String> spoken = const <String>['en'],
    Map<String, String> ownNames = const <String, String>{},
  }) => CatalogLanguage(
    code: index.code,
    name: index.name,
    ownName: index.ownName ?? ownNames[index.code],
    icon: index.icon,
    script: index.script,
    scriptDecks: index.scriptDecks,
    natives: <CatalogNative>[
      for (final native in index.natives)
        (
          code: native.code,
          name: native.name,
          progress: B1Progress.of(<B1Unit>[
            for (final unit in index.units) B1Unit.fromIndex(unit, native.code),
          ]),
        ),
    ],
    size: index
        .filesFor(index.nativesFor(spoken))
        .fold(0, (sum, file) => sum + file.size),
  );
}

/// A match of a search in a name: where it starts and ends.
typedef NameMatch = ({int start, int end});

/// Searching the languages: by English name, own name and code, ignoring
/// case and accents. "espanol" finds Español, "hi" Hindi and Marathi.
abstract final class LanguageSearch {
  /// Whether [language] matches [query]. An empty query matches all.
  static bool matches(CatalogLanguage language, String query) {
    final q = _fold(query.trim()).text;
    if (q.isEmpty) return true;
    return _fold(language.name).text.contains(q) ||
        (language.ownName != null &&
            _fold(language.ownName!).text.contains(q)) ||
        _fold(language.code).text.contains(q);
  }

  /// Where [query] is found in [name], in [name]'s own positions, to mark
  /// it; null when it is not, or the query is empty.
  static NameMatch? find(String name, String query) {
    final q = _fold(query.trim()).text;
    if (q.isEmpty) return null;
    final folded = _fold(name);
    final at = folded.text.indexOf(q);
    if (at < 0) return null;
    return (start: folded.from[at], end: folded.to[at + q.length - 1]);
  }

  /// [text] lower-cased and folded, and for each of its code units, where
  /// in [text] the character it came from starts and ends.
  static ({String text, List<int> from, List<int> to}) _fold(String text) {
    final out = StringBuffer();
    final from = <int>[];
    final to = <int>[];
    var i = 0;
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final folded = foldCharacter(char.toLowerCase());
      for (var k = 0; k < folded.length; k++) {
        from.add(i);
        to.add(i + char.length);
      }
      out.write(folded);
      i += char.length;
    }
    return (text: out.toString(), from: from, to: to);
  }
}

/// [languages] in the picker's order (`language-picker.md`, "Two groups"):
/// those taught from a language in [spoken] first, then the rest, each
/// part A to Z by English name.
List<CatalogLanguage> pickerOrder(
  Iterable<CatalogLanguage> languages,
  List<String> spoken,
) {
  final sorted = languages.toList()
    ..sort((a, b) {
      final mine =
          (a.taughtFromSpoken(spoken) ? 0 : 1) -
          (b.taughtFromSpoken(spoken) ? 0 : 1);
      return mine != 0 ? mine : a.name.compareTo(b.name);
    });
  return sorted;
}
