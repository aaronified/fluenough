// Haptics (Plan-Haptics): what a learner feels, in meaning. The service
// obeys the setting, the screen reader and the throttle; the system engine is
// the one table of feels; the Vibrate on touch row, the pills, a verdict and
// the rest say the right thing; and nothing but the engine calls
// `HapticFeedback`.

import 'dart:io';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/haptics.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/wallpaper_colours.dart';
import 'package:fluenough/core/data/course_path.dart' show Milestone;
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/haptics/haptic.dart';
import 'package:fluenough/core/haptics/system_haptic_engine.dart';
import 'package:fluenough/core/languages/language_skills.dart';
import 'package:fluenough/features/languages/language_skills_sheet.dart';
import 'package:fluenough/features/languages/language_views.dart';
import 'package:fluenough/features/settings/appearance_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/picker.dart';
import 'support/recording_haptic_engine.dart';

/// A [Haptics] on a recording engine and a clock the test moves.
({Haptics haptics, RecordingHapticEngine engine, void Function(int ms) wait})
service({bool Function()? enabled}) {
  final engine = RecordingHapticEngine();
  var now = DateTime(2026, 11, 6);
  return (
    haptics: Haptics(
      engine: engine,
      enabled: enabled ?? () => true,
      clock: () => now,
    ),
    engine: engine,
    wait: (ms) => now = now.add(Duration(milliseconds: ms)),
  );
}

void main() {
  group('the service', () {
    test('plays nothing while Vibrate on touch is off', () {
      final s = service(enabled: () => false);
      s.haptics
        ..tap()
        ..confirm()
        ..danger()
        ..success()
        ..error()
        ..pill(SkillMark.know);
      expect(s.engine.played, isEmpty);
    });

    test('a burst inside 50 ms plays once, and a call after it plays', () {
      final s = service();
      s.haptics.select();
      s.wait(20);
      s.haptics.select();
      s.wait(20);
      s.haptics.select();
      expect(s.engine.played, <Haptic>[Haptic.select]);
      s.wait(60);
      s.haptics.select();
      expect(s.engine.played, <Haptic>[Haptic.select, Haptic.select]);
    });

    test('a double is not interrupted while it plays', () {
      final s = service();
      s.haptics.error();
      s.wait(100);
      s.haptics.tap();
      expect(s.engine.played, <Haptic>[Haptic.error]);
      s.wait(150);
      s.haptics.tap();
      expect(s.engine.played, <Haptic>[Haptic.error, Haptic.tap]);
    });

    test(
      'with a screen reader on, touches are left to it and meanings stay',
      () {
        final s = service();
        s.haptics.screenReader = true;
        for (final silent in <void Function()>[
          s.haptics.tap,
          s.haptics.select,
          s.haptics.confirm,
          () => s.haptics.toggle(true),
          () => s.haptics.toggle(false),
        ]) {
          silent();
          s.wait(300);
        }
        expect(s.engine.played, isEmpty);
        for (final kept in <void Function()>[
          s.haptics.success,
          s.haptics.error,
          s.haptics.danger,
          s.haptics.correct,
          s.haptics.wrong,
          () => s.haptics.pill(SkillMark.learn),
        ]) {
          kept();
          s.wait(300);
        }
        expect(s.engine.played, hasLength(6));
      },
    );

    test('a pill feels the mark it now draws: Learnt is the rise', () {
      final s = service();
      final felt = <Haptic>[];
      for (final mark in SkillMark.values) {
        s.haptics.pill(mark);
        felt.add(s.engine.played.last);
        s.wait(300);
      }
      expect(felt, <Haptic>[
        Haptic.pillLeave,
        Haptic.pillKnow,
        Haptic.pillLearnt,
        Haptic.pillKnow,
        Haptic.pillLearnt,
        Haptic.pillLearn,
      ]);
    });
  });

  group('the system engine', () {
    final calls = <(String, Object?)>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add((call.method, call.arguments));
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    List<String> felt() => <String>[
      for (final (method, arg) in calls)
        arg is String ? arg.replaceFirst('HapticFeedbackType.', '') : method,
    ];

    testWidgets('gives each action its feel', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const engine = SystemHapticEngine();
      final table = <Haptic, List<String>>{
        Haptic.select: <String>['selectionClick'],
        Haptic.pillLeave: <String>['selectionClick'],
        Haptic.tap: <String>['lightImpact'],
        Haptic.pillLearn: <String>['lightImpact'],
        Haptic.toggleOff: <String>['lightImpact'],
        Haptic.confirm: <String>['mediumImpact'],
        Haptic.toggleOn: <String>['mediumImpact'],
        Haptic.pillKnow: <String>['mediumImpact'],
        Haptic.danger: <String>['heavyImpact'],
        Haptic.longPress: <String>['HapticFeedback.vibrate'],
        Haptic.success: <String>['lightImpact', 'mediumImpact'],
        Haptic.pillLearnt: <String>['lightImpact', 'mediumImpact'],
        Haptic.error: <String>['mediumImpact', 'mediumImpact'],
        Haptic.wrong: <String>['mediumImpact', 'mediumImpact'],
        Haptic.none: <String>[],
      };
      for (final entry in table.entries) {
        calls.clear();
        engine.play(entry.key);
        await tester.pump(const Duration(milliseconds: 300));
        expect(felt(), entry.value, reason: '${entry.key}');
      }
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('drops the second pulse of a double when switched off', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var on = true;
      const SystemHapticEngine().play(Haptic.success, stillOn: () => on);
      on = false;
      await tester.pump(const Duration(milliseconds: 300));
      expect(felt(), <String>['lightImpact']);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('is not available, and silent, on the web and desktop', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(const SystemHapticEngine().available, isFalse);
      const SystemHapticEngine().play(Haptic.danger);
      expect(calls, isEmpty);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(const SystemHapticEngine().available, isTrue);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('the setting', () {
    test(
      'is on by default, saved, restored, and an old backup keeps it on',
      () {
        expect(SettingsNotifier().haptics, isTrue);
        final off = SettingsNotifier()..haptics = false;
        expect(off.toStored()['haptics'], 'false');
        expect((SettingsNotifier()..restore(off.toStored())).haptics, isFalse);
        // A backup from before it existed has no key: the stored values go over
        // the defaults, as Backups.restore does.
        final live = SettingsNotifier()..haptics = false;
        live.restore(<String, String>{
          ...SettingsNotifier().toStored(),
          'seed': 'clay',
        });
        expect(live.haptics, isTrue);
      },
    );
  });

  group('the Vibrate on touch row', () {
    testWidgets('is not drawn where the phone cannot vibrate', (tester) async {
      usePhone(tester);
      await pumpScreen(tester, const AppearancePage());
      expect(find.text(l10nOf(tester).appearanceHaptics), findsNothing);
    });

    testWidgets('turning it off is silent, turning it on is pressed, and '
        'the line says what happens now', (tester) async {
      usePhone(tester);
      final engine = RecordingHapticEngine();
      final state = AppState.test(hapticEngine: engine);
      await pumpScreen(tester, const AppearancePage(), state: state);
      final l10n = l10nOf(tester);
      final row = find.text(l10n.appearanceHaptics);
      await scrollToFind(tester, row);
      expect(find.text(l10n.appearanceHapticsOn), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(state.settings.haptics, isFalse);
      expect(find.text(l10n.appearanceHapticsOff), findsOneWidget);
      expect(engine.played, isEmpty, reason: 'the switch is off already');

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(state.settings.haptics, isTrue);
      expect(find.text(l10n.appearanceHapticsOn), findsOneWidget);
      expect(engine.played, <Haptic>[Haptic.toggleOn]);
    });

    testWidgets('and the Colour help line fit at 1.4x text, light and dark; '
        'a dimmed Colour is not read as choices', (tester) async {
      final handle = tester.ensureSemantics();
      for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
        usePhone(tester, textScale: 1.4);
        final state = AppState.test(
          hapticEngine: RecordingHapticEngine(),
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningChosen: true,
            dynamicColour: true,
          ),
          wallpaperSource: FixedWallpaperSource(const Color(0xFFE91E63)),
        );
        await state.wallpaper.refresh();
        await pumpScreen(
          tester,
          const AppearancePage(),
          state: state,
          themeMode: mode,
        );
        final l10n = l10nOf(tester);
        final help = find.text(l10n.appearanceColourFollowing);
        final forest = find.text(l10n.appearanceSeedForest);
        await scrollToFind(tester, forest);
        await tester.ensureVisible(forest);
        await tester.pumpAndSettle();
        // The swatches are drawn dimmed and say nothing to a screen reader.
        expect(find.bySemanticsLabel(l10n.appearanceSeedForest), findsNothing);
        await scrollToFind(tester, help);
        expect(help, findsOneWidget);
        final box = tester.getRect(help);
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(390));
        await scrollToFind(tester, find.text(l10n.appearanceHaptics));
        expect(find.text(l10n.appearanceHaptics), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Wallpaper colours off: the choices are back, and read as choices.
        state.settings.dynamicColour = false;
        await tester.pumpAndSettle();
        await scrollToFind(tester, forest);
        await tester.ensureVisible(forest);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(l10n.appearanceSeedForest), findsWidgets);
      }
      handle.dispose();
    });
  });

  group('a skill pill', () {
    testWidgets('feels the rung it lands on: Know twice at the top', (
      tester,
    ) async {
      final es = pickerSpokenList.firstWhere((l) => l.code == 'es');
      final course = CatalogLanguage(
        code: 'es',
        name: 'Spanish',
        natives: <CatalogNative>[
          (
            code: 'en',
            name: 'English',
            progress: B1Progress.of(<B1Unit>[
              const B1Unit(words: 10, milestone: Milestone.a1, has: 10),
            ]),
          ),
        ],
      );
      final engine = RecordingHapticEngine();
      usePhone(tester);
      await pumpScreen(
        tester,
        Scaffold(
          body: LanguageSkillsSheet(
            view: LanguageView(es, course),
            initial: LanguageSkills(),
          ),
        ),
        state: AppState.test(
          hapticEngine: engine,
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningChosen: true,
          ),
        ),
      );
      final pill = find.byKey(const ValueKey<String>('skill-spoken'));
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(pill);
        await tester.tap(pill);
        await tester.pumpAndSettle();
      }
      // Leave, Learn, Hear, Hear and Speak: the last two are both Know.
      expect(engine.played, <Haptic>[
        Haptic.pillLearn,
        Haptic.pillKnow,
        Haptic.pillKnow,
      ]);
    });
  });

  group('the rule', () {
    test('only the system engine calls HapticFeedback or Feedback', () {
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('core/haptics/system_haptic_engine.dart')) {
          continue;
        }
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          if (line.startsWith('//')) continue;
          if (line.contains('HapticFeedback.') ||
              RegExp(r'\bFeedback\.for').hasMatch(line)) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'use AppScope.read(c).haptics');
    });
  });
}
