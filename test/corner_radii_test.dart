import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/ui/theme.dart';

/// The corner radii are one scale with a token per role (#878): the themed
/// components take their role's token, and no widget writes a number.
void main() {
  final themes = <String, ThemeData>{
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  };

  Future<void> pump(WidgetTester tester, ThemeData theme, Widget child) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: Center(child: child)),
        ),
      );

  /// The shape of the first [Material] under [of].
  ShapeBorder shapeUnder(WidgetTester tester, Finder of) {
    final material = tester.widget<Material>(
      find.descendant(of: of, matching: find.byType(Material)).first,
    );
    return material.shape!;
  }

  void expectRadius(ShapeBorder shape, double radius) {
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(radius),
    );
  }

  for (final MapEntry(key: mode, value: theme) in themes.entries) {
    group('$mode theme', () {
      testWidgets('every button type is a stadium', (tester) async {
        await pump(
          tester,
          theme,
          Column(
            children: <Widget>[
              FilledButton(onPressed: () {}, child: const Text('a')),
              FilledButton.tonal(onPressed: () {}, child: const Text('b')),
              OutlinedButton(onPressed: () {}, child: const Text('c')),
              TextButton(onPressed: () {}, child: const Text('d')),
              ElevatedButton(onPressed: () {}, child: const Text('e')),
            ],
          ),
        );
        for (final type in <Type>[
          FilledButton,
          OutlinedButton,
          TextButton,
          ElevatedButton,
        ]) {
          expect(
            shapeUnder(tester, find.byType(type).first),
            isA<StadiumBorder>(),
            reason: '$type',
          );
        }
        expect(
          shapeUnder(tester, find.widgetWithText(FilledButton, 'b')),
          isA<StadiumBorder>(),
        );
      });

      testWidgets('a chip takes the chip radius', (tester) async {
        await pump(tester, theme, const Chip(label: Text('chip')));
        expectRadius(shapeUnder(tester, find.byType(Chip)), AppRadii.chip);
      });

      testWidgets('a text field takes the field radius', (tester) async {
        await pump(
          tester,
          theme,
          const SizedBox(width: 300, child: TextField()),
        );
        final border = tester
            .widget<InputDecorator>(find.byType(InputDecorator))
            .decoration
            .border;
        expect(border, isA<OutlineInputBorder>());
        expect(
          (border! as OutlineInputBorder).borderRadius,
          BorderRadius.circular(AppRadii.field),
        );
        expect(AppRadii.fieldBorder.borderRadius, AppRadii.fieldRadius);
      });

      testWidgets('a card takes the card radius', (tester) async {
        await pump(tester, theme, const Card(child: Text('card')));
        expectRadius(shapeUnder(tester, find.byType(Card)), AppRadii.card);
      });

      testWidgets('a list tile takes the control radius', (tester) async {
        await pump(
          tester,
          theme,
          const SizedBox(width: 300, child: ListTile(title: Text('tile'))),
        );
        final tile = tester.widget<ListTile>(find.byType(ListTile));
        expectRadius(
          tile.shape ?? theme.listTileTheme.shape!,
          AppRadii.control,
        );
      });

      testWidgets('a dialog takes the dialog radius', (tester) async {
        await pump(
          tester,
          theme,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('dialog')),
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expectRadius(shapeUnder(tester, find.byType(Dialog)), AppRadii.dialog);
      });

      testWidgets('a bottom sheet rounds its top by the sheet radius', (
        tester,
      ) async {
        await pump(
          tester,
          theme,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(height: 100),
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final shape = shapeUnder(tester, find.byType(BottomSheet));
        expect(shape, isA<RoundedRectangleBorder>());
        expect(
          (shape as RoundedRectangleBorder).borderRadius,
          const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
        );
      });

      testWidgets('a snack bar takes the field radius', (tester) async {
        await pump(
          tester,
          theme,
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('snack'))),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expectRadius(shapeUnder(tester, find.byType(SnackBar)), AppRadii.field);
      });
    });
  }

  test('no widget writes a numeric radius', () {
    // A radius is a role's token from AppRadii. One that follows a size
    // (`size * 0.32`, `thickness / 2`) is a formula, not a number, and is
    // allowed; so is the token list in theme.dart (its values are doubles).
    final literal = RegExp(
      r'(?:BorderRadius(?:Directional)?\.circular|Radius\.circular)\(\s*\d',
    );
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (literal.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'use an AppRadii token (lib/ui/theme.dart) for the role',
    );
  });
}
