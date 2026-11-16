import '../models/card.dart';
import '../models/drill_mode.dart';
import 'session_queue.dart';

/// How many questions of other items come between an item's first and its
/// second question (owner, 2026-11-16: "first question right after, 2nd
/// question after 2 more questions").
const int learnGap = 2;

/// How many learn attempts are open at once. With the gap fixed at
/// [learnGap], three open at once pack as Q1a Q1b Q1c Q2a Q2b Q2c and keep
/// exactly two other questions between each Q1 and its Q2.
const int learnOpenMax = learnGap + 1;

/// How long a sitting may be idle before an open attempt is dropped (the
/// app closed or backgrounded, the learner called away): five minutes.
const Duration learnIdleLimit = Duration(minutes: 5);

/// Which step of a learn attempt an item of a session is.
enum LearnStep {
  /// The content shown: a teach card or a rule card. Records nothing.
  show,

  /// The first question, straight after the show.
  first,

  /// The second question, of another type, after [learnGap] other questions.
  second,
}

/// The mark a session item carries when it is a step of a learn attempt: the
/// attempt is named by the card it teaches.
class LearnTag {
  const LearnTag(this.id, this.step, {this.gap = learnGap});

  final String id;
  final LearnStep step;

  /// How many other questions the lesson put between this attempt's first and
  /// second question: [learnGap], or fewer only for a lesson too short to be
  /// spaced by two others.
  final int gap;

  @override
  String toString() => 'LearnTag($id, ${step.name})';
}

/// Where one learn attempt is.
enum LearnPhase {
  /// Shown, the first question not answered yet.
  shown,

  /// The first question was right; the second is awaited.
  awaitingSecond,
}

/// What an answer did to its attempt.
enum LearnOutcome {
  /// Nothing to say: the answer belongs to no open attempt (a question asked
  /// again after a miss, or of an attempt dropped), or it is the first
  /// question, right, and the second is awaited.
  pending,

  /// Both questions were right, each at once: the item is learned.
  learned,

  /// A question was missed: the attempt is over, the item stays unlearnt.
  failed,

  /// The attempt broke its rule (a gap that is not exactly [learnGap], an
  /// idle sitting, a step out of order): the item stays unlearnt.
  dropped,
}

/// The result of [LearnTracker.answer]: the outcome and, when the item is
/// learned, the two held payloads in the order they were answered.
class LearnResult<T> {
  const LearnResult(this.outcome, [this.held = const <Never>[]]);

  final LearnOutcome outcome;
  final List<T> held;
}

class _Open<T> {
  _Open(this.gap);

  /// The gap the second question must come after, exactly.
  final int gap;
  LearnPhase phase = LearnPhase.shown;

  /// Questions completed since the content was shown (phase shown), or since
  /// the first question (phase awaiting the second).
  int between = 0;
  T? first;
}

/// The state of the learn attempts of one sitting (drill session): a small
/// explicit machine, shown -> awaiting Q1 -> awaiting Q2 -> learned, failed or
/// dropped, kept apart from the widgets so that it is tested on its own.
///
/// It holds each attempt's first answer as a payload [T] rather than writing
/// it anywhere: only when the second is right too does [answer] hand both
/// back, to be given to the scheduler. A wrong answer, a broken gap, an idle
/// sitting, or leaving the drill ([end]) hands back nothing, so nothing of
/// the item ever reaches FSRS.
class LearnTracker<T> {
  LearnTracker({
    required this.now,
    this.idle = learnIdleLimit,
    this.openMax = learnOpenMax,
  });

  /// The clock the idle limit is read from.
  final DateTime Function() now;

  /// The idle time after which every open attempt is dropped.
  final Duration idle;

  /// The most attempts open at once.
  final int openMax;

  final Map<String, _Open<T>> _open = <String, _Open<T>>{};
  DateTime? _last;

  /// The ids of the attempts open now.
  Iterable<String> get open => _open.keys;

  /// Where [id]'s attempt is, or null when it is not open.
  LearnPhase? phaseOf(String id) => _open[id]?.phase;

  /// Drops every open attempt after an idle stretch; the clock restarts.
  /// Returns whether any was dropped.
  bool _activity() {
    final at = now();
    final last = _last;
    _last = at;
    if (last != null && at.difference(last) > idle && _open.isNotEmpty) {
      _open.clear();
      return true;
    }
    return false;
  }

  /// The content of [id] is shown. Opens its attempt, unless [openMax] are
  /// open already (then it returns false and the item is simply not learned
  /// in this sitting).
  bool shown(String id, {int gap = learnGap}) {
    _activity();
    _open.remove(id);
    if (_open.length >= openMax) return false;
    _open[id] = _Open<T>(gap);
    return true;
  }

  /// A question of [id]'s attempt was skipped, never shown: the attempt
  /// cannot keep its gap, so it ends.
  void dropAttempt(String id) => _open.remove(id);

  /// [id]'s question of [step] was answered, [correct] or not on its first
  /// attempt, with [payload] describing the answer.
  LearnResult<T> answer(String id, LearnStep step, bool correct, T payload) {
    final dropped = _activity();
    final attempt = _open[id];
    if (attempt == null) {
      return LearnResult<T>(
        dropped ? LearnOutcome.dropped : LearnOutcome.pending,
      );
    }
    final inOrder = switch (step) {
      LearnStep.first =>
        attempt.phase == LearnPhase.shown && attempt.between == 0,
      LearnStep.second =>
        attempt.phase == LearnPhase.awaitingSecond &&
            attempt.between == attempt.gap,
      LearnStep.show => false,
    };
    if (!inOrder) {
      _open.remove(id);
      return LearnResult<T>(LearnOutcome.dropped);
    }
    if (!correct) {
      _open.remove(id);
      return LearnResult<T>(LearnOutcome.failed);
    }
    if (step == LearnStep.first) {
      attempt
        ..phase = LearnPhase.awaitingSecond
        ..between = 0
        ..first = payload;
      return LearnResult<T>(LearnOutcome.pending);
    }
    _open.remove(id);
    return LearnResult<T>(LearnOutcome.learned, <T>[
      attempt.first as T,
      payload,
    ]);
  }

  /// A question was left behind, answered or skipped: [id] is the attempt it
  /// belonged to, if any. Every other open attempt has one more question
  /// between. A question of an attempt left without an answer ends that
  /// attempt.
  void left({String? id, LearnStep? step}) {
    _activity();
    if (id != null && step != null && step != LearnStep.show) {
      final own = _open[id];
      if (own != null) {
        final answered = switch (step) {
          LearnStep.first => own.phase == LearnPhase.awaitingSecond,
          _ => false,
        };
        // A second question is removed when answered, so one still open
        // here was not; a first one is open after its answer only in the
        // awaiting phase.
        if (!answered) _open.remove(id);
      }
    }
    for (final entry in _open.entries) {
      if (entry.key != id) entry.value.between++;
    }
    // An attempt whose gap is already broken ends now, so it never lingers.
    _open.removeWhere(
      (_, a) => a.phase == LearnPhase.shown ? a.between > 0 : a.between > a.gap,
    );
  }

  /// The sitting is over: the learner left the drill, or it ended. Every
  /// open attempt is dropped.
  void end() => _open.clear();
}

/// One new item as a lesson lays it out: what shows it, its first question
/// and its second, of a different type.
class LearnAttempt {
  const LearnAttempt({
    required this.card,
    required this.shows,
    required this.first,
    this.second,
    this.tracked = true,
  });

  final Card card;

  /// The teach card, or the rule card, shown right before the first question.
  final List<SessionItem> shows;
  final SessionItem first;

  /// The second question, of a different type; null only for an untracked
  /// card with a single question.
  final SessionItem? second;

  /// Whether the answers are held until both are right. False for a card
  /// already learned that a session asks again (sounds practised).
  final bool tracked;

  SessionItem _tag(SessionItem item, LearnStep step, int gap) =>
      tracked ? item.taggedAs(LearnTag(card.id, step, gap: gap)) : item;
}

/// The items of [attempts] in the order a lesson asks them, and what it took.
///
/// Each tracked attempt is shown, then asked its first question at once,
/// then its second after exactly [learnGap] other questions: three open at
/// once, Q1 Q1 Q1 Q2 Q2 Q2. A last group of fewer than three needs
/// [learnOpenMax] less its size of [fillers], questions of other items (a
/// review), to keep the gap at two; without them it is left out and its items
/// wait for another lesson. Only where the lesson has no other group is a
/// short group kept, with the shorter gap it can have, so that a lesson is
/// never empty for good; each attempt carries the gap it must keep. Untracked
/// attempts come after, laid out plainly: each shown and asked, then each
/// asked again.
({List<SessionItem> items, int fillersUsed}) learnSequence(
  List<LearnAttempt> attempts, {
  List<SessionItem> fillers = const <SessionItem>[],
}) {
  final tracked = <LearnAttempt>[
    for (final a in attempts)
      if (a.tracked && a.second != null) a,
  ];
  final plain = <LearnAttempt>[
    for (final a in attempts)
      if (!a.tracked) a,
  ];
  final items = <SessionItem>[];
  var fillersUsed = 0;
  for (var start = 0; start < tracked.length; start += learnOpenMax) {
    final group = tracked.skip(start).take(learnOpenMax).toList();
    final needed = learnOpenMax - group.length;
    final available = fillers.length - fillersUsed;
    final int use;
    if (needed <= available) {
      use = needed;
    } else if (tracked.length == group.length) {
      use = available;
    } else {
      continue;
    }
    final gap = group.length - 1 + use;
    for (final a in group) {
      items
        ..addAll(<SessionItem>[
          for (final show in a.shows) a._tag(show, LearnStep.show, gap),
        ])
        ..add(a._tag(a.first, LearnStep.first, gap));
    }
    for (var i = 0; i < use; i++) {
      items.add(fillers[fillersUsed++]);
    }
    for (final a in group) {
      items.add(a._tag(a.second!, LearnStep.second, gap));
    }
  }
  for (final a in plain) {
    items
      ..addAll(a.shows)
      ..add(a.first);
  }
  for (final a in plain) {
    final second = a.second;
    if (second != null) items.add(second);
  }
  return (items: items, fillersUsed: fillersUsed);
}

/// The two questions that make [card] learnable, or null when it has not two
/// different ones. [questions] are what a lesson can ask the card, best
/// first. The first is the best; the second has a different type, a different
/// skill where there is one. A recognition question rated by the learner
/// ([Ask.own] in recognition) never counts: it proves nothing.
///
/// [extras] are more ways to ask the card within its skills, for a card whose
/// own questions give only one type: they are tried when the card's own have no
/// second.
({SessionItem first, SessionItem second})? learnPair(
  List<SessionItem> questions, {
  List<SessionItem> extras = const <SessionItem>[],
}) {
  final usable = <SessionItem>[
    for (final q in questions)
      if (!(q.mode == DrillMode.recognition && q.ask == Ask.own) &&
          q.ask != Ask.matchPairs)
        q,
  ];
  if (usable.isEmpty) {
    // Nothing the card is asked its own way proves anything: its extras do.
    return extras.length < 2 ? null : learnPair(extras);
  }
  final first = usable.first;
  final other = usable
      .where((q) => q.mode != first.mode && q.ask != first.ask)
      .firstOrNull;
  if (other != null) return (first: first, second: other);
  final same = usable.where((q) => q.ask != first.ask).firstOrNull;
  if (same != null) return (first: first, second: same);
  final more = extras
      .where((q) => q.ask != first.ask)
      .where((q) => !(q.mode == DrillMode.recognition && q.ask == Ask.own))
      .firstOrNull;
  if (more != null) return (first: first, second: more);
  return null;
}
