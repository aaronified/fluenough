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
  late AppState state;
  setUp(() async {
    state = await kindsWorldApp();
    state.lazyOff = true;
  });
  testWidgets('V5 lazyOff', timeout: _t, (tester) async {
    await tester.pumpWidget(const SizedBox());
    _p('V5 pumped ${state.status}');
  });
}
