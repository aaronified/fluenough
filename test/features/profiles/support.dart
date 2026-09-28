import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/profiles/gallery_entries.dart';

import '../../support/harness.dart';

/// Pumps [page] on a phone, on the design's Aro (PIN 1234) and Mira, with
/// profiles and PIN lock on, or as this version ships them when [flagsOn]
/// is false.
Future<AppState> pumpProfiles(
  WidgetTester tester,
  Widget page, {
  bool flagsOn = true,
  String currentProfileId = 'aro',
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  usePhone(tester, textScale: textScale);
  final app = AppState.test();
  await app.load();
  return pumpScreen(
    tester,
    page,
    state: flagsOn
        ? profilesOn(app, currentProfileId: currentProfileId)
        : GalleryFixtures.state(app, currentProfileId: currentProfileId),
    themeMode: themeMode,
  );
}

/// The name a loaded deck gives the language with BCP-47 [code].
String languageName(AppState state, String code) =>
    state.languages.firstWhere((l) => l.code == code).name;

/// Scrolls the page's outer list from top to bottom, failing on any
/// exception on the way, such as an overflow in a part built off screen.
Future<void> scrollThrough(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 30; i++) {
    expect(tester.takeException(), isNull);
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent) return;
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}
