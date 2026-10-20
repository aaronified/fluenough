import 'dart:async';
import 'dart:collection';

/// A fixed number of slots handed out fairly: a free slot goes to the
/// waiting key that holds the fewest, the one waiting longest on a tie, so
/// that one key with many waiting never holds every slot while another
/// waits. A key that has nothing waiting gives its share to the others.
class FairSlots {
  FairSlots(this.limit);

  final int limit;
  int _busy = 0;
  final Map<String, int> _held = <String, int>{};

  /// The keys with waiters, the longest waiting first.
  final Map<String, Queue<Completer<void>>> _waiting =
      <String, Queue<Completer<void>>>{};
  bool _scheduled = false;

  /// Completes once [key] holds a slot, which it gives back with
  /// [release]. Waiters of every key that ask in the same moment are
  /// served fairly, not in the order they asked.
  Future<void> acquire(String key) {
    final waiter = Completer<void>();
    (_waiting[key] ??= Queue<Completer<void>>()).add(waiter);
    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(() {
        _scheduled = false;
        _grant();
      });
    }
    return waiter.future;
  }

  /// Gives back a slot [key] held.
  void release(String key) {
    _busy--;
    _held[key] = _held[key]! - 1;
    _grant();
  }

  void _grant() {
    while (_busy < limit && _waiting.isNotEmpty) {
      var key = _waiting.keys.first;
      for (final other in _waiting.keys) {
        if ((_held[other] ?? 0) < (_held[key] ?? 0)) key = other;
      }
      final queue = _waiting[key]!;
      queue.removeFirst().complete();
      if (queue.isEmpty) _waiting.remove(key);
      _busy++;
      _held[key] = (_held[key] ?? 0) + 1;
    }
  }
}
