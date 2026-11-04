import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/web_frame.dart';

/// The padding a screen reads under the frame, in a window of [window] with
/// a notch and home bar of [insets].
Future<EdgeInsets> _padding(
  WidgetTester tester,
  Size window,
  EdgeInsets insets,
) async {
  tester.view
    ..physicalSize = window
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late EdgeInsets seen;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => webPhoneFrameWith(context, child, insets),
      home: Builder(
        builder: (context) {
          seen = MediaQuery.paddingOf(context);
          return const SizedBox.expand();
        },
      ),
    ),
  );
  return seen;
}

void main() {
  const notch = EdgeInsets.fromLTRB(10, 47, 20, 34);

  testWidgets('a phone-sized window gives the screens the notch and bar', (
    tester,
  ) async {
    expect(await _padding(tester, const Size(390, 844), notch), notch);
  });

  testWidgets('a SafeArea under the frame keeps clear of them', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const key = Key('inside');
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => webPhoneFrameWith(context, child, notch),
        home: const SafeArea(child: SizedBox.expand(key: key)),
      ),
    );
    expect(
      tester.getRect(find.byKey(key)),
      const Rect.fromLTRB(10, 47, 370, 810),
    );
  });

  testWidgets('in a wide window only top and bottom apply: the sides are '
      'the frame\'s own margin', (tester) async {
    final got = await _padding(tester, const Size(1600, 900), notch);
    expect(got, const EdgeInsets.only(top: 47, bottom: 34));
  });

  testWidgets('with no notch the screens read no padding', (tester) async {
    expect(
      await _padding(tester, const Size(390, 844), EdgeInsets.zero),
      EdgeInsets.zero,
    );
  });
}
