import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_log.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/core/logs/log_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime.utc(2026, 10, 9, 12);

  /// A clock that reads [now], which a test moves on.
  DateTime now = start;
  DateTime clock() => now;
  setUp(() => now = start);

  String line(Duration ago, String message) =>
      LogEntry(start.subtract(ago), LogLevel.event, message).line;

  group('the app log', () {
    test('once open, writes each entry to its store as it comes', () async {
      final store = MemoryLogStore();
      final log = AppLog(store: store, clock: clock);
      await log.open();
      log
        ..event('Opened /deck')
        ..warning('Review log not exported: PathException')
        ..error('Uncaught: Bad state');
      await log.idle;
      expect(store.lines, <String>[
        '2026-10-09T12:00:00.000Z EVENT Opened /deck',
        '2026-10-09T12:00:00.000Z WARN Review log not exported: '
            'PathException',
        '2026-10-09T12:00:00.000Z ERROR Uncaught: Bad state',
      ]);
      expect(log.text, store.lines.join('\n'));
    });

    test('opening reads what was kept, capped by age, before what was logged '
        'since, and writes the store again', () async {
      final store = MemoryLogStore(<String>[
        line(const Duration(days: 8), 'too old'),
        'not a line',
        line(const Duration(days: 2), 'kept'),
      ]);
      final log = AppLog(store: store, clock: clock)..event('App started');
      await log.idle;
      expect(store.lines, hasLength(3), reason: 'nothing written before open');
      await log.open();
      expect(
        <String>[for (final e in log.entries) e.message],
        <String>['kept', 'App started'],
      );
      expect(store.lines, <String>[for (final e in log.entries) e.line]);
    });

    test('opening keeps the last 2,000 lines', () async {
      final store = MemoryLogStore(<String>[
        for (var i = 0; i < 2300; i++)
          line(Duration(seconds: 2300 - i), 'line $i'),
      ]);
      final log = AppLog(store: store, clock: clock);
      await log.open();
      expect(log.entries, hasLength(logMaxLines));
      expect(log.entries.first.message, 'line 300');
      expect(store.lines, hasLength(logMaxLines));
    });

    test('while running, it keeps no more than the cap, and its store is '
        'written whole again before it grows far past it', () async {
      final store = MemoryLogStore();
      final log = AppLog(store: store, clock: clock);
      await log.open();
      for (var i = 0; i < 2500; i++) {
        now = start.add(Duration(seconds: i));
        log.event('Opened /deck $i');
      }
      await log.idle;
      expect(log.entries, hasLength(logMaxLines));
      expect(log.entries.last.message, 'Opened /deck 2499');
      expect(store.lines.length, lessThanOrEqualTo(2200));
      expect(store.lines.last, log.entries.last.line);

      // A week on, everything older than 7 days goes as the next entry comes.
      now = start.add(const Duration(days: 7, hours: 1));
      log.event('Opened /deck');
      expect(log.entries, hasLength(1));
    });

    test('survives a restart in its file', () async {
      final folder = await Directory.systemTemp.createTemp('fluenough-log');
      addTearDown(() => folder.delete(recursive: true));
      final file = File('${folder.path}/logs/app.log');
      final before = AppLog(store: FileLogStore(file), clock: clock);
      await before.open();
      before
        ..event('Opened /drill')
        ..error('Uncaught: crash');
      await before.idle;

      final after = AppLog(store: FileLogStore(file), clock: clock);
      await after.open();
      expect(
        <String>[for (final e in after.entries) e.message],
        <String>['Opened /drill', 'Uncaught: crash'],
      );
      expect(after.entries.last.level, LogLevel.error);
    });

    test('clearing empties it and its store', () async {
      final store = MemoryLogStore();
      final log = AppLog(store: store, clock: clock)..event('x');
      await log.clear();
      expect(log.isEmpty, isTrue);
      expect(log.text, '');
      expect(store.lines, isEmpty);
    });

    test('a store that fails does not stop the app, or log itself', () async {
      final log = AppLog(store: _FailingStore(), clock: clock);
      await log.open();
      log.event('x');
      await log.idle;
      expect(log.entries, hasLength(1));
    });

    test('an entry far too long is cut', () {
      final log = AppLog(clock: clock)..error('x' * 5000);
      expect(log.entries.single.message, hasLength(logMaxMessage + 1));
      expect(log.entries.single.message, endsWith('…'));
    });

    test('tells its listeners after it changes, not during', () async {
      final log = AppLog(clock: clock);
      var told = 0;
      log.addListener(() => told++);
      log
        ..event('a')
        ..event('b');
      expect(told, 0);
      await Future<void>.delayed(Duration.zero);
      expect(told, 1);
    });
  });

  group('screens opened', () {
    testWidgets('a named page is logged by its name only; dialogs and '
        'unnamed pages are not', (tester) async {
      final log = AppLog(clock: clock);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          navigatorObservers: <NavigatorObserver>[LogNavigatorObserver(log)],
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox(),
          ),
        ),
      );
      key.currentState!.pushNamed('/deck', arguments: 'secret-card-text');
      await tester.pumpAndSettle();
      key.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: key.currentContext!,
          routeSettings: const RouteSettings(name: '/dialog'),
          builder: (_) => const SizedBox(),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.pushReplacementNamed('/inspect');
      await tester.pumpAndSettle();
      final messages = <String>[for (final e in log.entries) e.message];
      expect(messages, <String>['Opened /', 'Opened /deck', 'Opened /inspect']);
      expect(log.text, isNot(contains('secret')));
    });
  });

  group('the app logs', () {
    testWidgets('decks loaded and tabs opened', (tester) async {
      final log = AppLog(clock: clock);
      final state = AppState.test(log: log);
      addTearDown(state.dispose);
      await tester.runAsync(state.load);
      expect(log.entries.first.message, 'Decks loaded: ${state.decks.length}');
      state.shellTab.value = ShellTab.settings;
      expect(log.entries.last.message, 'Opened tab settings');
    });
  });

  group('errors', () {
    test('Flutter errors and uncaught ones go to the log, and on to where '
        'they went before', () {
      final log = AppLog(clock: clock);
      final dispatcher = PlatformDispatcher.instance;
      final flutterBefore = FlutterError.onError;
      final platformBefore = dispatcher.onError;
      final presented = <FlutterErrorDetails>[];
      final uncaught = <Object>[];
      FlutterError.onError = presented.add;
      dispatcher.onError = (error, stack) {
        uncaught.add(error);
        return true;
      };
      final restore = logErrors(log);
      try {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError('layout broke'),
            stack: StackTrace.fromString('#0 build (a.dart:1)'),
            context: ErrorDescription('while building Today'),
          ),
        );
        final handled = dispatcher.onError!(
          ArgumentError('bad'),
          StackTrace.fromString('#0 main (b.dart:2)'),
        );
        expect(handled, isTrue);
        expect(presented, hasLength(1));
        expect(uncaught.single, isArgumentError);
        expect(
          <LogLevel>[for (final e in log.entries) e.level],
          <LogLevel>[LogLevel.error, LogLevel.error],
        );
        expect(
          log.entries.first.message,
          'while building Today: StateError\n#0 build (a.dart:1)',
        );
        expect(
          log.entries.last.message,
          'Uncaught: ArgumentError\n#0 main (b.dart:2)',
        );
      } finally {
        restore();
        expect(FlutterError.onError, presented.add);
        FlutterError.onError = flutterBefore;
        dispatcher.onError = platformBefore;
      }
    });

    test('with nothing before, an uncaught error is left unhandled', () {
      final log = AppLog(clock: clock);
      final dispatcher = PlatformDispatcher.instance;
      final platformBefore = dispatcher.onError;
      dispatcher.onError = null;
      final restore = logErrors(log);
      try {
        expect(dispatcher.onError!(StateError('x'), StackTrace.empty), isFalse);
        expect(log.entries.single.level, LogLevel.error);
      } finally {
        restore();
        expect(dispatcher.onError, isNull);
        dispatcher.onError = platformBefore;
      }
    });
  });
}

class _FailingStore implements LogStore {
  @override
  Future<void> append(String line) async =>
      throw const FileSystemException('full');

  @override
  Future<List<String>> read() async => throw const FileSystemException('gone');

  @override
  Future<void> write(List<String> lines) async =>
      throw const FileSystemException('full');
}
