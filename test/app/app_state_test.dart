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
import 'package:fluenough/core/tts/fixed_tts_engine.dart';

void main() {
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
      expect(state.deckById('es-core-100'), isNotNull);
      expect(state.brokenDecks, isEmpty);
      expect(notified, greaterThan(0));
    });

    test('a catalog that cannot load is a failure, not a crash', () async {
      final state = AppState.test(decks: _ThrowingSource());
      await state.load();
      expect(state.status, CatalogStatus.failed);
      expect(state.loadError, isA<StateError>());
    });
  });

  group('voices', () {
    test('are checked once the catalog is in', () async {
      final state = await loaded(tts: FixedTtsEngine({'es'}));
      final spanish = state.deckById('es-core-100')!.language;
      final japanese = state.deckById('ja-hiragana')!.language;
      expect(state.voiceStatus(spanish), VoiceStatus.available);
      expect(state.voiceStatus(japanese), VoiceStatus.missing);
      expect(state.hasVoice(japanese), isFalse);
    });

    test('speak uses the language tag and the learner\'s rate', () async {
      final tts = FixedTtsEngine({'es'});
      final state = await loaded(
        tts: tts,
        settings: SettingsNotifier(speechRate: 0.8),
      );
      final spanish = state.deckById('es-core-100')!.language;
      await state.speak('la casa', spanish);
      await state.speak('la casa', spanish, slower: true);
      expect(tts.spoken.map((s) => s.bcp47), ['es-ES', 'es-ES']);
      expect(tts.spoken[0].rate, closeTo(0.4, 1e-9));
      expect(tts.spoken[1].rate, closeTo(0.28, 1e-9));
    });
  });

  group('sessions', () {
    test('today, fresh: new recognition pairs up to the daily cap', () async {
      final state = await loaded();
      final queue = state.buildSession(const DrillRequest.today());
      expect(queue.length, 20);
      expect(queue.due, isEmpty);
      expect(queue.items.every((i) => i.mode == DrillMode.recognition), isTrue);
    });

    test('the cap follows the setting and what today already used', () async {
      final settings = SettingsNotifier(newCardsPerDay: 5);
      final state = await loaded(settings: settings);
      expect(state.buildSession(const DrillRequest.today()).length, 5);
      final item = state.buildSession(const DrillRequest.today()).items.first;
      state.record(item, 4);
      expect(state.newCardsLeftToday, 4);
      settings.newCardsPerDay = 0;
      expect(state.buildSession(const DrillRequest.today()).isEmpty, isTrue);
    });

    test('listening joins only when the language has a voice', () async {
      final state = await loaded(tts: FixedTtsEngine({'es'}));
      final spanish = state.buildSession(
        DrillRequest.deck('es-core-100', skill: Skill.listening),
      );
      final japanese = state.buildSession(
        DrillRequest.deck('ja-hiragana', skill: Skill.listening),
      );
      expect(spanish.isNotEmpty, isTrue);
      expect(japanese.isEmpty, isTrue);
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
              DrillRequest.deck('es-core-100', skill: Skill.grammar),
            )
            .isEmpty,
        isTrue,
      );
    });

    test('a skill switched off in settings is left out', () async {
      final settings = SettingsNotifier();
      final state = await loaded(settings: settings);
      settings.setSkillEnabled(Skill.recognition, false);
      final queue = state.buildSession(const DrillRequest.today());
      expect(queue.items.every((i) => i.mode == DrillMode.production), isTrue);
    });

    test('tags narrow a deck to the cards that carry them', () async {
      final state = await loaded();
      final queue = state.buildSession(
        DrillRequest.deck('es-core-100', tags: {'people'}),
      );
      expect(queue.isNotEmpty, isTrue);
      expect(queue.items.every((i) => i.card.tags.contains('people')), isTrue);
    });

    test('a profile sees only its own languages', () async {
      final state = await loaded(
        profiles: const [
          Profile(id: 'mira', name: 'Mira', languages: {'ja'}),
        ],
      );
      expect(state.profileDecks.map((d) => d.id), ['ja-hiragana']);
      final queue = state.buildSession(const DrillRequest.today());
      expect(queue.items.every((i) => i.card.deckId == 'ja-hiragana'), isTrue);
    });

    test('learnNew drills only new pairs, at most the number asked', () async {
      final state = await loaded();
      final queue = state.buildSession(const DrillRequest.learnNew(5));
      expect(queue.length, 5);
      expect(queue.items.every((i) => i.isNew), isTrue);
    });

    test('recording goes to the progress store at the injected time', () async {
      final state = await loaded();
      final item = state.buildSession(const DrillRequest.today()).items.first;
      final event = state.record(item, 5, answerGiven: 'x');
      expect(event.at, state.now());
      expect(state.progress.log.single.cardId, item.card.id);
      expect(
        state.progress.stateOf(item.card.deckId, item.card.id, item.mode),
        isNotNull,
      );
    });

    test('deck counts agree with the deck\'s session', () async {
      final state = await loaded(settings: SettingsNotifier(newCardsPerDay: 7));
      final deck = state.deckById('ja-hiragana')!;
      final counts = state.countsFor(deck);
      expect(counts.due, 0);
      expect(counts.fresh, 7);
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

  test('progress is not saved while persistence is incoming', () async {
    expect((await loaded()).progressIsSaved, isFalse);
    expect(
      (await loaded(features: FeatureRegistry.all())).progressIsSaved,
      isTrue,
    );
  });

  test('settings clamp to their ranges', () {
    final settings = SettingsNotifier();
    settings.newCardsPerDay = 500;
    expect(settings.newCardsPerDay, SettingsNotifier.maxNewCardsPerDay);
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
