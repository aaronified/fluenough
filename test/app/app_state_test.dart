import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/features/gallery/fixtures.dart';

void main() {
  test('tomorrow counts only what Today will drill: not a pair set aside, '
      'nor a skill switched off', () async {
    final state = AppState.test();
    addTearDown(state.dispose);
    await state.load();
    final cards = state.deckById('es-en-core-100')!.cards;
    // Answered Hard today, so due tomorrow.
    for (final card in cards.take(3)) {
      state.progress.record(
        deckId: 'es-en-core-100',
        cardId: card.id,
        mode: DrillMode.production,
        grade: 3,
        now: state.now(),
      );
    }
    expect(state.dueTomorrow(), 3);
    state.progress.actOnLeech(
      (cardId: cards.first.id, mode: DrillMode.production),
      LeechActionKind.setAside,
      now: state.now(),
    );
    expect(state.dueTomorrow(), 2);
    state.settings.setSkillEnabled(Skill.production, false);
    expect(state.dueTomorrow(), 0);
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> loaded({
    FixedTtsEngine? tts,
    FeatureRegistry features = const FeatureRegistry.shipped(),
    SettingsNotifier? settings,
    List<Profile> profiles = const [Profile.defaultProfile],
  }) async {
    final state = AppState.test(
      tts: tts ?? FixedTtsEngine(const {}),
      features: features,
      settings: settings,
      profiles: profiles,
    );
    await state.load();
    return state;
  }

  group('loading', () {
    test('starts loading, then holds the bundled decks', () async {
      final state = AppState.test();
      expect(state.status, CatalogStatus.loading);
      expect(state.decks, isEmpty);
      var notified = 0;
      state.addListener(() => notified++);
      await state.load();
      expect(state.status, CatalogStatus.ready);
      expect(state.deckById('es-en-core-100'), isNotNull);
      expect(state.brokenDecks, isEmpty);
      expect(notified, greaterThan(0));
    });

    test('a catalog that cannot load is a failure, not a crash', () async {
      final state = AppState.test(decks: _ThrowingSource());
      await state.load();
      expect(state.status, CatalogStatus.failed);
      expect(state.loadError, isA<StateError>());
    });

    test('reload reads the source again after a failure', () async {
      final source = _FailOnceSource();
      final state = AppState.test(decks: source);
      await state.load();
      expect(state.status, CatalogStatus.failed);
      await state.load();
      expect(source.listed, 1, reason: 'load is memoised');

      final statuses = <CatalogStatus>[];
      state.addListener(() => statuses.add(state.status));
      final reloading = state.reload();
      expect(state.status, CatalogStatus.loading);
      expect(state.loadError, isNull);
      expect(identical(state.reload(), reloading), isTrue, reason: 'joined');
      await reloading;
      expect(source.listed, 2);
      expect(state.status, CatalogStatus.ready);
      expect(statuses.take(2), <CatalogStatus>[
        CatalogStatus.loading,
        CatalogStatus.ready,
      ]);
    });
  });

  group('voices', () {
    test('are checked once the catalog is in', () async {
      final state = await loaded(tts: FixedTtsEngine({'es'}));
      final spanish = state.deckById('es-en-core-100')!.language;
      final hindi = state.deckById('hi-en-script-vowels')!.language;
      expect(state.voiceStatus(spanish), VoiceStatus.available);
      expect(state.voiceStatus(hindi), VoiceStatus.missing);
      expect(state.hasVoice(hindi), isFalse);
    });

    test('speak uses the language tag and the learner\'s rate', () async {
      final tts = FixedTtsEngine({'es'});
      final state = await loaded(
        tts: tts,
        settings: SettingsNotifier(speechRate: 0.8),
      );
      final spanish = state.deckById('es-en-core-100')!.language;
      await state.speak('la casa', spanish);
      await state.speak('la casa', spanish, slower: true);
      expect(tts.spoken.map((s) => s.bcp47), ['es-ES', 'es-ES']);
      expect(tts.spoken[0].rate, closeTo(0.4, 1e-9));
      expect(tts.spoken[1].rate, closeTo(0.28, 1e-9));
    });
  });

  group('sessions', () {
    // Grammar cards enter in their own mode. These tests are about
    // vocabulary, so the grammar drill is off in them.
    final vocabOnly = FeatureRegistry.only(
      Feature.available.difference({Feature.drillGrammar}),
    );

    test('today, fresh: nothing to review, and new words come in a lesson '
        '(ADR-0024)', () async {
      final state = await loaded(features: vocabOnly);
      expect(state.buildSession(const DrillRequest.today()).isEmpty, isTrue);
      final lesson = state.lessonFor(DrillRequest.lesson(language: 'es'));
      expect(lesson.where((i) => i.ask == Ask.teach), hasLength(9));
    });

    test('once a word is taught, its other skills join the reviews, and '
        'it leaves the lessons', () async {
      final state = await loaded(features: vocabOnly);
      final lesson = DrillRequest.lesson(language: 'es');
      final check = state.lessonFor(lesson)[1];
      state.record(check, 4);
      expect(state.isTaught(check.card), isTrue);
      final today = state.buildSession(const DrillRequest.today());
      expect(today.fresh.map((i) => i.card.id), <String>[check.card.id]);
      expect(today.fresh.single.mode, isNot(check.mode));
      expect(
        state.lessonFor(lesson).map((i) => i.card.id),
        isNot(contains(check.card.id)),
      );
    });

    test('listening joins only when the language has a voice', () async {
      final state = await loaded(tts: FixedTtsEngine({'es'}));
      final spanish = state.buildSession(
        DrillRequest.untaught('es-en-core-100', skill: Skill.listening),
      );
      final hindi = state.buildSession(
        DrillRequest.untaught('hi-en-script-vowels', skill: Skill.listening),
      );
      expect(spanish.isNotEmpty, isTrue);
      expect(hindi.isEmpty, isTrue);
    });

    test('an incoming skill never enters a session', () async {
      final state = await loaded(
        features: const FeatureRegistry.only({Feature.drillProduction}),
      );
      final queue = state.buildSession(const DrillRequest.today());
      expect(queue.items.every((i) => i.mode == DrillMode.production), isTrue);
      expect(
        state
            .buildSession(
              DrillRequest.deck('es-en-core-100', skill: Skill.grammar),
            )
            .isEmpty,
        isTrue,
      );
    });

    test('a skill switched off in settings is left out', () async {
      final settings = SettingsNotifier();
      final state = await loaded(
        tts: FixedTtsEngine({'es'}),
        settings: settings,
        features: vocabOnly,
      );
      // A taught word's other skills join the reviews, Write first; with
      // Write switched off, Hear comes in its place.
      state.record(state.lessonFor(DrillRequest.lesson(language: 'es'))[1], 4);
      settings.setSkillEnabled(Skill.production, false);
      final queue = state.buildSession(const DrillRequest.today());
      expect(queue.isNotEmpty, isTrue);
      expect(queue.items.every((i) => i.mode != DrillMode.production), isTrue);
    });

    test('tags narrow a deck to the cards that carry them', () async {
      final state = await loaded();
      final queue = state.buildSession(
        const DrillRequest(
          deckIds: {'es-en-core-100'},
          tags: {'people'},
          untaught: true,
        ),
      );
      expect(queue.isNotEmpty, isTrue);
      expect(queue.items.every((i) => i.card.tags.contains('people')), isTrue);
    });

    test('a profile sees only its own languages', () async {
      final state = await loaded(
        profiles: const [
          Profile(id: 'mira', name: 'Mira', languages: {'hi'}),
        ],
      );
      final hindi = <String>{
        for (final d in state.decks)
          if (d.language.code == 'hi') d.id,
      };
      expect(state.profileDecks.map((d) => d.id).toSet(), hindi);
      final lesson = state.lessonFor(DrillRequest.lesson(language: 'hi'));
      expect(lesson, isNotEmpty);
      expect(lesson.every((i) => hindi.contains(i.card.deckId)), isTrue);
      expect(state.lessonFor(DrillRequest.lesson(language: 'es')), isEmpty);
    });

    test('Start review takes new skills of taught words only', () async {
      // With history, so some words are taught.
      final state = GalleryFixtures.state(await loaded());
      await state.load();
      final queue = state.buildSession(const DrillRequest.today());
      expect(queue.due, isNotEmpty);
      expect(queue.fresh.every((i) => state.isTaught(i.card)), isTrue);
    });

    test('new cards follow the theme path, two units at a time; a picked '
        'theme drills alone', () async {
      String deck(String id, String theme) =>
          '''
schema: 1
id: $id
name: "$theme"
theme: $theme
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: $id-0001, target: "क", native: "k", reading: "k" }
  - { id: $id-0002, target: "ख", native: "kh", reading: "kh" }
''';
      final state = AppState.test(
        decks: MemoryDeckSource(<String, String>{
          'decks/themes.yaml': '''
schema: 1
kind: themes
themes:
  - { id: first-words, name: "First words" }
  - { id: market, name: "Market" }
''',
          // Alphabetically, market's file comes first; the path puts it second.
          'decks/hi/hi-en-a-market.yaml': deck('hi-en-a-market', 'market'),
          'decks/hi/hi-en-first-words.yaml': deck(
            'hi-en-first-words',
            'first-words',
          ),
        }),
      );
      await state.load();
      // Without a path each deck is a unit, in theme order; a lesson mixes
      // the first two (ADR-0013), first words first.
      expect(state.untaughtCards('hi').take(2).map((c) => c.deckId), [
        'hi-en-first-words',
        'hi-en-a-market',
      ]);
      final picked = state.buildSession(
        DrillRequest.untaught('hi-en-a-market'),
      );
      expect(picked.items.map((i) => i.card.deckId).toSet(), {
        'hi-en-a-market',
      });
    });

    test('recording goes to the progress store at the injected time', () async {
      final state = await loaded();
      final item = state
          .lessonFor(DrillRequest.lesson(language: 'es'))
          .firstWhere((i) => i.ask != Ask.teach);
      final event = state.record(item, 5, answerGiven: 'x');
      expect(event.at, state.now());
      expect(state.progress.log.single.cardId, item.card.id);
      expect(state.progress.stateOf(item.card.id, item.mode), isNotNull);
    });

    test('deck counts agree with the deck\'s session', () async {
      final state = await loaded();
      final deck = state.deckById('hi-en-script-vowels')!;
      final counts = state.countsFor(deck);
      expect(counts.due, 0);
      // New: the words not taught yet.
      expect(counts.fresh, state.notStudiedIn(deck));
      expect(counts.fresh, greaterThan(0));
      expect(counts.learned, 0);
    });
  });

  group('profiles', () {
    test('the app opens on the default profile', () async {
      final state = await loaded();
      expect(state.currentProfile.id, Profile.defaultProfile.id);
      expect(state.currentProfile.name, isNull);
      expect(state.profileDecks, hasLength(state.decks.length));
    });

    test('creating adds, selecting switches and notifies', () async {
      final state = await loaded();
      var notified = 0;
      state.addListener(() => notified++);
      final dev = state.createProfile(name: ' Dev ', languages: {'es'});
      expect(dev.name, 'Dev');
      expect(state.profiles, hasLength(2));
      expect(state.currentProfile.id, isNot(dev.id));
      state.selectProfile(dev.id);
      expect(state.currentProfile.id, dev.id);
      expect(notified, 2);
      state.selectProfile('nobody');
      expect(state.currentProfile.id, dev.id);
    });

    test('a PIN is checked against the profile', () async {
      final state = await loaded(
        profiles: const [
          Profile(id: 'aro', name: 'Aro', pin: '1234'),
          Profile(id: 'mira', name: 'Mira'),
        ],
      );
      expect(state.checkPin('aro', '1234'), isTrue);
      expect(state.checkPin('aro', '0000'), isFalse);
      expect(state.checkPin('mira', ''), isTrue);
      expect(state.checkPin('nobody', '1234'), isFalse);
    });
  });

  test('progress in memory is not saved, whatever the features say', () async {
    expect((await loaded()).progressIsSaved, isFalse);
    expect(
      (await loaded(features: FeatureRegistry.all())).progressIsSaved,
      isFalse,
    );
  });

  test('settings clamp to their ranges', () {
    final settings = SettingsNotifier();
    settings.speechRate = 9;
    expect(settings.speechRate, SettingsNotifier.maxSpeechRate);
    var notified = 0;
    settings.addListener(() => notified++);
    settings.speechRate = SettingsNotifier.maxSpeechRate;
    expect(notified, 0, reason: 'no change, no notification');
  });

  test('memory progress is the default store', () {
    expect(AppState.test().progress, isA<MemoryProgress>());
  });
}

class _ThrowingSource implements DeckSource {
  @override
  Future<List<String>> list() async => throw StateError('no manifest');

  @override
  Future<String> read(String path) async => throw StateError('unreachable');
}

/// Fails its first listing, then lists no files.
class _FailOnceSource implements DeckSource {
  int listed = 0;

  @override
  Future<List<String>> list() async {
    if (listed++ == 0) throw StateError('no manifest');
    return const <String>[];
  }

  @override
  Future<String> read(String path) async => throw StateError('unreachable');
}
