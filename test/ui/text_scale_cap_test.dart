import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/ui/theme.dart';

import '../support/harness.dart';

void main() {
  testWidgets('the app caps the phone\'s 2x text at 1.4x (#505)', (
    tester,
  ) async {
    usePhone(tester, textScale: 2.0);
    await pumpApp(tester);
    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(AppSizes.maxTextScale, 1.4);
    expect(scaler.scale(10), closeTo(14, 0.001));
  });

  testWidgets('text below the cap keeps the phone\'s size (#505)', (
    tester,
  ) async {
    usePhone(tester, textScale: 1.2);
    await pumpApp(tester);
    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(Scaffold).first),
    );
    expect(scaler.scale(10), closeTo(12, 0.001));
  });
}
