import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/input_mode_choice.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('each script or Latin letters segment is a 48dp tap target, '
      'even at Android\'s smallest text', (tester) async {
    // At 0.85x the labels no longer push the segments past their minimum
    // height, so the minimum is what the learner gets.
    usePhone(tester, textScale: 0.85);
    await pumpScreen(
      tester,
      DrillPage(
        request: DrillRequest.untaught(
          'te-en-first-words',
          skill: Skill.production,
        ),
        preset: const DrillPreset(target: 'నమస్కారం'),
      ),
    );
    final segments = find.descendant(
      of: find.byType(InputModeChoice),
      matching: find.byType(InkWell),
    );
    expect(segments, findsNWidgets(2));
    for (final segment in segments.evaluate()) {
      final size = tester.getSize(find.byElementPredicate((e) => e == segment));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
