// Temporary diagnostics (removed after the fix).
// ignore_for_file: avoid_print
import 'dart:async';
import 'package:fluenough/app/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/kinds_world.dart';

void _p(String m) => print('DIAG ${DateTime.now().toIso8601String()} $m');
const _t = Timeout(Duration(seconds: 25));
Timer? _watch;
void _startWatch(String n) {
  var i = 0;
  _watch = Timer.periodic(const Duration(seconds: 5), (_) {
    _p('$n watch ${i++} phase=${SchedulerBinding.instance.schedulerPhase} frame=${SchedulerBinding.instance.hasScheduledFrame} tc=${SchedulerBinding.instance.transientCallbackCount}');
  });
}

void main() {
  late AppState state;
  setUp(() async {
    state = await kindsWorldApp();
  });
  tearDown(() => _watch?.cancel());
  testWidgets('h5', timeout: _t, (tester) async {
    _startWatch('h5');
    _p('h5 start');
    await state.load(); await tester.pump(); _p('pump() ok'); await tester.pumpWidget(const SizedBox());
    _p('h5 pump done');
  });
}
