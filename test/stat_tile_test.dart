// A number tile's one-word label stays whole at the app's 1.4x text cap.

import 'package:fluenough/ui/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a long one-word label is not broken mid-word at 1.4x', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 110,
                child: StatTile(
                  value: '87%',
                  label: 'Remembered',
                  variant: StatTileVariant.large,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final label = tester.renderObject<RenderParagraph>(find.text('Remembered'));
    // One line: a mid-word break would make the paragraph two lines tall.
    expect(label.size.height, lessThan(label.text.style!.fontSize! * 1.4 * 2));
    expect(tester.takeException(), isNull);
  });
}
