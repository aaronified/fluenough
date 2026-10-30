import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/ui/theme.dart';
import 'package:fluenough/ui/widgets/hint.dart';

/// A control without text of its own shows a small hint on a long press
/// (#913): the themed [Tooltip], through [Hint] or an `IconButton`'s
/// `tooltip:`. The scans below keep a new control from skipping it.
void main() {
  /// The source of the call that opens at [open] in [source], through its
  /// matching parenthesis. Parentheses inside strings are not special-cased:
  /// close enough for a scan, and a miscount fails loudly, not silently.
  String call(String source, int open) {
    var depth = 0;
    for (var i = open; i < source.length; i++) {
      if (source[i] == '(') depth++;
      if (source[i] == ')' && --depth == 0) return source.substring(open, i);
    }
    return source.substring(open);
  }

  Iterable<(String, String)> libSources() sync* {
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      yield (file.path, file.readAsStringSync());
    }
  }

  test('every IconButton has a tooltip', () {
    // The rule: an `IconButton(`, `.outlined(`, `.filled(` or
    // `.filledTonal(` call in lib/ names `tooltip:`. (`IconButton.styleFrom`
    // is a style, not a button.)
    final constructor = RegExp(
      r'\bIconButton(\.(outlined|filled|filledTonal))?\(',
    );
    final missing = <String>[];
    for (final (path, source) in libSources()) {
      for (final m in constructor.allMatches(source)) {
        if (!call(source, m.end - 1).contains('tooltip:')) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          missing.add('$path:$line');
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'IconButton without tooltip: (use a short hint, #913)',
    );
  });

  test('an icon-only tap target carries a hint', () {
    // The rule: an `InkWell(`, `InkResponse(` or `GestureDetector(` whose
    // call holds an `Icon(` must live in a file that uses `Hint(`,
    // `Tooltip(` or `tooltip:`, unless it is listed below or marked
    // `// hint-ok: shows text` on the line above, because it also shows text. A call that shows text opts out with a `// hint-ok:`
    // comment on the line above it. (A file-level check: coarse on purpose, so a new
    // icon-only control in a file with no hint at all cannot slip by.)
    // Icon-only pills are covered by ModePill, which wraps its icon-only
    // sizes in a Hint itself (checked below).
    const showsText = <String>{
      'lib/features/drill/choice_tile.dart',
      'lib/features/decks/deck_search_bar.dart',
      'lib/features/settings/settings_page.dart',
    };
    final target = RegExp(r'\b(InkWell|InkResponse|GestureDetector)\(');
    final missing = <String>[];
    for (final (path, source) in libSources()) {
      if (showsText.contains(path)) continue;
      final hinted =
          source.contains('Hint(') ||
          source.contains('Tooltip(') ||
          source.contains('tooltip:');
      if (hinted) continue;
      for (final m in target.allMatches(source)) {
        final body = call(source, m.end - 1);
        final above = source.substring(0, m.start).split('\n');
        if (above.length > 1 &&
            above[above.length - 2].contains('// hint-ok:')) {
          continue;
        }
        if (body.contains('Icon(') || body.contains('Icons.')) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          missing.add('$path:$line');
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'icon-only control without a Hint (#913); wrap it in Hint',
    );
    final pill = File('lib/ui/widgets/mode_pill.dart').readAsStringSync();
    expect(pill, contains('Hint('), reason: 'icon-only pills show a hint');
  });

  test('hint texts are one short line with no full stop', () {
    final arb = File('lib/l10n/app_en.arb').readAsStringSync();
    final hints = RegExp(r'"(hint[A-Z]\w*)": "([^"]*)"').allMatches(arb);
    expect(hints, isNotEmpty);
    for (final m in hints) {
      final text = m.group(2)!;
      expect(text.endsWith('.'), isFalse, reason: m.group(1));
      expect(text.split(' ').length, lessThanOrEqualTo(3), reason: m.group(1));
    }
  });

  for (final (name, theme) in <(String, ThemeData)>[
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('a long press shows the hint, $name, at 1.4x text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: const Hint(
                message: 'Speak',
                child: InkWell(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.mic),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Speak'), findsNothing);
      await tester.longPress(find.byIcon(Icons.mic));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Speak'), findsOneWidget);
      final box = tester.getSize(find.text('Speak'));
      expect(box.height, lessThan(40), reason: 'one compact line');
    });
  }
}
