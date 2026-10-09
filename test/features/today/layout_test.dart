import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/gallery/gallery_entry.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/features/today/gallery_entries.dart';
import 'package:fluenough/features/today/today_fixtures.dart';
import 'package:fluenough/features/today/today_page.dart';

import '../../support/harness.dart';

/// Every state Today draws, built on a loaded app.
final Map<String, Future<AppState> Function()> states =
    <String, Future<AppState> Function()>{
      'first day, no voice': () async => AppState.test(),
      'with voices': () async =>
          AppState.test(tts: FixedTtsEngine(const <String>{'es', 'hi'})),
      'mid-streak': () async => GalleryFixtures.state(await _loaded()),
      'adjusted to you': () async =>
          GalleryFixtures.adjusted(GalleryFixtures.state(await _loaded())),
      'all done': () async {
        final state = GalleryFixtures.state(await _loaded());
        await state.load();
        finishToday(state);
        return state;
      },
      'no voice, Mira': () async => todayNoVoiceState(await _loaded()),
      'no decks': () async => AppState.test(
        profiles: const <Profile>[
          Profile(id: 'fr', name: 'Fr', languages: <String>{'fr'}),
        ],
      ),
    };

Future<AppState> _loaded() async {
  final app = AppState.test();
  await app.load();
  return app;
}

void main() {
  for (final MapEntry(key: name, value: make) in states.entries) {
    for (final dark in <bool>[false, true]) {
      testWidgets('Today, $name, at text scale 2.0${dark ? ', dark' : ''}', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        await pumpScreen(
          tester,
          const TodayPage(),
          state: await make(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(TodayPage), findsOneWidget);
      });
    }
  }

  testWidgets('the gallery\'s Today states build, light and dark', (
    tester,
  ) async {
    usePhone(tester);
    final app = await _loaded();
    for (final GalleryEntry entry in todayGalleryStates) {
      for (final dark in <bool>[false, true]) {
        await pumpScreen(
          tester,
          GalleryPreview(key: UniqueKey(), entry: entry, dark: dark),
          state: app,
        );
        expect(tester.takeException(), isNull, reason: '${entry.id} $dark');
      }
    }
  });

  testWidgets('the gallery\'s all-done state is all done', (tester) async {
    usePhone(tester);
    final app = await _loaded();
    final entry = todayGalleryStates.firstWhere(
      (e) => e.id == 'today-all-done',
    );
    await pumpScreen(tester, GalleryPreview(entry: entry), state: app);
    expect(find.text(l10nOf(tester).todayAllDoneTitle), findsOneWidget);
  });
}
