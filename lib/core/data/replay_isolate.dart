import 'dart:isolate';

import '../models/leech_action.dart';
import '../models/review_event.dart';
import '../progress/progress_index.dart';
import '../scheduling/fsrs.dart';
import '../scheduling/replay.dart';
import '../scheduling/skill_map.dart';
import '../scheduling/skill_parameters.dart';

/// What opening a profile replays (#857): the review log as the database
/// holds it, in any order, with its leech actions in the order the database
/// gave them and the learner's fitted parameters. Plain data, so that it
/// crosses to an isolate.
class OpenJob {
  const OpenJob({
    required this.reviews,
    required this.leechActions,
    required this.fitted,
  });

  final List<LoggedReview> reviews;
  final List<LeechAction> leechActions;
  final Map<SkillKey, FittedParameters> fitted;
}

/// What [openLog] works out from an [OpenJob]: everything opening the app
/// needs from the whole log, so that nothing walks it on the UI isolate.
class OpenedLog {
  const OpenedLog({
    required this.cacheStates,
    required this.memory,
    required this.index,
    required this.lastStudied,
    required this.leechActions,
  });

  /// Each pair's state from its own reviews alone: what `card_states`
  /// caches.
  final Map<ProgressKey, FsrsState> cacheStates;

  /// The log replayed as memory keeps it: events, states and the script
  /// skills'.
  final Replayed memory;

  /// The aggregates of [memory]'s events, built once here.
  final ProgressIndex index;

  /// When each language was last studied, which chooses the parameters of a
  /// language that takes another's as its baseline.
  final Map<String, DateTime> lastStudied;

  /// The job's leech actions, as given.
  final List<LeechAction> leechActions;
}

/// Replays [job]'s log: sorts it by time, then replays it twice as opening
/// the app always has, once for the state cache (each pair's own reviews)
/// and once for memory, with the script skills and the index. Pure: no
/// database, no Flutter, so [replayInIsolate] can run it on an isolate and
/// [replayInPlace] gives the same result.
OpenedLog openLog(OpenJob job) {
  final reviews = inTimeOrder(job.reviews);
  final parameters = SkillParameters(
    fitted: job.fitted,
    lastStudied: SkillParameters.lastStudiedIn(<({String cardId, DateTime at})>[
      for (final r in reviews) (cardId: r.key.cardId, at: r.at),
    ]),
  );
  // One replay of the log serves the state cache; memory is replayed from
  // its events, as `MemoryProgress.replaying` does.
  final cache = replayReviews(
    reviews,
    effects: LeechEffects(actionsInTimeOrder(job.leechActions)),
    parameters: parameters,
  );
  final fromEvents = cache.events.map(logged).toList();
  final lastStudied = SkillParameters.lastStudiedIn(
    <({String cardId, DateTime at})>[
      for (final r in fromEvents) (cardId: r.key.cardId, at: r.at),
    ],
  );
  final memory = replayReviews(
    fromEvents,
    effects: LeechEffects(job.leechActions),
    skills: const SkillMap(),
    parameters: SkillParameters(fitted: job.fitted, lastStudied: lastStudied),
  );
  return OpenedLog(
    cacheStates: cache.states,
    memory: memory,
    index: ProgressIndex()..rebuild(memory.events),
    lastStudied: lastStudied,
    leechActions: job.leechActions,
  );
}

/// Runs an [OpenJob], somewhere.
typedef ReplayRunner = Future<OpenedLog> Function(OpenJob job);

/// [openLog] on the calling isolate: for tests, and where an isolate cannot
/// run.
Future<OpenedLog> replayInPlace(OpenJob job) async => openLog(job);

/// [openLog] on an isolate of its own (#857): sorting and replaying the whole
/// review log takes seconds on a phone once it is long, which on the UI
/// isolate is a frozen app. The log is plain data and so is the result, which
/// comes back without being copied. If the isolate cannot start (the web) or
/// fails, it replays in place, so the result is the same either way, and a
/// log that cannot be replayed at all fails there as it always did.
Future<OpenedLog> replayInIsolate(OpenJob job) async {
  try {
    return await Isolate.run(() => openLog(job));
  } catch (_) {
    return openLog(job);
  }
}
