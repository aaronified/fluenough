import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/ui/widgets/bottom_actions.dart';

import '../support/harness.dart';

void main() {
  testWidgets('BottomActions keeps its button above the three-button bar '
      '(#501)', (tester) async {
    usePhone(tester, navBar: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: BottomActions(
            child: FilledButton(onPressed: () {}, child: const Text('Go')),
          ),
        ),
      ),
    );
    final button = find.byType(FilledButton);
    expect(
      tester.getBottomLeft(button).dy,
      lessThanOrEqualTo(844 - navBarHeight),
    );
  });
}
