import 'review_event.dart';

/// Something the learner did about a leech (#19). Undoing is an action of
/// its own: nothing is ever removed, like the review log (AGENTS.md rule 9).
enum LeechActionKind { reset, undoReset, setAside, bringBack }

/// One leech action, on one `(card, mode)` pair.
class LeechAction {
  const LeechAction({required this.at, required this.key, required this.kind});

  final DateTime at;
  final ProgressKey key;
  final LeechActionKind kind;

  @override
  String toString() =>
      'LeechAction(${key.cardId} '
      '${key.mode.name}, ${kind.name})';
}

/// What a sequence of leech actions adds up to, for scheduling.
///
/// A reset holds until it is undone, and the latest one counts: the pair's
/// reviews before it are kept but no longer schedule it. Undo takes back
/// only the latest reset, so an earlier one holds again. A set-aside holds
/// until the pair is brought back, and keeps the pair out of every session.
class LeechEffects {
  /// The effects of [actions], oldest first.
  factory LeechEffects(Iterable<LeechAction> actions) {
    final resets = <ProgressKey, List<DateTime>>{};
    final setAside = <ProgressKey>{};
    for (final action in actions) {
      switch (action.kind) {
        case LeechActionKind.reset:
          (resets[action.key] ??= <DateTime>[]).add(action.at);
        case LeechActionKind.undoReset:
          final held = resets[action.key];
          if (held != null && held.isNotEmpty) held.removeLast();
        case LeechActionKind.setAside:
          setAside.add(action.key);
        case LeechActionKind.bringBack:
          setAside.remove(action.key);
      }
    }
    return LeechEffects._(<ProgressKey, DateTime>{
      for (final MapEntry(:key, :value) in resets.entries)
        if (value.isNotEmpty) key: value.last,
    }, setAside);
  }

  const LeechEffects._(this._resetAt, this._setAside);

  /// No actions at all.
  static const LeechEffects none = LeechEffects._(
    <ProgressKey, DateTime>{},
    <ProgressKey>{},
  );

  final Map<ProgressKey, DateTime> _resetAt;
  final Set<ProgressKey> _setAside;

  /// When [key] was last reset, if that reset still holds.
  DateTime? resetAt(ProgressKey key) => _resetAt[key];

  /// Every pair whose reset still holds, and when it was reset.
  Map<ProgressKey, DateTime> get resets => Map.unmodifiable(_resetAt);

  bool isSetAside(ProgressKey key) => _setAside.contains(key);
}
