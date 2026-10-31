import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/memory_progress.dart';
import '../../core/data/course_path.dart';
import '../../core/models/deck.dart' show countsAsWord;
import '../../core/progress/mastery.dart';
import '../../core/progress/practice_week.dart';

/// What Progress shows of mastery (#678) for one language, or for every
/// language practised together when [language] is null: the words, the
/// level, the start date, the 7-day calendar and the star. Worked out from
/// the review log, the decks and the paths; nothing is stored.
class ProgressMastery {
  ProgressMastery._({
    required this.words,
    required this.level,
    required this.started,
    required this.week,
    required this.now,
    required List<MasteryPart>? parts,
    required List<Mastery>? series,
    required DateTime at,
  }) : _parts = parts,
       _series = series,
       _at = at;

  /// The mastery of the languages [parts] hold, whose reviews together are
  /// [log] (those of the languages counted), as of [at]. With [withSeries]
  /// the weekly snapshots are worked out now and [parts] are let go, so
  /// that the result holds plain data only and can cross from an isolate
  /// (#857); without, they wait for [overTime].
  factory ProgressMastery.fromParts(
    List<MasteryPart> parts, {
    required List<ReviewEvent> log,
    required DateTime at,
    Milestone? level,
    bool withSeries = false,
  }) {
    final result = ProgressMastery._(
      words: _words(parts),
      level: level,
      started: startedOn(log),
      week: practiceWeek(log, now: at),
      now: _combine(parts, null),
      parts: parts,
      series: null,
      at: at,
    );
    if (withSeries) {
      result
        ..overTime()
        .._parts = null;
    }
    return result;
  }

  /// Nothing reviewed: no words, an empty week and a star with nothing in it.
  factory ProgressMastery.empty(DateTime at) => ProgressMastery.fromParts(
    const <MasteryPart>[],
    log: const <ReviewEvent>[],
    at: at,
  );

  /// Words mastered, of the words taught.
  final WordCounts words;

  /// The course's level reached, or null before A1 and on All languages,
  /// where levels differ by course.
  final Milestone? level;

  /// The day of the first answer, the earliest across languages on All.
  final DateTime? started;

  /// The last seven days.
  final List<PracticeDay> week;

  /// The star's numbers now.
  final Mastery now;

  List<MasteryPart>? _parts;
  List<Mastery>? _series;
  final DateTime _at;

  /// The star's numbers each week for twelve weeks, oldest first. Worked out
  /// on the first ask, unless the isolate that made this did so already.
  List<Mastery> overTime() => _series ??= <Mastery>[
    for (var i = 11; i >= 0; i--)
      _combine(_parts!, _at.subtract(Duration(days: 7 * i))),
  ];

  static WordCounts _words(List<MasteryPart> parts) {
    var mastered = 0;
    var taught = 0;
    for (final p in parts) {
      final counts = wordCounts(p.log, parametersOf: p.parametersOf);
      mastered += counts.mastered;
      taught += counts.taught;
    }
    return (mastered: mastered, taught: taught);
  }

  static Mastery _combine(List<MasteryPart> parts, DateTime? asOf) =>
      sumMastery(<Mastery>[
        for (final p in parts)
          masteryAt(
            p.log,
            p.scriptLog,
            totals: p.totals,
            scriptCards: p.scriptCards,
            asOf: asOf,
            parametersOf: p.parametersOf,
          ),
      ]);
}

/// One language's share of [ProgressMastery]: its reviews, what the course
/// holds, and the parameters that schedule it.
class MasteryPart {
  const MasteryPart({
    required this.log,
    required this.scriptLog,
    required this.totals,
    required this.scriptCards,
    required this.parametersOf,
  });

  final ParametersOf parametersOf;
  final List<ReviewEvent> log;
  final List<ReviewEvent> scriptLog;
  final MasteryTotals totals;
  final Set<String> scriptCards;
}

/// What the course of [code] holds, from [state]'s decks and path: the B1
/// totals per skill, the cards that teach a script, and the level reached.
({MasteryTotals totals, Set<String> scriptCards, Milestone? level})
courseInputsOf(AppState state, String code) {
  final native = state.courseNative(code);
  final entries = <DeckEntry>[
    for (final e in state.decks)
      if (e.language.code == code && e.deck.native.code == native) e,
  ];
  final path = entries.isEmpty ? null : state.pathOf(entries.first);
  final inCourse = path == null
      ? entries
      : <DeckEntry>[for (final id in path.deckIds) ?state.deckById(id)];
  final alphabet = path?.alphabet ?? const <String>{};
  final scriptCards = <String>{};
  final words = <String>{};
  final grammar = <String>{};
  for (final entry in inCourse) {
    for (final card in entry.cards) {
      if (alphabet.contains(entry.id)) {
        scriptCards.add(card.id);
      } else if (card.isGrammarCell) {
        grammar.add(card.id);
      } else if (countsAsWord(card, entry.deck.kind)) {
        // Roots only (#615): a phrase is no word of a level.
        words.add(card.id);
      }
    }
  }
  final b1Words = path == null || path.plannedWords < words.length
      ? words.length
      : path.plannedWords;
  return (
    totals: <MasterySkill, int>{
      MasterySkill.grammar: grammar.length,
      MasterySkill.script: scriptCards.length * 2,
      MasterySkill.read: b1Words,
      MasterySkill.write: b1Words,
      MasterySkill.hear: b1Words,
      MasterySkill.say: b1Words,
    },
    scriptCards: scriptCards,
    level: path == null
        ? null
        : levelReached(path, (id) {
            final entry = state.deckById(id);
            return entry != null && state.isFinished(entry);
          }),
  );
}
