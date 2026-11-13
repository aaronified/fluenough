// Temporary diagnostics (removed after the fix).
// ignore_for_file: avoid_print
import 'dart:async';
import 'package:fluenough/app/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kinds_world.dart';

void _p(String m) => print('DIAG ${DateTime.now().toIso8601String()} $m');
const _t = Timeout(Duration(seconds: 20));
int _n = 0, _log = 0, _set = 0, _prog = 0;
Timer? _watch;

void main() {
  late AppState state;
  setUp(() async {
    state = await kindsWorldApp();
    _n = _log = _set = _prog = 0;
    state.addListener(() => _n++);
    state.log.addListener(() => _log++);
    state.settings.addListener(() => _set++);
    state.progress.addListener(() => _prog++);
    var i = 0;
    _watch = Timer.periodic(const Duration(seconds: 3), (_) {
      _p('g3 watch ${i++} state=$_n log=$_log settings=$_set progress=$_prog phase=${SchedulerBinding.instance.schedulerPhase} frame=${SchedulerBinding.instance.hasScheduledFrame}');
    });
  });
  tearDown(() => _watch?.cancel());
  testWidgets('g3', timeout: _t, (tester) async {
    _p('before load'); await state.load(); _p('after load'); await tester.pump(); _p('after plain pump');
    _p('g3 end');
  });
}
