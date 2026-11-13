// Temporary diagnostics for the hanging topic and search tests. Removed once
// the cause is fixed.
// ignore_for_file: avoid_print
import 'package:fluenough/app/app_scope.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/topics/topic_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/kinds_world.dart';

void _p(String m) => print('DIAG ${DateTime.now().toIso8601String()} $m');

void main() {
  testWidgets('A plain state', timeout: const Timeout(Duration(seconds: 40)), (
    tester,
  ) async {
    final s = AppState.test();
    _p('A load');
    await s.load();
    _p('A pump1');
    await tester.pumpWidget(const SizedBox());
    _p('A pump1 done');
    await tester.pumpWidget(const SizedBox());
    _p('A done');
  });

  group('kinds world', () {
    late AppState state;
    setUp(() async {
      _p('setUp');
      state = await kindsWorldApp();
      _p('setUp done');
    });

    testWidgets('B empty pump', timeout: const Timeout(Duration(seconds: 40)), (
      tester,
    ) async {
      _p('B load');
      await state.load();
      _p('B load done; pumping SizedBox');
      await tester.pumpWidget(const SizedBox());
      _p('B SizedBox pumped');
    });

    testWidgets('C page bounded', timeout: const Timeout(Duration(seconds: 40)), (
      tester,
    ) async {
      usePhone(tester);
      await state.load();
      _p('C pump SizedBox');
      await tester.pumpWidget(const SizedBox());
      _p('C pump page');
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: TopicPage(
              request: const TopicRequest(language: 'zz', topicId: 'zz-house'),
            ),
          ),
        ),
      );
      _p('C page pumped, hasScheduledFrame=${tester.binding.hasScheduledFrame}');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        _p('C frame $i scheduled=${tester.binding.hasScheduledFrame}');
        if (!tester.binding.hasScheduledFrame) break;
      }
    });
  });
}
