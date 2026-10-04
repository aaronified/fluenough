import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/gallery/gallery_entry.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:fluenough/features/settings/gallery_entries.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/voices_page.dart';

import '../../support/harness.dart';
import 'support.dart';

/// Every screen, in this version and with every feature on.
final Map<String, (Widget, AppState Function(AppState))> screens =
    <String, (Widget, AppState Function(AppState))>{
      'Settings': (const SettingsPage(), GalleryFixtures.state),
      'Settings, all on': (
        const SettingsPage(),
        (app) => GalleryFixtures.state(
          app,
          features: FeatureRegistry.all(),
          settings: SettingsNotifier(reminder: true),
        ),
      ),
      'Appearance': (const AppearancePage(), GalleryFixtures.state),
      'Appearance, all on': (
        const AppearancePage(),
        (app) => GalleryFixtures.state(app, features: FeatureRegistry.all()),
      ),
      'Voices': (const VoicesPage(), GalleryFixtures.state),
      'Voices, all installed': (
        const VoicesPage(),
        (app) => AppState.test(tts: FixedTtsEngine(const <String>{'es', 'hi'})),
      ),
    };

void main() {
  for (final MapEntry(key: name, value: (page, make)) in screens.entries) {
    for (final dark in <bool>[false, true]) {
      testWidgets('$name at text scale 2.0${dark ? ', dark' : ''}', (
        tester,
      ) async {
        usePhone(tester, textScale: 2.0);
        final app = AppState.test();
        await app.load();
        await pumpScreen(
          tester,
          page,
          state: make(app),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  // Every gallery entry and extra state, as Phase 2 will list them.
  final entries = <GalleryEntry>[
    ...settingsGalleryEntries,
    ...settingsGalleryStates,
  ];
  for (final entry in entries) {
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('gallery ${entry.id} at $scale, light and dark', (
        tester,
      ) async {
        usePhone(tester, textScale: scale);
        final app = AppState.test();
        await app.load();
        for (final dark in <bool>[false, true]) {
          await pumpScreen(
            tester,
            GalleryPreview(key: UniqueKey(), entry: entry, dark: dark),
            state: app,
          );
          expect(tester.takeException(), isNull, reason: 'dark: $dark');
          await scrollThrough(tester);
        }
      });
    }
  }
}
