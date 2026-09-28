import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/expressive_shape.dart';
import 'package:fluenough/ui/widgets/mode_pill.dart';
import 'package:fluenough/ui/widgets/segmented.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:fluenough/ui/widgets/wave_progress.dart';

import '../support/harness.dart';

const LanguageInfo urdu = LanguageInfo(
  code: 'ur',
  iso639_3: 'urd',
  name: 'Urdu',
  script: 'arabic',
  rtl: true,
);

void main() {
  testWidgets('Segmented: one selected, in a named group, tap selects', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var picked = 30;
    await pumpScreen(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context)!;
            return Segmented<int>(
              semanticLabel: l10n.statsRangeGroup,
              selected: picked,
              onSelected: (v) => setState(() => picked = v),
              options: <SegmentOption<int>>[
                SegmentOption(value: 7, label: l10n.statsRangeDays(7)),
                SegmentOption(value: 30, label: l10n.statsRangeDays(30)),
                SegmentOption(value: 0, label: l10n.statsRangeAll),
              ],
            );
          },
        ),
      ),
    );
    final l10n = l10nOf(tester);
    expect(
      tester.getSemantics(find.text(l10n.statsRangeDays(30))),
      matchesSemantics(
        label: l10n.statsRangeDays(30),
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isFocusable: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.text(l10n.statsRangeAll));
    await tester.pumpAndSettle();
    expect(picked, 0);
    handle.dispose();
  });

  testWidgets('WaveProgress is a named progress node', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return WaveProgress(
              value: 0.25,
              semanticsLabel: l10n.drillProgressLabel,
              semanticsValue: l10n.drillPosition(3, 8),
            );
          },
        ),
      ),
    );
    final l10n = l10nOf(tester);
    expect(
      tester.getSemantics(find.byType(WaveProgress)),
      matchesSemantics(
        label: l10n.drillProgressLabel,
        value: l10n.drillPosition(3, 8),
      ),
    );
    handle.dispose();
  });

  testWidgets('ModePill carries the skill name and its fixed colour', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const Scaffold(body: ModePill(skill: Skill.listening)),
    );
    final l10n = l10nOf(tester);
    expect(find.text(l10n.skillListening), findsOneWidget);
    final box = tester.widget<Container>(
      find
          .ancestor(
            of: find.text(l10n.skillListening),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, ModeColors.light.listening.container);
  });

  testWidgets('TargetText follows the deck, not the interface', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(body: TargetText.hero('کتاب', language: urdu)),
    );
    final text = tester.widget<Text>(find.text('کتاب'));
    expect(text.textDirection, TextDirection.rtl);
    expect(text.locale, const Locale('ur'));
    expect(text.style!.height, TargetSizes.rtlHeight);
    expect(text.style!.fontSize, 64, reason: 'four graphemes');
  });

  test('target sizes step down with length and scale with the setting', () {
    expect(TargetSizes.forText('あ'), 96);
    // क plus its vowel sign is two code points but one grapheme.
    expect(TargetSizes.forText('कि'), 96);
    expect(TargetSizes.forText('औरत'), 64);
    expect(TargetSizes.forText('la casa'), 48);
    expect(TargetSizes.forText('あ', scale: 1.4), closeTo(134.4, 1e-9));
  });

  test('an expressive shape fills its box and stays inside it', () {
    const rect = Rect.fromLTWH(0, 0, 112, 112);
    for (final shape in ExpressiveShape.values) {
      final bounds = shape.pathIn(rect).getBounds();
      expect(rect.inflate(0.01).contains(bounds.topLeft), isTrue);
      expect(rect.inflate(0.01).contains(bounds.bottomRight), isTrue);
      // Lobes pointing between the axes, like the clover's, leave the
      // shape narrower than its box; none is less than 80% of it.
      expect(bounds.width, greaterThan(0.8 * 112), reason: shape.name);
    }
  });
}
