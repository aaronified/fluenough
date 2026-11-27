// The home-screen widget's service (#108) with a fake gateway: nothing runs
// where the build has no widget, progress is stored once after it has been
// quiet, leaving the app stores at once, a failure goes to the log and never
// throws, and the widget is real data from the app's own numbers.

import 'dart:async';
import 'dart:ui' show Locale;

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/home_widget_gateway.dart';
import 'package:fluenough/app/home_widget_service.dart';
import 'package:fluenough/app/home_widget_words.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/widget/home_widget_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_home_widget_gateway.dart';

/// A timer a test fires by hand.
class _HandTimer implements Timer {
  _HandTimer(this.run);

  final void Function() run;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    if (cancelled || fired) return;
    fired = true;
    run();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;
}

String _deck(String code, String name, String iso, int from, int count) =>
    '''
schema: 1
id: $code-en-words
name: "$code words"
language: { code: $code, iso639_3: $iso, name: $name, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
${[for (var i = 0; i < count; i++) '  - { id: $code-${from + i}, target: "w$i", native: "n$i" }'].join('\n')}
''';

void main() {
  late FakeHomeWidgetGateway gateway;
  late List<_HandTimer> timers;
  late List<String> logged;
  late int numbers;
  var featureOn = true;
  final now = DateTime(2026, 11, 5, 19, 30);

  HomeWidgetService build() => HomeWidgetService(
    gateway: gateway,
    available: () => featureOn,
    summary: () => HomeWidgetSummary(
      language: 'Telugu',
      day: now,
      dueToday: numbers,
      dueNext: numbers + 3,
      streak: 4,
      practisedToday: true,
    ),
    texts: () => homeWidgetTextsFor(const Locale('en')),
    clock: () => now,
    timer: (after, run) {
      final timer = _HandTimer(run);
      timers.add(timer);
      return timer;
    },
    log: logged.add,
  );

  setUp(() {
    gateway = FakeHomeWidgetGateway();
    timers = <_HandTimer>[];
    logged = <String>[];
    numbers = 12;
    featureOn = true;
  });

  test(
    'stores the text, draws the widget and sets the day-turn redraws',
    () async {
      final service = build();
      await service.flush();

      expect(gateway.stored[HomeWidgetKeys.dueToday], '12 due');
      expect(gateway.stored[HomeWidgetKeys.dueNext], '15 due');
      expect(gateway.stored[HomeWidgetKeys.streakToday], '4 day streak');
      expect(gateway.stored[HomeWidgetKeys.language], 'Telugu');
      expect(gateway.redraws, 1);
      expect(gateway.scheduled, <DateTime>[
        DateTime(2026, 11, 6, 0, 1),
        DateTime(2026, 11, 7, 0, 1),
      ]);
      expect(logged, isEmpty);
    },
  );

  test('says all done when nothing is due', () async {
    numbers = 0;
    await build().flush();
    expect(gateway.stored[HomeWidgetKeys.dueToday], 'All done for today');
    expect(gateway.stored[HomeWidgetKeys.dueNext], '3 due');
  });

  group('where there is no widget', () {
    test('a build without one stores nothing and reads no numbers', () async {
      gateway = FakeHomeWidgetGateway(supported: false);
      var read = 0;
      final service = HomeWidgetService(
        gateway: gateway,
        available: () => true,
        summary: () {
          read++;
          return null;
        },
        texts: () => homeWidgetTextsFor(const Locale('en')),
        timer: (after, run) {
          final timer = _HandTimer(run);
          timers.add(timer);
          return timer;
        },
      );
      service.changed();
      await service.flush();
      expect(service.active, isFalse);
      expect(timers, isEmpty, reason: 'no timer is started');
      expect(read, 0, reason: 'no progress is counted');
      expect(gateway.saves, 0);
    });

    test('the null gateway, used on the web and iOS, is not supported', () {
      expect(const NullHomeWidgetGateway().supported, isFalse);
    });

    test('a feature that is off stores nothing', () async {
      featureOn = false;
      final service = build();
      service.changed();
      await service.flush();
      expect(timers, isEmpty);
      expect(gateway.saves, 0);
    });

    test('the web build does not have the feature', () {
      expect(
        const FeatureRegistry.web().isAvailable(Feature.homeWidget),
        isFalse,
      );
      expect(
        const FeatureRegistry.shipped().isAvailable(Feature.homeWidget),
        isTrue,
      );
    });
  });

  group('debounce', () {
    test('a burst of changes stores once, after the last', () async {
      final service = build();
      service.changed();
      service.changed();
      service.changed();
      expect(gateway.saves, 0, reason: 'nothing is stored while answering');
      expect(timers.length, 3);
      expect(timers.where((t) => t.isActive), hasLength(1));
      expect(timers.last.isActive, isTrue, reason: 'the last change counts');

      timers.last.fire();
      await pumpEventQueue();
      expect(gateway.saves, 1);
      expect(gateway.redraws, 1);
    });

    test('leaving the app stores at once and drops the wait', () async {
      final service = build();
      service.changed();
      await service.flush();
      expect(gateway.saves, 1);
      expect(timers.single.cancelled, isTrue);
      timers.single.fire();
      await pumpEventQueue();
      expect(gateway.saves, 1, reason: 'the cancelled wait does not store');
    });

    test('a disposed service stores nothing', () async {
      final service = build();
      service.changed();
      service.dispose();
      timers.single.fire();
      await service.flush();
      expect(gateway.saves, 0);
    });

    test('nothing to show stores nothing', () async {
      final service = HomeWidgetService(
        gateway: gateway,
        available: () => true,
        summary: () => null,
        texts: () => homeWidgetTextsFor(const Locale('en')),
      );
      await service.flush();
      expect(gateway.saves, 0);
      expect(gateway.redraws, 0);
    });
  });

  group('a failure', () {
    test('goes to the log and is never thrown', () async {
      gateway.failing = true;
      final service = build();
      await service.flush();
      expect(logged, hasLength(1));
      expect(logged.single, startsWith('Home widget error:'));
      expect(logged.single, contains('no widget storage'));
    });

    test('does not stop the next store', () async {
      gateway.failing = true;
      final service = build();
      await service.flush();
      gateway.failing = false;
      await service.flush();
      expect(gateway.saves, 1);
      expect(logged, hasLength(1));
    });
  });

  group('from the app', () {
    late FakeHomeWidgetGateway phone;

    Future<AppState> launch() async {
      phone = FakeHomeWidgetGateway();
      final state = AppState.test(
        decks: MemoryDeckSource(<String, String>{
          'decks/es/es-en-words.yaml': _deck('es', 'Spanish', 'spa', 1000, 3),
          'decks/fr/fr-en-words.yaml': _deck('fr', 'French', 'fra', 2000, 2),
        }),
        tts: FixedTtsEngine(const <String>{'en', 'es', 'fr'}),
        homeWidgetGateway: phone,
      );
      addTearDown(state.dispose);
      await state.load();
      await pumpEventQueue();
      return state;
    }

    void answer(
      AppState state,
      String deck,
      String card, {
      required int daysAgo,
    }) => state.progress.record(
      deckId: deck,
      cardId: card,
      mode: DrillMode.recognition,
      grade: 3,
      now: state.now().subtract(Duration(days: daysAgo)),
    );

    test('counts the shown language only, and the streak', () async {
      final state = await launch();
      // Two Spanish cards and one French are due; a French card answered
      // today gives the streak, and is not Spanish.
      answer(state, 'es-en-words', 'es-1000', daysAgo: 30);
      answer(state, 'es-en-words', 'es-1001', daysAgo: 30);
      answer(state, 'fr-en-words', 'fr-2000', daysAgo: 30);
      answer(state, 'fr-en-words', 'fr-2001', daysAgo: 0);

      expect(state.shownLanguage, 'es');
      final summary = state.homeWidgetSummary()!;
      expect(summary.language, 'Spanish');
      expect(summary.day, DateTime(2026, 9, 28));
      expect(summary.dueToday, 2, reason: 'French is not the shown language');
      expect(summary.dueNext, 2);
      expect(summary.streak, 1);
      expect(summary.practisedToday, isTrue);
    });

    test('follows the language that is shown', () async {
      final state = await launch();
      answer(state, 'es-en-words', 'es-1000', daysAgo: 30);
      answer(state, 'fr-en-words', 'fr-2000', daysAgo: 30);
      answer(state, 'fr-en-words', 'fr-2001', daysAgo: 30);
      state.showLanguage('fr');
      final summary = state.homeWidgetSummary()!;
      expect(summary.language, 'French');
      expect(summary.dueToday, 2);
      expect(summary.practisedToday, isFalse);
    });

    test('stores what the app holds when it is left', () async {
      final state = await launch();
      answer(state, 'es-en-words', 'es-1000', daysAgo: 30);
      await state.homeWidget.flush();
      expect(phone.stored[HomeWidgetKeys.language], 'Spanish');
      expect(phone.stored[HomeWidgetKeys.dueToday], '1 due');
      expect(phone.stored[HomeWidgetKeys.day], '2026-09-28');
      expect(phone.redraws, 1);
    });
  });
}
