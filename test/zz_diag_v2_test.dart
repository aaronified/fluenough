// Temporary diagnostics (removed after the fix).
// ignore_for_file: avoid_print
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kinds_world.dart';

void _p(String m) => print('DIAG ${DateTime.now().toIso8601String()} $m');
const _t = Timeout(Duration(seconds: 30));

void main() {
  testWidgets('V2 built inside runAsync', timeout: _t, (tester) async {
    final state = (await tester.runAsync(() => kindsWorldApp()))!;
    _p('built; frame=${tester.binding.hasScheduledFrame} tasks=${SchedulerBinding.instance.transientCallbackCount}');
    await tester.pumpWidget(const SizedBox());
    _p('V2 pumped ${state.status}');
  });
}
