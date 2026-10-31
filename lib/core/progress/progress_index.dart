import '../models/review_event.dart';
import '../scheduling/ability.dart';
import '../scheduling/fsrs.dart';

/// Lapses at which a pair counts as a leech (#19).
const int kLeechLapses = 5;

/// What the Progress tab reads, kept up to date one answer at a time.
///
/// Adding a review costs the same however long the log is, so that an answer
/// never waits on the whole history: nothing here walks the log but
/// [rebuild], which runs when progress loads or a backup is restored. Pure
/// Dart, so that `rebuild` can run in an isolate.
class ProgressIndex {
  final Map<ProgressKey, _Run> _runs = <ProgressKey, _Run>{};
  final Map<ProgressKey, String> _lastDeck = <ProgressKey, String>{};
  final Map<String, _Language> _languages = <String, _Language>{};
  final Map<String, List<int>> _byCard = <String, List<int>>{};
  int _count = 0;

  /// How many reviews are indexed.
  int get length => _count;

  /// Forgets everything and indexes [log] again, oldest first.
  void rebuild(Iterable<ReviewEvent> log) {
    _runs.clear();
    _lastDeck.clear();
    _languages.clear();
    _byCard.clear();
    _count = 0;
    log.forEach(add);
  }

  /// Indexes [event], the newest review.
  void add(ReviewEvent event) {
    // A walkthrough's view of a card is no answer: no review, day, lapse or
    // leech (#694). It leaves FSRS's state at zero repetitions, as a pair
    // never answered has none, so the lapses below still agree with it.
    if (event.isView) return;
    final key = event.key;
    final language = _languages[Abilities.languageOf(event.cardId)] ??=
        _Language();
    language.reviews++;
    final day = _dayOf(event.at);
    language.perDay[day] = (language.perDay[day] ?? 0) + 1;
    if (language.latest == null || event.at.isAfter(language.latest!)) {
      language.latest = event.at;
    }
    (_byCard[event.cardId] ??= <int>[]).add(_count++);
    _lastDeck[key] = event.deckId;
    // Lapses as a replay without resets counts them (`Fsrs.review`): a miss
    // after at least one right answer.
    final run = _runs[key];
    final missed =
        Fsrs.ratingOf(event.grade, rated: event.answerGiven == null) ==
        Rating.again;
    final lapsed = missed && run != null && run.repetitions > 0;
    final next = _Run(
      missed ? 0 : (run?.repetitions ?? 0) + 1,
      (run?.lapses ?? 0) + (lapsed ? 1 : 0),
    );
    _runs[key] = next;
    if (lapsed && next.lapses == kLeechLapses) language.leeches.add(key);
  }

  /// Lifetime lapses of [key]: what leeches are counted from.
  int lapsesOf(ProgressKey key) => _runs[key]?.lapses ?? 0;

  /// Every pair with at least [threshold] lifetime lapses, with the deck it
  /// was last answered in.
  Iterable<({ProgressKey key, String deckId, int lapses})> leeches({
    int threshold = kLeechLapses,
  }) sync* {
    for (final language in _languages.values) {
      if (threshold == kLeechLapses) {
        for (final key in language.leeches) {
          yield (key: key, deckId: _lastDeck[key]!, lapses: _runs[key]!.lapses);
        }
      }
    }
    if (threshold != kLeechLapses) {
      for (final MapEntry(:key, :value) in _runs.entries) {
        if (value.lapses >= threshold) {
          yield (key: key, deckId: _lastDeck[key]!, lapses: value.lapses);
        }
      }
    }
  }

  /// How many pairs of [language] are leeches.
  int leechCount(String language) => _languages[language]?.leeches.length ?? 0;

  /// How many reviews [language] has.
  int reviewsIn(String language) => _languages[language]?.reviews ?? 0;

  /// The time of [language]'s latest review, or null if it has none.
  DateTime? latestIn(String language) => _languages[language]?.latest;

  /// The languages with reviews.
  Iterable<String> get languages => _languages.keys;

  /// Reviews of [language] on each day, by [dayNumber] (local days). A
  /// heatmap reads the days it shows from this.
  Map<int, int> perDay(String language) =>
      _languages[language]?.perDay ?? const <int, int>{};

  /// The positions in the log of [cardId]'s reviews, oldest first.
  List<int> positionsOf(String cardId) => _byCard[cardId] ?? const <int>[];

  /// The day [at] falls on, counted from 1970-01-01 in its own zone.
  static int dayNumber(DateTime at) => _dayOf(at);

  static int _dayOf(DateTime at) =>
      DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

class _Run {
  const _Run(this.repetitions, this.lapses);
  final int repetitions;
  final int lapses;
}

class _Language {
  int reviews = 0;
  DateTime? latest;
  final Map<int, int> perDay = <int, int>{};
  final Set<ProgressKey> leeches = <ProgressKey>{};
}
