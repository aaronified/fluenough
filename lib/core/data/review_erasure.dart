import '../scheduling/ability.dart';

/// Which of one language's reviews the learner chose to delete (#861), in
/// Languages I'm learning: its answers, within a range of days or all of
/// them, and the reviews placement wrote for it.
///
/// The two are separate because placement's credit is written into the log
/// as reviews but is not what the learner answered: deleting "reviews" never
/// takes placement's credit, and deleting "placement" takes only it.
/// Placement's credit is told apart by the moment it was written, which
/// `Settings.placedAtOf` keeps in whole seconds ([placedAtSeconds]).
///
/// Plain data with no Flutter, so the same selection decides what the
/// database removes and what memory removes.
class ReviewErasure {
  const ReviewErasure({
    required this.language,
    this.answers = false,
    this.from,
    this.to,
    this.placement = false,
    this.placedAtSeconds = const <int>{},
    this.idPrefix,
  });

  /// The answers on the cards of a private language package, `fnpd-<code>-`
  /// (#1017), and nothing else: the built-in course of the same code keeps
  /// its progress, as does placement's credit. For "Remove and delete my
  /// progress" (owner, 2026-11-13).
  factory ReviewErasure.privatePackage(String code) =>
      ReviewErasure(language: code, answers: true, idPrefix: 'fnpd-$code-');

  /// The language, as card ids name it: `te` for `te-0053`.
  final String language;

  /// Whether the learner's own answers go.
  final bool answers;

  /// The first and last day of the answers that go, both included, by the
  /// learner's own calendar (local days). Either may be null for no limit
  /// on that side; both null is every date.
  final DateTime? from;
  final DateTime? to;

  /// Whether the reviews placement wrote for the language go, whatever the
  /// range says: placement is not a period of study.
  final bool placement;

  /// The moments, in whole seconds since the epoch, at which placement wrote
  /// the language's credit.
  final Set<int> placedAtSeconds;

  /// Whether nothing is chosen.
  bool get isEmpty => !answers && !placement;

  /// When set, only the cards whose id starts with it are selected, not every
  /// card of [language]: a private package's cards (`fnpd-te-`) are not the
  /// built-in course's, though both name `te`.
  final String? idPrefix;

  /// Whether [cardId] is of [language], or, with an [idPrefix], starts with
  /// it.
  bool isOfLanguage(String cardId) {
    final prefix = idPrefix;
    return prefix == null
        ? Abilities.languageOf(cardId) == language
        : cardId.startsWith(prefix);
  }

  /// Whether a review of [cardId] given at [at] is one placement wrote: in
  /// a second placement wrote its credit, and with the shape of credit
  /// ([creditShape]: Easy, no time taken, no answer given). A real answer
  /// in the same second is not placement's and is never taken with it.
  bool isPlacement(String cardId, DateTime at, {bool creditShape = true}) =>
      creditShape &&
      isOfLanguage(cardId) &&
      placedAtSeconds.contains(at.millisecondsSinceEpoch ~/ 1000);

  /// Whether [at] falls on a chosen day: from [from]'s day to [to]'s day,
  /// inclusive, in local time.
  bool inRange(DateTime at) {
    final day = _day(at.toLocal());
    final first = from;
    if (first != null && day.isBefore(_day(first))) return false;
    final last = to;
    if (last != null && day.isAfter(_day(last))) return false;
    return true;
  }

  /// Whether the review of [cardId] given at [at] is deleted.
  bool matches(String cardId, DateTime at, {bool creditShape = true}) {
    if (!isOfLanguage(cardId)) return false;
    if (isPlacement(cardId, at, creditShape: creditShape)) return placement;
    return answers && inRange(at);
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
