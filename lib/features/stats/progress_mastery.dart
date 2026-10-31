import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/memory_progress.dart';
import '../../core/data/course_path.dart';
import '../../core/models/deck.dart' show countsAsWord;
import '../../core/progress/mastery.dart';
import '../../core/progress/practice_week.dart';
import 'stats_numbers.dart';

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
    required this._parts,
    required this._at,
  });

  /// What Progress shows for [language] (every language when null), worked
  /// out again only when the progress, the decks or the day has changed:
  /// the weekly snapshots walk the whole log.
  factory ProgressMastery.of(AppState state, String? language) {
    final memo = _memos[state] ??= _Memo();
    final progress = state.progress;
    final key = (
      progress: progress,
      // A language's own version: an answer in another language leaves this
      // one's numbers as they were. All languages go by the whole progress.
      version: language == null
          ? progress.version
          : progress.versionOf(language),
      decks: state.decks,
      day: calendarDay(state.now()),
      native: language == null ? null : state.courseNative(language),
    );
    final cached = memo.byLanguage[language];
    if (cached != null && cached.key == key) {
      return cached.value;
    }
    final value = ProgressMastery._compute(state, language);
    memo.byLanguage[language] = (key: key, value: value);
    return value;
  }

  static final Expando<_Memo> _memos = Expando<_Memo>('ProgressMastery');

  static ProgressMastery _compute(AppState state, String? language) {
    final languageOf = languageLookupOf(state);
    final at = state.now();
    // On All, only reviews in a language that can be told count, so the
    // words and the star are of the same languages.
    bool counts(String deckId) => language == null
        ? languageOf(deckId) != null
        : languageOf(deckId) == language;
    final log = <ReviewEvent>[
      for (final e in state.progress.log.answered)
        if (counts(e.deckId)) e,
    ];
    final scriptLog = <ReviewEvent>[
      for (final e in state.progress.scriptLog)
        if (counts(e.deckId)) e,
    ];
    final codes = language != null
        ? <String>[language]
        : <String>{for (final e in log) ?languageOf(e.deckId)}.toList();

    final parts = <_Part>[];
    Milestone? level;
    for (final code in codes) {
      final inputs = _inputsOf(state, code);
      parts.add(
        _Part(
          log: <ReviewEvent>[
            for (final e in log)
              if (languageOf(e.deckId) == code) e,
          ],
          scriptLog: <ReviewEvent>[
            for (final e in scriptLog)
              if (languageOf(e.deckId) == code) e,
          ],
          totals: inputs.totals,
          scriptCards: inputs.scriptCards,
          parametersOf: (mode) => state.progress.parameters.of(code, mode),
        ),
      );
      if (language != null) level = inputs.level;
    }
    final now = _combine(parts, null);
    return ProgressMastery._(
      words: _words(parts),
      level: level,
      started: startedOn(log),
      week: practiceWeek(log, now: at),
      now: now,
      parts: parts,
      at: at,
    );
  }

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

  final List<_Part> _parts;
  final DateTime _at;

  /// The star's numbers each week for twelve weeks, oldest first.
  List<Mastery> overTime({int weeks = 12}) => <Mastery>[
    for (var i = weeks - 1; i >= 0; i--)
      _combine(_parts, _at.subtract(Duration(days: 7 * i))),
  ];

  static WordCounts _words(List<_Part> parts) {
    var mastered = 0;
    var taught = 0;
    for (final p in parts) {
      final counts = wordCounts(p.log, parametersOf: p.parametersOf);
      mastered += counts.mastered;
      taught += counts.taught;
    }
    return (mastered: mastered, taught: taught);
  }

  static Mastery _combine(List<_Part> parts, DateTime? asOf) =>
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

  static ({MasteryTotals totals, Set<String> scriptCards, Milestone? level})
  _inputsOf(AppState state, String code) {
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
}

class _Part {
  const _Part({
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

/// What [ProgressMastery.of] has worked out for one state, by language.
class _Memo {
  final Map<String?, ({Object key, ProgressMastery value})> byLanguage =
      <String?, ({Object key, ProgressMastery value})>{};
}
