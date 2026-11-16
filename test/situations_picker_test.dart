// The situations picker (#1145): a pencil at the top right of Today's
// Situations card opens a dialog with two sections, On Today (at most six,
// in order) and More situations (a tap adds); the card shows the first six
// chosen, per language. Labels on both are fitted by one FittedLabel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/situations.dart';
import 'package:fluenough/features/situations/fitted_label.dart';
import 'package:fluenough/features/situations/situations_editor.dart';
import 'package:fluenough/features/today/situations_card.dart';

import 'support/harness.dart';

const String _words = '''
schema: 1
id: hi-en-words
name: "Words"
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-en-words-0001, target: "कख", native: "word 1", reading: "kakha" }
''';

/// Eight situations, so that two are past the card's six. [titles] names
/// them (default "Scene 1" to "Scene 8").
String _situations([List<String>? titles]) {
  const icons = <String>[
    'taxi',
    'shops',
    'eat',
    'doctor',
    'traffic',
    'rail',
    'office',
    'bank',
  ];
  final rows = <String>[
    for (var i = 0; i < icons.length; i++)
      '  - id: s${i + 1}\n'
          '    icon: ${icons[i]}\n'
          '    title: { en: "${titles?[i] ?? 'Scene ${i + 1}'}" }\n'
          '    words: ["hi-en-words-0001"]',
  ];
  return '''
schema: 1
id: hi-situations
name: "Hindustani situations"
kind: situations
language: { code: hi, iso639_3: hin, name: Hindustani, script: devanagari }
license: "CC-BY-SA-4.0"
situations:
${rows.join('\n')}
''';
}

AppState _learner({List<String>? titles}) {
  final state = AppState.test(
    decks: MemoryDeckSource(<String, String>{
      'decks/hi/hi-en-words.yaml': _words,
      'decks/hi/hi-situations.yaml': _situations(titles),
    }),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningLanguages: const <String>['hi'],
      learningChosen: true,
    ),
  );
  addTearDown(state.dispose);
  return state;
}

Future<AppState> _pumpCard(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
  AppState? state,
}) {
  usePhone(tester, textScale: 1.4);
  return pumpScreen(
    tester,
    const Scaffold(body: SingleChildScrollView(child: SituationsCard())),
    state: state ?? _learner(),
    themeMode: themeMode,
  );
}

void main() {
  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('the card shows the first six situations, and a pencil '
        'opens the editor with all eight (${mode.name}, 1.4x)', (tester) async {
      await _pumpCard(tester, themeMode: mode);
      final l10n = l10nOf(tester);
      for (var i = 1; i <= 6; i++) {
        expect(find.text('Scene $i'), findsOneWidget);
      }
      expect(find.text('Scene 7'), findsNothing);
      expect(find.byTooltip(l10n.hintEdit), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.hintEdit));
      await tester.pumpAndSettle();
      expect(find.text(l10n.situationsEditTitle), findsOneWidget);
      expect(find.byType(SituationsEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping a tile under More adds it once there is room, a tile '
      'on Today removes it, and Done saves the choice for the language', (
    tester,
  ) async {
    final state = await _pumpCard(tester);
    final l10n = l10nOf(tester);
    await tester.tap(find.byTooltip(l10n.hintEdit));
    await tester.pumpAndSettle();

    final editor = find.byType(SituationsEditor);
    Finder tile(String title) =>
        find.descendant(of: editor, matching: find.text(title));
    await tester.ensureVisible(tile('Scene 1'));
    await tester.tap(tile('Scene 1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(tile('Scene 7'));
    await tester.tap(tile('Scene 7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();

    expect(state.settings.situationsShownOf('hi'), <String>[
      's2',
      's3',
      's4',
      's5',
      's6',
      's7',
    ]);
    expect(find.text('Scene 1'), findsNothing);
    expect(find.text('Scene 7'), findsOneWidget);
    expect(find.text('Scene 8'), findsNothing);
  });

  testWidgets('Reset to defaults and Done leave no choice stored, so the '
      'card follows the deck again', (tester) async {
    final state = _learner();
    state.settings.setSituationsShown('hi', <String>['s8', 's7']);
    await _pumpCard(tester, state: state);
    final l10n = l10nOf(tester);
    expect(find.text('Scene 8'), findsOneWidget);
    expect(find.text('Scene 1'), findsNothing);

    await tester.tap(find.byTooltip(l10n.hintEdit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.situationsEditReset));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();

    expect(state.settings.situationsShownOf('hi'), isNull);
    expect(find.text('Scene 1'), findsOneWidget);
    expect(find.text('Scene 8'), findsNothing);
  });

  testWidgets('a long press drags a chosen tile to another place', (
    tester,
  ) async {
    final state = await _pumpCard(tester);
    final l10n = l10nOf(tester);
    await tester.tap(find.byTooltip(l10n.hintEdit));
    await tester.pumpAndSettle();

    final editor = find.byType(SituationsEditor);
    final from = tester.getCenter(
      find.descendant(of: editor, matching: find.text('Scene 1')),
    );
    final to = tester.getCenter(
      find.descendant(of: editor, matching: find.text('Scene 3')),
    );
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(to, timeStamp: const Duration(milliseconds: 800));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonDone));
    await tester.pumpAndSettle();

    expect(state.settings.situationsShownOf('hi'), <String>[
      's2',
      's3',
      's1',
      's4',
      's5',
      's6',
    ]);
  });

  group('the two sections', () {
    Future<AppState> open(WidgetTester tester, {AppState? state}) async {
      final s = await _pumpCard(tester, state: state);
      await tester.tap(find.byTooltip(l10nOf(tester).hintEdit));
      await tester.pumpAndSettle();
      return s;
    }

    Finder tile(String title) => find.descendant(
      of: find.byType(SituationsEditor),
      matching: find.text(title),
    );

    VoidCallback? onTapOf(WidgetTester tester, String title) => tester
        .widget<InkWell>(
          find
              .ancestor(of: tile(title), matching: find.byType(InkWell))
              .first,
        )
        .onTap;

    Finder count(WidgetTester tester, int n) =>
        find.text(l10nOf(tester).situationsEditCount(n, situationsOnCard));

    testWidgets('On Today has a counter, the one instruction, and no '
        'numbers or help text', (tester) async {
      await open(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.situationsEditOnToday), findsOneWidget);
      expect(find.text(l10n.situationsEditMore), findsOneWidget);
      expect(count(tester, 6), findsOneWidget);
      expect(find.text(l10n.situationsEditReorder), findsOneWidget);
      // No per-tile place numbers.
      for (var n = 1; n <= 6; n++) {
        expect(
          find.descendant(
            of: find.byType(SituationsEditor),
            matching: find.text('$n'),
          ),
          findsNothing,
        );
      }
    });

    testWidgets('no more than six can be on Today: a tap on a tile under '
        'More does nothing at six, and it is disabled', (tester) async {
      final state = await open(tester);
      expect(count(tester, 6), findsOneWidget);
      expect(onTapOf(tester, 'Scene 7'), isNull);
      expect(onTapOf(tester, 'Scene 8'), isNull);
      expect(onTapOf(tester, 'Scene 6'), isNotNull);

      await tester.ensureVisible(tile('Scene 7'));
      await tester.tap(tile('Scene 7'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(count(tester, 6), findsOneWidget);
      expect(count(tester, 7), findsNothing);

      // Room again once one is removed; then exactly one more fits.
      await tester.tap(tile('Scene 6'));
      await tester.pumpAndSettle();
      expect(count(tester, 5), findsOneWidget);
      expect(onTapOf(tester, 'Scene 7'), isNotNull);
      await tester.ensureVisible(tile('Scene 7'));
      await tester.tap(tile('Scene 7'));
      await tester.pumpAndSettle();
      expect(count(tester, 6), findsOneWidget);
      expect(onTapOf(tester, 'Scene 8'), isNull);
      await tester.tap(find.text(l10nOf(tester).commonDone));
      await tester.pumpAndSettle();
      expect(state.settings.situationsShownOf('hi'), <String>[
        's1',
        's2',
        's3',
        's4',
        's5',
        's7',
      ]);
    });

    testWidgets('empty places are dashed slots exactly as big as a tile', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(tile('Scene 6'));
      await tester.pumpAndSettle();
      await tester.tap(tile('Scene 5'));
      await tester.pumpAndSettle();
      expect(count(tester, 4), findsOneWidget);
      final slots = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint && '${w.painter.runtimeType}' == '_DashedBorder',
      );
      expect(slots, findsNWidgets(2));
      final tileBox = find
          .ancestor(of: tile('Scene 4'), matching: find.byType(Material))
          .first;
      expect(tester.getSize(slots.first), tester.getSize(tileBox));
      expect(tester.getSize(slots.last), tester.getSize(tileBox));
    });

    testWidgets('a long press reorders only within On Today', (tester) async {
      final state = await open(tester);
      Future<void> drag(String from, String to) async {
        // Both ends on screen, the source last so the target is in view too.
        await tester.ensureVisible(tile(to));
        await tester.ensureVisible(tile(from));
        final a = tester.getCenter(tile(from));
        final b = tester.getCenter(tile(to));
        final gesture = await tester.startGesture(a);
        await tester.pump(const Duration(milliseconds: 700));
        await gesture.moveTo(b, timeStamp: const Duration(milliseconds: 800));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
      }

      // A tile under More cannot be dragged into On Today...
      await drag('Scene 7', 'Scene 2');
      // ...a tile on Today dropped on one under More stays in place...
      await drag('Scene 1', 'Scene 8');
      expect(count(tester, 6), findsOneWidget);
      // Still in the default order: Scene 1 first, in the top row.
      expect(
        tester.getCenter(tile('Scene 1')).dx,
        lessThan(tester.getCenter(tile('Scene 2')).dx),
      );
      // ...while within On Today the same drag does reorder.
      await drag('Scene 1', 'Scene 3');
      await tester.tap(find.text(l10nOf(tester).commonDone));
      await tester.pumpAndSettle();
      expect(state.settings.situationsShownOf('hi'), <String>[
        's2',
        's3',
        's1',
        's4',
        's5',
        's6',
      ]);
    });

    testWidgets('a list stored with more than six keeps the first six on '
        'Today and the rest under More', (tester) async {
      final state = _learner();
      state.settings.setSituationsShown('hi', <String>[
        's8',
        's7',
        's6',
        's5',
        's4',
        's3',
        's2',
      ]);
      await open(tester, state: state);
      expect(count(tester, 6), findsOneWidget);
      expect(onTapOf(tester, 'Scene 2'), isNull);
      await tester.tap(find.text(l10nOf(tester).commonDone));
      await tester.pumpAndSettle();
      expect(state.settings.situationsShownOf('hi'), <String>[
        's8',
        's7',
        's6',
        's5',
        's4',
        's3',
      ]);
    });

    testWidgets('the longest labels fit on Today and in the picker at 1.4x '
        'on 360 dp, between 11 and 13 sp, with no overflow', (tester) async {
      final titles = <String>[
        'Emergency',
        'Doctor and pharmacy',
        'Greetings and apologies',
        'క్షమాపణలు మరియు శుభాకాంక్షలు',
        'अभिवादन और माफ़ी',
        'শুভেচ্ছা ও ক্ষমা',
        'Taxi',
        'Hotel',
      ];
      final state = _learner(titles: titles);
      await _pumpCard(tester, state: state);
      tester.view.physicalSize = const Size(360 * 3, 844 * 3);
      await tester.pumpAndSettle();
      void check(Finder scope, int labels) {
        final fitted = find.descendant(
          of: scope,
          matching: find.byType(FittedLabel),
        );
        expect(fitted, findsNWidgets(labels));
        for (final label in fitted.evaluate()) {
          final text = tester.widget<Text>(
            find.descendant(
              of: find.byWidget(label.widget),
              matching: find.byType(Text),
            ),
          );
          final size = text.style!.fontSize!;
          expect(size, inInclusiveRange(11, 13));
          expect(size, greaterThanOrEqualTo(fittedLabelBaseSize - 2));
          expect(text.maxLines, 3);
        }
      }

      check(find.byType(SituationsCard), 6);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(l10nOf(tester).hintEdit));
      await tester.pumpAndSettle();
      check(find.byType(SituationsEditor), 8);
      expect(tester.takeException(), isNull);
    });
  });

  group('FittedLabel fit order', () {
    // The test font draws every glyph one em wide, so the widths below are
    // exact: a word of n letters is n x size x 1.4 wide at 1.4x text, and
    // each letter adds the letter-spacing (which the scaler does not scale).
    const style = TextStyle(fontWeight: FontWeight.w700, height: 1.2);
    const scaler = TextScaler.linear(1.4);

    LabelFit fit(String text, double width) => fitLabel(
      text: text,
      style: style,
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxWidth: width,
    );

    test('wraps first: long labels keep 13 sp and no tightening while their '
        'words fit', () {
      for (final (text, width) in <(String, double)>[
        ('Doctor and pharmacy', 150),
        ('Greetings and apologies', 170),
      ]) {
        final result = fit(text, width);
        expect(result.fontSize, 13, reason: text);
        expect(result.letterSpacing, 0, reason: text);
      }
    });

    test('a word wider than the tile tightens first, then shrinks, and '
        'never by more than 2 sp', () {
      // "Emergency" is 9 letters: 163.8 wide at 13 sp, too wide for 153;
      // tightening alone gives 161.5, so it shrinks to 12 sp.
      final shrunk = fit('Emergency', 153);
      expect(shrunk.fontSize, 12);
      expect(shrunk.letterSpacing, closeTo(-0.02 * 12, 1e-9));
      // Tightening alone is enough here, so the size stays 13.
      final tightened = fit('Emergency', 162);
      expect(tightened.fontSize, 13);
      expect(tightened.letterSpacing, closeTo(-0.02 * 13, 1e-9));
      // Too narrow for any step: the floor, 2 sp below the base.
      final floor = fit('Emergency', 100);
      expect(floor.fontSize, fittedLabelMinSize);
      expect(floor.fontSize, fittedLabelBaseSize - 2);
      expect(floor.letterSpacing, closeTo(-0.02 * 11, 1e-9));
    });

    test('the order holds at every width, and a word is never broken '
        'unless nothing fits', () {
      const labels = <String>[
        'Emergency',
        'Doctor and pharmacy',
        'Greetings and apologies',
        'క్షమాపణలు మరియు శుభాకాంక్షలు',
        'अभिवादन और माफ़ी',
        'শুভেচ্ছা ও ক্ষমা',
      ];
      for (final text in labels) {
        for (var width = 40.0; width <= 320; width += 4) {
          final r = fit(text, width);
          String reason() => '$text at $width: $r';
          expect(r.fontSize, inInclusiveRange(11, 13), reason: reason());
          // Tightening comes before shrinking, never the other way round.
          if (r.letterSpacing == 0) {
            expect(r.fontSize, 13, reason: reason());
          } else {
            expect(
              r.letterSpacing,
              closeTo(-0.02 * r.fontSize, 1e-9),
              reason: reason(),
            );
          }
          // Above the floor, every word fits on a line of its own.
          if (r.fontSize > fittedLabelMinSize) {
            for (final word in text.split(' ')) {
              final painter = TextPainter(
                text: TextSpan(
                  text: word,
                  style: style.copyWith(
                    fontSize: r.fontSize,
                    letterSpacing: r.letterSpacing,
                  ),
                ),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
              )..layout();
              expect(painter.width, lessThanOrEqualTo(width + 0.01));
              painter.dispose();
            }
          }
        }
      }
    });
  });

  test('the choice survives a backup, per language, and a language\'s '
      'settings reset forgets it', () {
    final settings = SettingsNotifier()
      ..setSituationsShown('hi', <String>['s2', 's1']);
    final stored = settings.toStored();
    final back = SettingsNotifier()..restore(stored);
    expect(back.situationsShownOf('hi'), <String>['s2', 's1']);
    expect(back.situationsShownOf('bn'), isNull);
    back.clearLanguageSettings('hi');
    expect(back.situationsShownOf('hi'), isNull);
  });

  test('a situation a deck update adds never joins a chosen list, and an id '
      'the file no longer writes is left out', () async {
    final state = _learner();
    await state.load();
    state.settings.setSituationsShown('hi', <String>['s8', 'gone', 's2']);
    expect(
      <String>[for (final s in state.pickedSituations('hi')) s.id],
      <String>['s8', 's2'],
    );
  });

  test('a pick whose ids are all gone, or an empty restored pick, leaves '
      'the default six', () async {
    final state = _learner();
    await state.load();
    state.settings.setSituationsShown('hi', <String>['gone', 'also-gone']);
    expect(
      <String>[for (final s in state.pickedSituations('hi')) s.id],
      <String>['s1', 's2', 's3', 's4', 's5', 's6'],
    );
    final restored = SettingsNotifier()
      ..restore(<String, String>{'situations_shown': '{"hi":[]}'});
    expect(restored.situationsShownOf('hi'), isNull);
  });
}
