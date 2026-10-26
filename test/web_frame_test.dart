import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/web_frame.dart';

/// The size a screen under [webPhoneFrame] reads, in a window of [window].
Future<({Size seen, Size drawn})> _under(
  WidgetTester tester,
  Size window,
) async {
  tester.view
    ..physicalSize = window
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late Size seen;
  const key = Key('screen');
  await tester.pumpWidget(
    MaterialApp(
      builder: webPhoneFrame,
      home: Builder(
        builder: (context) {
          seen = MediaQuery.sizeOf(context);
          return const SizedBox.expand(key: key);
        },
      ),
    ),
  );
  return (seen: seen, drawn: tester.getSize(find.byKey(key)));
}

void main() {
  testWidgets('a wide window gets a phone-wide column, not the whole screen', (
    tester,
  ) async {
    final got = await _under(tester, const Size(1600, 900));
    expect(got.drawn, const Size(webFrameMaxWidth, 900));
    expect(got.seen, got.drawn, reason: 'screens lay out by the frame');
  });

  testWidgets('a short, wide window keeps a 9:16 shape', (tester) async {
    final got = await _under(tester, const Size(1600, 640));
    expect(got.drawn, const Size(360, 640));
  });

  testWidgets('a phone-sized window is drawn whole', (tester) async {
    final got = await _under(tester, const Size(390, 844));
    expect(got.drawn, const Size(390, 844));
    expect(got.seen, got.drawn);
  });
}
