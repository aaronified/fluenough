// The skill pills (owner, 2026-11-01): icons only, one colour per level (Leave
// red, Learn and Know two yellows, Learnt dark green), one tick and two ticks
// told apart by shape, at 1.4x text in light and dark.
import 'dart:math' as math;

import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/features/languages/skill_widgets.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

const _marks = <SkillMark>[
  SkillMark.leave,
  SkillMark.learn,
  SkillMark.know,
  SkillMark.knowBoth,
  SkillMark.knowCovered,
  SkillMark.knowBothCovered,
];

Finder _badge(String key) => find.byKey(ValueKey<String>(key));

Finder _icon(Finder badge, SkillKind kind) => find.descendant(
  of: badge,
  matching: find.byKey(ValueKey<String>('pill-icon-${kind.name}')),
);

Finder _mark(Finder badge, String name) => find.descendant(
  of: badge,
  matching: find.byKey(ValueKey<String>('pill-mark-$name')),
);

/// Every combination under test, each pill keyed `kind/mark`.
Future<void> _pumpPills(WidgetTester tester, ThemeMode mode) async {
  usePhone(tester, textScale: 1.4);
  await pumpScreen(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: Wrap(
          children: <Widget>[
            for (final mark in _marks) ...<Widget>[
              SkillBadge(
                key: ValueKey<String>('script/${mark.name}'),
                kind: SkillKind.read,
                combined: true,
                mark: mark,
                name: 'Script',
                big: true,
              ),
              SkillBadge(
                key: ValueKey<String>('spoken/${mark.name}'),
                kind: SkillKind.hear,
                combined: true,
                mark: mark,
                name: 'Spoken',
                big: true,
              ),
              SkillBadge(
                key: ValueKey<String>('gesture/${mark.name}'),
                kind: SkillKind.gesture,
                mark: mark,
                name: 'Gestures',
              ),
            ],
          ],
        ),
      ),
    ),
    themeMode: mode,
  );
}

void main() {
  group('colour tokens', () {
    final sets = <String, ModeColors>{
      'light': ModeColors.light,
      'dark': ModeColors.dark,
      'light high contrast': ModeColors.lightHigh,
      'dark high contrast': ModeColors.darkHigh,
    };
    for (final MapEntry(:key, :value) in sets.entries) {
      test('icon, tick and ring are 4.5:1 on every level in $key', () {
        for (final mark in _marks) {
          final c = pillColors(value, mark);
          expect(
            contrast(c.onContainer, c.container),
            greaterThanOrEqualTo(4.5),
            reason: '${mark.name} in $key',
          );
        }
      });

      test('the four levels have four different fills in $key', () {
        final fills = <Color>{
          for (final mark in _marks) pillColors(value, mark).container,
        };
        expect(fills.length, 4);
      });
    }

    test('Know and Learn are both yellow, Leave red, Learnt green', () {
      for (final modes in sets.values) {
        final know = HSLColor.fromColor(modes.pillKnow.container);
        final learn = HSLColor.fromColor(modes.pillLearn.container);
        expect(know.hue, inInclusiveRange(40, 55));
        expect(learn.hue, inInclusiveRange(40, 55));
        expect(
          HSLColor.fromColor(modes.pillLeave.container).hue,
          anyOf(lessThan(10), greaterThan(350)),
        );
        expect(
          HSLColor.fromColor(modes.pillVerified.container).hue,
          inInclusiveRange(100, 140),
        );
      }
    });
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    group('pills at 1.4x text in ${mode.name}', () {
      testWidgets('each level shows the right icons and mark', (tester) async {
        await _pumpPills(tester, mode);
        expect(tester.takeException(), isNull);
        void shows(
          String key, {
          required List<SkillKind> icons,
          required String mark,
        }) {
          final badge = _badge(key);
          expect(badge, findsOneWidget, reason: key);
          for (final kind in SkillKind.values) {
            expect(
              _icon(badge, kind),
              icons.contains(kind) ? findsOneWidget : findsNothing,
              reason: '$key icon ${kind.name}',
            );
          }
          expect(_mark(badge, mark), findsOneWidget, reason: '$key mark');
          for (final other in <String>[
            'leave',
            'learn',
            'know',
            'verified',
          ].where((m) => m != mark)) {
            expect(_mark(badge, other), findsNothing, reason: '$key $other');
          }
        }

        // Leave: the block icon alone, whatever the pill.
        for (final kind in <String>['script', 'spoken', 'gesture']) {
          shows('$kind/leave', icons: const <SkillKind>[], mark: 'leave');
        }
        // Learn: the cap alone on a combined pill, the skill's icon and the
        // cap on a single skill.
        shows('script/learn', icons: const <SkillKind>[], mark: 'learn');
        shows('spoken/learn', icons: const <SkillKind>[], mark: 'learn');
        shows(
          'gesture/learn',
          icons: const <SkillKind>[SkillKind.gesture],
          mark: 'learn',
        );
        // Know and Learnt: only the icons of the levels reached.
        shows(
          'script/know',
          icons: const <SkillKind>[SkillKind.read],
          mark: 'know',
        );
        shows(
          'script/knowBoth',
          icons: const <SkillKind>[SkillKind.read, SkillKind.write],
          mark: 'know',
        );
        shows(
          'script/knowCovered',
          icons: const <SkillKind>[SkillKind.read],
          mark: 'verified',
        );
        shows(
          'script/knowBothCovered',
          icons: const <SkillKind>[SkillKind.read, SkillKind.write],
          mark: 'verified',
        );
        shows(
          'spoken/know',
          icons: const <SkillKind>[SkillKind.hear],
          mark: 'know',
        );
        shows(
          'spoken/knowBoth',
          icons: const <SkillKind>[SkillKind.hear, SkillKind.speak],
          mark: 'know',
        );
        shows(
          'spoken/knowCovered',
          icons: const <SkillKind>[SkillKind.hear],
          mark: 'verified',
        );
        shows(
          'spoken/knowBothCovered',
          icons: const <SkillKind>[SkillKind.hear, SkillKind.speak],
          mark: 'verified',
        );
        shows(
          'gesture/know',
          icons: const <SkillKind>[SkillKind.gesture],
          mark: 'know',
        );
        shows(
          'gesture/knowCovered',
          icons: const <SkillKind>[SkillKind.gesture],
          mark: 'verified',
        );
      });

      testWidgets('one tick and two ticks are different widgets, glyphs, '
          'sizes and fills', (tester) async {
        await _pumpPills(tester, mode);
        final oneTick = _mark(_badge('spoken/knowBoth'), 'know');
        final twoTicks = _mark(_badge('spoken/knowBothCovered'), 'verified');
        expect(oneTick, findsOneWidget);
        expect(twoTicks, findsOneWidget);
        // One tick is a check inside an outlined circle; two ticks are
        // done_all on a filled capsule.
        expect(
          find.descendant(of: oneTick, matching: find.byIcon(Icons.check)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: oneTick, matching: find.byIcon(Icons.done_all)),
          findsNothing,
        );
        expect(
          find.descendant(of: twoTicks, matching: find.byIcon(Icons.done_all)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: twoTicks, matching: find.byIcon(Icons.check)),
          findsNothing,
        );
        final a =
            tester.widget<Container>(oneTick).decoration! as BoxDecoration;
        final b =
            tester.widget<Container>(twoTicks).decoration! as BoxDecoration;
        expect(a.shape, BoxShape.circle);
        expect(a.border, isNotNull);
        expect(a.color, isNull, reason: 'outlined, not filled');
        expect(b.color, isNotNull, reason: 'filled');
        expect(b.border, isNull);
        expect(
          tester.getSize(twoTicks).width,
          greaterThan(tester.getSize(oneTick).width),
          reason: 'the double tick is the bigger mark',
        );
      });

      testWidgets('a pill is filled with its level colour from the theme', (
        tester,
      ) async {
        await _pumpPills(tester, mode);
        final modes = ModeColors.of(tester.element(find.byType(Scaffold)));
        final want = <String, Color>{
          'leave': modes.pillLeave.container,
          'learn': modes.pillLearn.container,
          'know': modes.pillKnow.container,
          'knowBoth': modes.pillKnow.container,
          'knowCovered': modes.pillVerified.container,
          'knowBothCovered': modes.pillVerified.container,
        };
        for (final MapEntry(:key, :value) in want.entries) {
          final fill = find.descendant(
            of: _badge('script/$key'),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).color == value &&
                  (w.decoration! as BoxDecoration).shape == BoxShape.rectangle,
            ),
          );
          expect(fill, findsOneWidget, reason: key);
        }
        // Know and Learn are two different yellows.
        expect(modes.pillKnow.container, isNot(modes.pillLearn.container));
      });

      testWidgets('a long press says the level in a word or two and a screen '
          'reader reads the name and the full phrase', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await _pumpPills(tester, mode);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(Scaffold)),
          )!;
          final spoken = <String, String>{
            'spoken/leave': l10n.languagesPillLeave,
            'spoken/learn': l10n.languagesPillLearning,
            'spoken/know': l10n.languagesPillHear,
            'spoken/knowBoth': l10n.languagesPillHearSpeak,
            'spoken/knowCovered': l10n.languagesPillChecked(
              l10n.languagesPillHear,
            ),
            'spoken/knowBothCovered': l10n.languagesPillChecked(
              l10n.languagesPillHearSpeak,
            ),
            'script/know': l10n.languagesPillRead,
            'script/knowBothCovered': l10n.languagesPillChecked(
              l10n.languagesPillReadWrite,
            ),
            'gesture/learn': l10n.languagesPillLearnGesture,
            'gesture/know': l10n.languagesPillGesture,
          };
          for (final MapEntry(:key, :value) in spoken.entries) {
            final name = key.startsWith('spoken')
                ? 'Spoken'
                : key.startsWith('script')
                ? 'Script'
                : 'Gestures';
            expect(
              tester.getSemantics(_badge(key)).label,
              l10n.languagesSkillState(name, value),
              reason: key,
            );
            // The long press shows the level's own words, nothing else.
            final tip = tester.widget<Tooltip>(
              find.descendant(of: _badge(key), matching: find.byType(Tooltip)),
            );
            expect(tip.message, value, reason: key);
          }
          final target = _badge('spoken/knowBothCovered');
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.longPress(target);
          await tester.pumpAndSettle();
          expect(
            find.text(l10n.languagesPillChecked(l10n.languagesPillHearSpeak)),
            findsOneWidget,
          );
        } finally {
          handle.dispose();
        }
      });

      testWidgets('the Learn pill has a visible edge against the surface', (
        tester,
      ) async {
        await _pumpPills(tester, mode);
        final modes = ModeColors.of(tester.element(find.byType(Scaffold)));
        final surface = Theme.of(tester.element(find.byType(Scaffold)))
            .colorScheme
            .surface;
        final ring = tester
            .widgetList<Container>(
              find.descendant(
                of: _badge('spoken/learn'),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.foregroundDecoration)
            .whereType<BoxDecoration>()
            .single;
        final edge = (ring.border! as Border).top.color;
        expect(edge, modes.pillLearn.onContainer);
        expect(contrast(edge, surface), greaterThanOrEqualTo(3));
      });
    });
  }
}
