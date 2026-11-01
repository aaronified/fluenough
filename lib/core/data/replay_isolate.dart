import 'dart:isolate';
import 'dart:typed_data';

import '../models/leech_action.dart';
import '../models/review_event.dart';
import '../progress/progress_index.dart';
import 'replay_snapshot.dart';
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
    this.encode = false,
  });

  final List<LoggedReview> reviews;
  final List<LeechAction> leechActions;
  final Map<SkillKey, FittedParameters> fitted;

  /// Whether the result also carries [OpenedLog.snapshot], made in the same
  /// isolate, to be kept for the next launch (ADR-0051).
  final bool encode;
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
    this.snapshot,
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

  /// This result as [encodeSnapshot] writes it, when the job asked
  /// ([OpenJob.encode]) and it could be written: the bytes to keep for the
  /// next launch. Null never means a wrong replay, only no snapshot.
  final Uint8List? snapshot;
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
  Uint8List? snapshot;
  if (job.encode) {
    try {
      snapshot = encodeSnapshot(memory: memory, cacheStates: cache.states);
    } on Object {
      snapshot = null; // no snapshot is better than failing the open
    }
  }
  return OpenedLog(
    cacheStates: cache.states,
    memory: memory,
    index: ProgressIndex()..rebuild(memory.events),
    lastStudied: lastStudied,
    leechActions: job.leechActions,
    snapshot: snapshot,
  );
}

/// A kept snapshot to open from instead of replaying (ADR-0051): its bytes,
/// the leech actions the database gave, and how many reviews the log it is
/// for holds, which its events must equal in number.
class SnapshotJob {
  const SnapshotJob({
    required this.bytes,
    required this.leechActions,
    required this.reviewCount,
  });

  final Uint8List bytes;
  final List<LeechAction> leechActions;
  final int reviewCount;
}

/// The [OpenedLog] a snapshot holds, with the index and each language's last
/// study built from its events as [openLog] builds them, or null if the
/// snapshot cannot be read or does not hold [SnapshotJob.reviewCount]
/// events, whatever the reason. Pure, like [openLog].
OpenedLog? openFromSnapshot(SnapshotJob job) {
  try {
    final kept = decodeSnapshot(job.bytes);
    final events = kept.memory.events;
    if (events.length != job.reviewCount) return null;
    return OpenedLog(
      cacheStates: kept.cacheStates,
      memory: kept.memory,
      index: ProgressIndex()..rebuild(events),
      lastStudied: SkillParameters.lastStudiedIn(
        <({String cardId, DateTime at})>[
          for (final e in events) (cardId: e.cardId, at: e.at),
        ],
      ),
      leechActions: job.leechActions,
    );
  } on Object {
    return null;
  }
}

/// Opens from a snapshot, somewhere. Null: use the log.
typedef SnapshotRunner = Future<OpenedLog?> Function(SnapshotJob job);

/// [openFromSnapshot] on the calling isolate: for tests.
Future<OpenedLog?> snapshotInPlace(SnapshotJob job) async =>
    openFromSnapshot(job);

/// [openFromSnapshot] on an isolate of its own, so that reading the bytes
/// does not hold the UI isolate. If the isolate cannot start it reads in
/// place; either way a snapshot that cannot be read gives null.
Future<OpenedLog?> snapshotInIsolate(SnapshotJob job) async {
  try {
    return await Isolate.run(() => openFromSnapshot(job));
  } catch (_) {
    return openFromSnapshot(job);
  }
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
