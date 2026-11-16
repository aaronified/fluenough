import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;

import '../core/placement/item_bank.dart';
import '../core/placement/item_codec.dart';
import '../core/placement/item_registry.dart' show RegItem;
import '../core/placement/placement_data.dart';
import '../core/placement/saved_run.dart' show placementDeckSetKey;
import 'blob_store.dart';

// The question bank of Find my level V3 (wiki/Plan-Placement-V3.md, "Step
// 7a"): the admitted items of a language, made from its decks. Making them
// takes about 40 s on a desktop and minutes on a phone, so the bank is made
// once per language and deck set, in the background, kept in storage, and
// read back at once the next time. A learner is never made to wait on a
// frozen screen: the build reports its progress, can be left, and reports
// its failure.

/// Makes the items of [data], reporting progress (0 to 1), handing the clean
/// items of the first formats to [onStarter] as soon as they exist (a run can
/// begin with them), and stopping early, with null, when [cancelled] says so.
/// Throws if it cannot.
typedef BankRunner = Future<List<RegItem>?> Function(
  PlacementLanguageData data,
  void Function(double progress) onProgress,
  bool Function() cancelled,
  void Function(List<RegItem> starter) onStarter,
);

/// One build (or read) of a language's bank.
class PlacementBankJob {
  PlacementBankJob._(this.key);

  /// `bank/<language>/<deck set>/v<schema>`, the name the bank is stored
  /// under.
  final String key;

  /// How far the build is, 0 to 1.
  final ValueNotifier<double> progress = ValueNotifier<double>(0);

  final Completer<List<RegItem>> _done = Completer<List<RegItem>>();
  final Completer<List<RegItem>> _first = Completer<List<RegItem>>();
  List<RegItem>? _items;
  Object? _error;
  bool _cancelled = false;

  /// The items, once made; completes with an error when the build failed.
  Future<List<RegItem>> get result => _done.future;

  /// The items if they are ready, else null.
  List<RegItem>? get items => _items;

  /// The items a run can begin with: the clean items of the first formats
  /// while the rest is still being made, then the whole bank.
  Future<List<RegItem>> get first => _first.future;

  List<RegItem>? _starter;

  /// What a run can begin with now (the whole bank once it is made), or null.
  List<RegItem>? get startable => _items ?? _starter;

  /// Why the build failed, or null.
  Object? get error => _error;

  bool get failed => _error != null;

  /// Stops the build; its result is dropped and a later request starts again.
  void cancel() {
    if (_done.isCompleted) return;
    _cancelled = true;
    _fail(StateError('cancelled'));
  }

  void _starterReady(List<RegItem> items) {
    if (_done.isCompleted || _first.isCompleted) return;
    _starter = items;
    _first.complete(items);
  }

  void _succeed(List<RegItem> items) {
    if (_done.isCompleted) return;
    _items = items;
    progress.value = 1;
    _done.complete(items);
    if (!_first.isCompleted) _first.complete(items);
  }

  void _fail(Object error) {
    if (_done.isCompleted) return;
    _error = error;
    // Nobody may be listening: a failure is read from [error].
    _done.future.ignore();
    _done.completeError(error);
    if (!_first.isCompleted) {
      _first.future.ignore();
      _first.completeError(error);
    }
  }
}

/// The banks of an app: the jobs in progress or done, and where banks are
/// kept ([store], null for memory only).
class PlacementBanks {
  PlacementBanks({
    this.store,
    BankRunner? runner,
    void Function(String problem)? onProblem,
  }) : _runner = runner ?? runBankInBackground,
       // ignore: prefer_initializing_formals
       _onProblem = onProblem;

  final BlobStore? store;
  final BankRunner _runner;
  final void Function(String problem)? _onProblem;
  final Map<String, PlacementBankJob> _jobs = <String, PlacementBankJob>{};

  /// The key [data]'s bank is stored under.
  static String keyOf(PlacementLanguageData data) =>
      'bank-${data.language}-${placementDeckSetKey(data)}-v$kItemSchema';

  /// The job that makes (or reads) [data]'s bank: the one already running or
  /// done, or a new one (a failed or cancelled job is replaced).
  PlacementBankJob jobFor(PlacementLanguageData data) {
    final key = keyOf(data);
    final kept = _jobs[key];
    if (kept != null && !kept.failed) return kept;
    final job = PlacementBankJob._(key);
    _jobs[key] = job;
    unawaited(_run(job, data));
    return job;
  }

  Future<void> _run(PlacementBankJob job, PlacementLanguageData data) async {
    try {
      final stored = await _read(job.key);
      if (stored != null) {
        job._starterReady(stored);
        job._succeed(stored);
        return;
      }
      final items = await _runner(
        data,
        (p) => job.progress.value = p,
        () => job._cancelled,
        job._starterReady,
      );
      if (items == null || job._cancelled) {
        job._fail(StateError('cancelled'));
        return;
      }
      job._succeed(items);
      await _save(job.key, data.language, items);
    } on Object catch (error, stack) {
      _onProblem?.call('The question bank failed: $error\n$stack');
      job._fail(error);
    }
  }

  Future<List<RegItem>?> _read(String key) async {
    final s = store;
    if (s == null) return null;
    try {
      final bytes = await s.read(key);
      if (bytes == null) return null;
      final items = decodeItems(utf8.decode(bytes));
      if (items == null) {
        _onProblem?.call('A stored question bank was damaged: $key');
        await s.write(const <String, Uint8List>{}, deletes: <String>[key]);
      }
      return items;
    } on Object catch (e) {
      _onProblem?.call('A stored question bank could not be read: $e');
      return null;
    }
  }

  /// Keeps [items] under [key] and drops the language's other banks (an
  /// older deck set, another schema).
  Future<void> _save(String key, String language, List<RegItem> items) async {
    final s = store;
    if (s == null) return;
    try {
      final stale = <String>[
        for (final k in await s.keys())
          if (k.startsWith('bank-$language-') && k != key) k,
      ];
      await s.write(<String, Uint8List>{
        key: Uint8List.fromList(utf8.encode(encodeItems(items))),
      }, deletes: stale);
    } on Object catch (e) {
      // The bank is only a copy: the run goes on from memory.
      _onProblem?.call('A question bank could not be kept: $e');
    }
  }
}

/// The default [BankRunner]: in an isolate where there is one (it reports its
/// progress and can be stopped), else, in the browser or when an isolate
/// cannot carry the data, in steps on this thread with a pause between them
/// so that the screen keeps drawing.
Future<List<RegItem>?> runBankInBackground(
  PlacementLanguageData data,
  void Function(double progress) onProgress,
  bool Function() cancelled,
  void Function(List<RegItem> starter) onStarter,
) async {
  if (!kIsWeb) {
    try {
      return await _inIsolate(data, onProgress, cancelled, onStarter);
    } on Object {
      if (cancelled()) return null;
      // Whatever an isolate cannot carry, this thread can, in steps.
    }
  }
  return runBankInSteps(data, onProgress, cancelled, onStarter);
}

/// The build in steps on this thread, a pause between them so that the
/// screen keeps drawing (the browser's way).
Future<List<RegItem>?> runBankInSteps(
  PlacementLanguageData data,
  void Function(double progress) onProgress,
  bool Function() cancelled,
  void Function(List<RegItem> starter) onStarter,
) => ItemBank.buildItems(
  data,
  pause: () => Future<void>.delayed(Duration.zero),
  onProgress: onProgress,
  onStarter: onStarter,
  cancelled: cancelled,
);

Future<List<RegItem>?> _inIsolate(
  PlacementLanguageData data,
  void Function(double progress) onProgress,
  bool Function() cancelled,
  void Function(List<RegItem> starter) onStarter,
) async {
  final port = ReceivePort();
  final result = Completer<List<RegItem>?>();
  final isolate = await Isolate.spawn<List<Object>>(
    _bankEntry,
    <Object>[port.sendPort, data],
    errorsAreFatal: true,
    onError: port.sendPort,
    onExit: port.sendPort,
  );
  final watch = Timer.periodic(const Duration(milliseconds: 250), (_) {
    if (cancelled() && !result.isCompleted) {
      isolate.kill(priority: Isolate.immediate);
      result.complete(null);
    }
  });
  port.listen((message) {
    if (result.isCompleted) return;
    if (message is double) {
      onProgress(message);
    } else if (message is String && message.startsWith('S')) {
      final starter = decodeItems(message.substring(1));
      if (starter != null) onStarter(starter);
    } else if (message is String) {
      result.complete(decodeItems(message.substring(1)));
    } else if (message is List) {
      result.completeError(StateError('the bank build failed: $message'));
    } else if (message == null) {
      result.completeError(StateError('the bank build ended with no bank'));
    }
  });
  try {
    final items = await result.future;
    if (items == null && !cancelled()) {
      throw StateError('the bank could not be read back');
    }
    return items;
  } finally {
    watch.cancel();
    port.close();
    isolate.kill(priority: Isolate.immediate);
  }
}

Future<void> _bankEntry(List<Object> args) async {
  final out = args[0] as SendPort;
  final data = args[1] as PlacementLanguageData;
  final items = await ItemBank.buildItems(
    data,
    pause: () => Future<void>.delayed(Duration.zero),
    onProgress: out.send,
    onStarter: (starter) => out.send('S${encodeItems(starter)}'),
  );
  out.send('F${encodeItems(items!)}');
}
