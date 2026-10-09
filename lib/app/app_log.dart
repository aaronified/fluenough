import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/logs/log_entry.dart';

/// Where the app log's lines are kept. An interface so that tests need no
/// file.
abstract interface class LogStore {
  /// Every line kept, oldest first; none if nothing is kept yet.
  Future<List<String>> read();

  /// Adds [line] at the end.
  Future<void> append(String line);

  /// Keeps [lines] in place of everything kept before.
  Future<void> write(List<String> lines);
}

/// [LogStore] in a file on the phone, so that the log of a crash is there
/// after a restart (#162).
class FileLogStore implements LogStore {
  FileLogStore(this.file);

  final File file;

  @override
  Future<List<String>> read() async {
    if (!await file.exists()) return const <String>[];
    return file.readAsLines();
  }

  @override
  Future<void> append(String line) async {
    await file.parent.create(recursive: true);
    await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
  }

  @override
  Future<void> write(List<String> lines) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      lines.isEmpty ? '' : '${lines.join('\n')}\n',
      flush: true,
    );
  }
}

/// [LogStore] in memory: lost when the app closes. For tests, and for a
/// build given no file.
class MemoryLogStore implements LogStore {
  MemoryLogStore([List<String>? lines]) : lines = lines ?? <String>[];

  final List<String> lines;

  @override
  Future<List<String>> read() async => List<String>.of(lines);

  @override
  Future<void> append(String line) async => lines.add(line);

  @override
  Future<void> write(List<String> lines) async {
    this.lines
      ..clear()
      ..addAll(lines);
  }
}

/// The app's own log (#162): errors and warnings, and key events, kept on
/// the phone, capped at the last [logMaxAge] or [logMaxLines] entries,
/// whichever keeps fewer. It never records an answer typed or a card's
/// contents: what is logged is chosen where [event], [warning] and
/// [error] are called, and those calls name screens, decks, skills and
/// counts only.
///
/// Settings' Logs section shows, copies, clears and exports it, and a
/// report attaches it if the reporter ticks the box (ADR-0021).
///
/// Notifies after it changes, a microtask later, so that an error logged
/// while a frame is built does not rebuild a widget in that frame.
class AppLog extends ChangeNotifier {
  AppLog({LogStore? store, this._clock = DateTime.now})
    : _store = store ?? MemoryLogStore();

  final LogStore _store;
  final DateTime Function() _clock;
  final List<LogEntry> _entries = <LogEntry>[];

  /// Writes to the store, one after another, in the order they were asked.
  Future<void> _writes = Future<void>.value();

  /// Lines in the store since it was last written whole: [open] and
  /// compaction write it whole, so that the file stays near the cap.
  int _stored = 0;

  /// Whether [open] has read the store. Until then entries are kept here
  /// only, and [open] writes them after what it read.
  bool _opened = false;
  bool _notifying = false;
  bool _disposed = false;

  /// Every entry kept, oldest first.
  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  /// The log as it is shown, copied, exported and attached: one line an
  /// entry, oldest first.
  String get text => logText(_entries);

  /// Reads what the store kept, puts it before anything logged since this
  /// log was made, caps the whole, and writes it back to the store. Nothing
  /// reaches the store before this; every entry after it does, as it comes.
  Future<void> open() => _queue(() async {
    final List<String> lines;
    try {
      lines = await _store.read();
    } on Exception catch (e) {
      // Left as it is, rather than written over: new entries are added to
      // it.
      debugPrint('fluenough: could not read the app log: $e');
      _opened = true;
      return;
    }
    final read = <LogEntry>[for (final line in lines) ?LogEntry.parse(line)];
    final all = capLog(<LogEntry>[...read, ..._entries], _clock());
    _entries
      ..clear()
      ..addAll(all);
    _opened = true;
    await _writeWhole();
    _changed();
  });

  /// A key event: a screen opened, decks loaded, a fit run, an import or
  /// an export.
  void event(String message) => add(LogLevel.event, message);

  /// Something that did not work, after which the app went on.
  void warning(String message) => add(LogLevel.warning, message);

  /// Something that went wrong. [describeError] writes an error and its
  /// stack.
  void error(String message) => add(LogLevel.error, message);

  void add(LogLevel level, String message) {
    if (_disposed) return;
    final entry = LogEntry(
      _clock(),
      level,
      message.length > logMaxMessage
          ? '${message.substring(0, logMaxMessage)}…'
          : message,
    );
    _entries.add(entry);
    final capped = capLog(_entries, entry.time);
    if (capped.length != _entries.length) {
      _entries
        ..clear()
        ..addAll(capped);
    }
    // The file grows a line at a time, and is written whole, capped, once
    // it holds a tenth more than the cap.
    if (!_opened) {
      // [open] writes it.
    } else if (_stored + 1 > logMaxLines + logMaxLines ~/ 10) {
      _queue(_writeWhole);
    } else {
      _stored++;
      _queue(() => _store.append(entry.line));
    }
    _changed();
  }

  /// Forgets every entry, here and in the store.
  Future<void> clear() {
    _entries.clear();
    _changed();
    return _queue(_writeWhole);
  }

  /// Done when every write asked for so far is: for tests, and before the
  /// log is attached or exported.
  Future<void> get idle => _writes;

  Future<void> _writeWhole() async {
    final lines = <String>[for (final entry in _entries) entry.line];
    _stored = lines.length;
    await _store.write(lines);
  }

  /// Runs [write] after every write before it. A write that fails is told
  /// to the console, never to the log, which would write again.
  Future<void> _queue(Future<void> Function() write) =>
      _writes = _writes.then((_) async {
        try {
          await write();
        } on Exception catch (e) {
          debugPrint('fluenough: could not write the app log: $e');
        }
      });

  void _changed() {
    if (_notifying || _disposed) return;
    _notifying = true;
    scheduleMicrotask(() {
      _notifying = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Logs each screen pushed with a name, as `Opened /deck`: the route's
/// name only, never its argument, which can be a card or an answer.
class LogNavigatorObserver extends NavigatorObserver {
  LogNavigatorObserver(this.log);

  final AppLog log;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _opened(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _opened(newRoute);

  void _opened(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || route is! PageRoute) return;
    log.event('Opened $name');
  }
}

/// Sends every error Flutter reports, and every error nothing caught, to
/// [log] as well as where they went before: Flutter's own handler, and the
/// platform's. Returns what puts the handlers back, for tests.
VoidCallback logErrors(AppLog log, {PlatformDispatcher? dispatcher}) {
  final platform = dispatcher ?? PlatformDispatcher.instance;
  final flutterBefore = FlutterError.onError;
  final platformBefore = platform.onError;
  FlutterError.onError = (details) {
    log.error(
      describeError(
        details.context?.toDescription() ?? 'Flutter error',
        details.exception,
        details.stack,
      ),
    );
    (flutterBefore ?? FlutterError.presentError)(details);
  };
  platform.onError = (error, stack) {
    log.error(describeError('Uncaught', error, stack));
    return platformBefore?.call(error, stack) ?? false;
  };
  return () {
    FlutterError.onError = flutterBefore;
    platform.onError = platformBefore;
  };
}
