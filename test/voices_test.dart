// Voices: which voice says a card, and when nothing is said. The fallback
// between the Hindi and Urdu voices, a voice gone, one word's error, sound
// off, a muted phone, recordings, a tap that plays a word without giving
// the answer away, the Voices page, and rude words never offered.

import 'dart:async';
import 'dart:io';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/card_media.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/app/system_settings.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';
import 'package:fluenough/core/speech/speech_engine.dart';
import 'package:fluenough/core/speech/system_speech_engine.dart';
import 'package:fluenough/core/tts/clip_player.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/tts/system_tts_engine.dart';
import 'package:fluenough/core/tts/tts_engine.dart';
import 'package:fluenough/core/tts/voice_apps.dart';
import 'package:fluenough/core/tts/volume_monitor.dart';
import 'package:fluenough/features/drill/drill_page.dart';
import 'package:fluenough/features/drill/drill_preset.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/match_hear_toggle.dart';
import 'package:fluenough/features/settings/speech_test_sheet.dart';
import 'package:fluenough/features/settings/voices_page.dart';
import 'package:fluenough/features/today/today_numbers.dart';
import 'package:fluenough/ui/widgets/speaker.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'support/settings_pages.dart';
import 'support/harness.dart';
import 'support/review_fixture.dart';

// From voice_backup_test.dart.
// A course's decks may name several voices: Hindustani's Devanagari decks
// are voiced `hi-IN`, its Perso-Arabic ones `ur-PK` (#641). Every one is
// listed and checked, and while the deck's own is missing the course's
// other voice says the card's spelling in its script.

/// A phone with [voices], and the state loaded on it.
Future<(AppState, FixedTtsEngine)> _phone(Set<String> voices) async {
  final tts = FixedTtsEngine(voices);
  final state = AppState.test(tts: tts);
  addTearDown(state.dispose);
  await state.load();
  return (state, tts);
}

/// The Perso-Arabic deck that has the card [id], and the card.
(DeckEntry, Card) _perso(AppState state, String id) {
  final entry = state.decks.firstWhere(
    (d) => d.language.ttsTag == 'ur-PK' && d.cards.any((c) => c.id == id),
  );
  return (entry, entry.cards.firstWhere((c) => c.id == id));
}

// From system_tts_engine_test.dart.
/// The plugin as Android's flutter_tts 4.2.5 behaves: with
/// awaitSpeakCompletion, speak() completes when the utterance is done, and
/// an utterance that fails calls the error handler and never completes it.
class _Plugin extends FlutterTts {
  _Plugin();

  /// The voices getVoices lists, as the plugin gives them.
  List<Map<String, String>> voices = <Map<String, String>>[
    <String, String>{'name': 'es-es-x-eea', 'locale': 'es-ES'},
    <String, String>{'name': 'es-us-x-esd', 'locale': 'es-US'},
  ];

  /// What getVoices or isLanguageAvailable throws, for a broken engine.
  PlatformException? broken;

  /// The pending utterance, completed by [finish] or never.
  Completer<dynamic>? utterance;

  int voiceLists = 0;
  final List<String> calls = <String>[];

  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    if (broken case final e?) throw e;
    return true;
  }

  @override
  Future<dynamic> get getVoices async {
    voiceLists++;
    if (broken case final e?) throw e;
    return voices;
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    calls.add('language $language');
    return 1;
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    calls.add('voice ${voice['name']}');
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) {
    calls.add('speak $text');
    return (utterance = Completer<dynamic>()).future;
  }

  @override
  Future<dynamic> stop() async => 1;

  /// The utterance ends as it should.
  void finish() => utterance!.complete(1);

  /// The engine reports an error, as onError does: through the handler,
  /// leaving speak() pending.
  void fail(String message) => errorHandler!(message);
}

// From engine_errors_test.dart.
/// What the phone's own speech and voice engines fail with reaches the app
/// log by its code (#162), rather than being swallowed into "no" or "none"
/// inside the engine.

/// The recogniser plugin, whose listen never answers.
class _Recogniser extends SpeechToText {
  _Recogniser() : super.withMethodChannel();

  int stops = 0;

  @override
  Future<bool> get hasPermission async {
    return true;
  }

  @override
  Future<bool> initialize({
    onError,
    onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    return true;
  }

  @override
  Future<List<LocaleName>> locales() {
    return Future.value(<LocaleName>[LocaleName('hi_IN', 'Hindi')]);
  }

  /// Never answers: the recogniser neither hears nor gives up.
  @override
  Future<void> listen({
    onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {}

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> cancel() async {}
}

// From sound_settings_test.dart.
/// Sound for the whole app, playing words automatically and the speaker
/// tap count: stored like every setting; and what sound off does
/// to what is spoken and drilled.

// From raise_volume_test.dart.
/// A phone at zero volume (ADR-0026): a question that needs sound is greyed
/// out and asks, on the card, for the volume to be raised.

const String hindi = 'hi-en-phrasebook';

Future<AppState> pumpHeard(
  WidgetTester tester,
  FixedVolumeMonitor volume, {
  Ask ask = Ask.hearAndChoose,
}) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(hindi, skill: Skill.listening),
    preset: DrillPreset(target: 'नमस्कार', ask: ask),
  ),
  state: AppState.test(tts: FixedTtsEngine(<String>{'hi'}), volume: volume),
);

// From card_media_test.dart.
/// Finds every recording at [path] on the phone.
class _At implements CardMedia {
  const _At(this.path);

  final String path;

  @override
  String? localPath(String path) => '${this.path}/$path';
}

const appendix = 'test/fixtures/b1/appendix-a/zz';
const recording = 'decks/zz/audio/zz-9001.opus';

const credit =
    '{ source: "https://commons.wikimedia.org/wiki/File:Te-ఇల్లు.ogg", '
    'license: "CC-BY-SA-4.0", credit: "A. Speaker" }';

const testlang = LanguageInfo(
  code: 'zz',
  iso639_3: 'zzz',
  name: 'Testlang',
  script: 'telugu',
  tts: 'te-IN',
);

// From speaker_test.dart.
/// A speaker on every drill card (the owner's spec): a tap plays, a long
/// press switches Play words automatically, every tenth tap says so, and
/// with sound off it is greyed out and says why.

const String spanish = 'es-en-core-100';

AppState voiced({SettingsNotifier? settings, FixedTtsEngine? tts}) =>
    AppState.test(
      tts: tts ?? FixedTtsEngine(const <String>{'es', 'hi'}),
      settings: settings,
    );

/// [state]'s settings, past the first launch, with [change] made.
SettingsNotifier settingsWith(void Function(SettingsNotifier s) change) {
  final s = SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningChosen: true,
  );
  change(s);
  return s;
}

Future<AppState> pumpAsked(
  WidgetTester tester, {
  required Skill skill,
  required AppState state,
  String deck = spanish,
  String target = 'la casa',
  Ask ask = Ask.own,
}) => pumpScreen(
  tester,
  DrillPage(
    request: DrillRequest.untaught(deck, skill: skill),
    preset: DrillPreset(target: target, ask: ask),
  ),
  state: state,
);

Finder get speaker => find.byType(Speaker);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Card cardOf(AppState state, String deck, String target) =>
    state.deckById(deck)!.cards.firstWhere((c) => c.target == target);

// From match_tap_to_hear_test.dart.
/// Tap to hear in match pairs (ADR-0032): its own setting, on by default and
/// remembered, switched by one speaker button on the card. While it is on, a
/// word tile tapped says its word, whatever Play words automatically says;
/// a meaning never speaks; sound off in Settings still wins.

AppState tapVoiced({SettingsNotifier? settings, FixedTtsEngine? tts}) =>
    AppState.test(
      tts: tts ?? FixedTtsEngine(const <String>{'es'}),
      settings: settings,
    );

/// A match of four words, the other three taken from Write's new pairs:
/// what is tested here is the tiles, not what they record.
Future<AppState> pumpMatch(WidgetTester tester, {required AppState state}) =>
    pumpScreen(
      tester,
      DrillPage(
        key: UniqueKey(),
        request: DrillRequest.untaught(spanish, skill: Skill.production),
        preset: const DrillPreset(target: 'la casa', ask: Ask.matchPairs),
      ),
      state: state,
    );

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapToggle(WidgetTester tester) async {
  await tester.tap(find.byType(MatchHearToggle));
  await tester.pumpAndSettle();
}

Finder get toggle => find.byType(MatchHearToggle);

/// The toggle's icon, or null if it has none.
IconData? iconOf(WidgetTester tester) => tester
    .widget<Icon>(find.descendant(of: toggle, matching: find.byType(Icon)))
    .icon;

/// The words of the match on screen, with their meanings.
List<({String word, String meaning})> pairsOf(
  WidgetTester tester,
) => <({String word, String meaning})>[
  for (final entry
      in tester.widget<MatchDrill>(find.byType(MatchDrill)).session.item.group)
    (word: entry.card.target, meaning: entry.card.native),
];

// From voices_page_test.dart.
/// How many languages the Voices page lists: every one but the IPA, which
/// has no voice (ADR-0041).
int _voiced(AppState state) => state.languages.where((l) => !l.isIpa).length;

LanguageInfo _language(AppState state, String code) =>
    state.languages.firstWhere((l) => l.code == code);

// From voice_cards_test.dart.
// One Voices card per language, with a test for hearing it and for
// speaking it.

/// A phone tall enough for every bundled language's card.
void _useTallPhone(WidgetTester tester, {double textScale = 1.0}) {
  usePhone(tester, textScale: textScale);
  tester.view.physicalSize = const Size(390 * 3, 9000 * 3);
}

/// A state with [speech] set up and speaking on, and voices for [voices].
Future<AppState> _speaking(
  FixedSpeechEngine speech, {
  Set<String> voices = const <String>{'hi', 'es'},
  bool on = true,
}) async {
  final state = AppState.test(
    speech: speech,
    tts: FixedTtsEngine(voices),
    settings: SettingsNotifier(
      spokenLanguages: const <String>['en'],
      learningChosen: true,
      enabledSkills: <Skill>{
        ...Skill.values.where((s) => s.onByDefault),
        if (on) Skill.speaking,
      },
    ),
  );
  await state.load();
  if (on) await state.startSpeech();
  return state;
}

/// [language]'s card.
Finder _card(String name) => find.ancestor(
  of: find.textContaining(name, findRichText: true),
  matching: find.byType(LanguageVoiceCard),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// From voice_apps_page_test.dart.
// The Voices page for a course that uses two voices, Hindustani's hi-IN and
// ur-PK (#641), and the voice apps it lists (#642).

/// A [FixedTtsEngine] whose voices can change, for the learner installing
/// one while away.
class _NamedTts implements TtsEngine {
  _NamedTts(this.voices);

  Set<String> voices;

  FixedTtsEngine get _now => FixedTtsEngine(voices);

  @override
  Future<bool> isLanguageAvailable(String bcp47) =>
      _now.isLanguageAvailable(bcp47);

  @override
  Future<List<TtsVoice>> voicesFor(String bcp47) => _now.voicesFor(bcp47);

  @override
  Future<void> speak(
    String text, {
    required String bcp47,
    double rate = 0.5,
    String? voice,
  }) => _now.speak(text, bcp47: bcp47, rate: rate, voice: voice);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final List<VoiceApp> _apps = parseVoiceApps(
  File('assets/voice_apps.yaml').readAsStringSync(),
);

Finder _hindustani() => find.ancestor(
  of: find.textContaining('Hindustani', findRichText: true),
  matching: find.byType(LanguageVoiceCard),
);

AppState _state(_NamedTts tts, {FixedLinks? links}) => AppState.test(
  tts: tts,
  links: links,
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['hi'],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the backup voice', () {
    test('with the Urdu voice missing, the Hindi voice says the card from its '
        'Devanagari spelling', () async {
      final (state, tts) = await _phone(<String>{'hi-in'});
      final (entry, card) = _perso(state, 'hi-0647');
      expect(card.targetScripts['devanagari'], 'ब');
      expect(state.voiceStatus(entry.language), VoiceStatus.missing);
      expect(state.backupVoice(entry.language)?.ttsTag, 'hi-IN');
      expect(state.hasVoice(entry.language), isTrue);

      await state.speakCard(card, entry.language);
      expect(tts.spoken.single.bcp47, 'hi-IN');
      expect(tts.spoken.single.text, 'ब');
    });

    test('a card with no spelling in the backup script is not said', () async {
      final (state, tts) = await _phone(<String>{'hi-in'});
      final (entry, card) = _perso(state, 'hi-0690');
      expect(card.targetScripts, isEmpty);
      await state.speakCard(card, entry.language);
      expect(tts.spoken, isEmpty);
    });

    test('with neither voice there is no backup', () async {
      final (state, _) = await _phone(<String>{});
      final (entry, _) = _perso(state, 'hi-0647');
      expect(state.backupVoice(entry.language), isNull);
      expect(state.hasVoice(entry.language), isFalse);
    });
  });

  group('the phone\'s voice', () {
    late _Plugin plugin;
    late SystemTtsEngine engine;
    setUp(() {
      plugin = _Plugin();
      engine = SystemTtsEngine(tts: plugin);
    });

    test('an error for one word does not fail the next, and a voice gone '
        'from the list falls back to the language\'s', () async {
      final first = engine.speak('hola', bcp47: 'es-ES');
      await pumpEventQueue();
      plugin.fail('Error from TextToSpeech (speak) - -8');
      await expectLater(first, throwsA(isA<TtsFailure>()));
      final second = engine.speak('adiós', bcp47: 'es-ES');
      await pumpEventQueue();
      plugin.finish();
      await second;

      plugin.voices = <Map<String, String>>[
        <String, String>{'name': 'es-es-x-eea', 'locale': 'es-ES'},
      ];
      expect(await engine.voicesFor('es-ES'), hasLength(1));
      final speaking = engine.speak(
        'uno',
        bcp47: 'es-ES',
        voice: 'es-us-x-esd',
      );
      await pumpEventQueue();
      plugin.finish();
      await speaking;
      expect(plugin.calls, <String>['language es-ES', 'speak uno']);
      expect(plugin.voiceLists, 1);
    });
  });

  group('engine errors', () {
    group('the recogniser', () {
      testWidgets('a listen that never answers fails with the code timeout', (
        tester,
      ) async {
        final listening = SystemSpeechEngine(_Recogniser())
            .listen(bcp47: 'hi-IN', onDevice: true);
        await tester.pump(const Duration(seconds: 13));
        final heard = await listening;
        expect(heard.failure, SpeechFailure.noMatch);
        expect(heard.code, 'timeout');
      });
    });
  });

  group('sound off', () {
    group('sound off', () {
      Future<AppState> loaded(
        FixedTtsEngine tts, {
        MemoryProgress? progress,
      }) async {
        final state = AppState.test(tts: tts, progress: progress);
        await state.load();
        return state;
      }

      test(
        'with sound off nothing is spoken, and listening is skipped',
        () async {
          final tts = FixedTtsEngine(const <String>{'es'});
          final state = await loaded(tts);
          final spanish = state.deckById('es-en-core-100')!.language;
          state.settings.soundOn = false;
          await state.speak('la casa', spanish);
          expect(tts.spoken, isEmpty);
          expect(state.voiceStatus(spanish), VoiceStatus.available);
          expect(state.hasVoice(spanish), isTrue);
          expect(state.canSpeak(spanish), isFalse);

          state.settings.soundOn = true;
          await state.speak('la casa', spanish);
          expect(tts.spoken.single.text, 'la casa');
          expect(state.canSpeak(spanish), isTrue);

          {
            // Words taught by ear three days ago, so that listening is due.
            final base = await loaded(
              FixedTtsEngine(const <String>{'es', 'hi'}),
            );
            final progress = MemoryProgress();
            for (final card in base.untaughtCards('es').take(4)) {
              progress.record(
                deckId: card.deckId,
                cardId: card.id,
                mode: DrillMode.listening,
                grade: 4,
                now: base.now().subtract(const Duration(days: 3)),
              );
            }
            final state =
                await loaded(
                    FixedTtsEngine(const <String>{'es', 'hi'}),
                    progress: progress,
                  )
                  ..showLanguage('es');

            bool listens(Iterable<SessionItem> items) =>
                items.any((i) => i.mode == DrillMode.listening);
            final deck = DrillRequest.untaught(
              'es-en-core-100',
              skill: Skill.listening,
            );
            final lesson = DrillRequest.lesson(language: 'es');
            const today = DrillRequest.today();
            final numbers = state.deckById('hi-en-numbers-big')!;

            // Sound on: each has listening.
            expect(state.buildSession(deck).isNotEmpty, isTrue);
            expect(listens(state.lessonFor(lesson)), isTrue);
            expect(listens(state.buildSession(today).items), isTrue);
            expect(
              TodayNumbers.of(state).bySkill[Skill.listening],
              greaterThan(0),
            );
            expect(listens(state.numberPracticeFor(numbers)), isTrue);

            state.settings.soundOn = false;
            expect(state.buildSession(deck).isEmpty, isTrue);
            expect(listens(state.lessonFor(lesson)), isFalse);
            expect(
              state.lessonFor(lesson),
              isNotEmpty,
              reason: 'the rest stays',
            );
            expect(listens(state.buildSession(today).items), isFalse);
            expect(state.buildSession(today).items, isNotEmpty);
            expect(TodayNumbers.of(state).bySkill[Skill.listening] ?? 0, 0);
            expect(listens(state.numberPracticeFor(numbers)), isFalse);
          }
        },
      );
    });
  });

  group('a muted phone', () {
    testWidgets('a heard question asks for the volume while the phone is at '
        'zero, and is asked as usual once it is raised', (tester) async {
      usePhone(tester);
      final volume = FixedVolumeMonitor(muted: true);
      await pumpHeard(tester, volume);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.drillRaiseVolume), findsOneWidget);
      expect(find.text(l10n.drillChooseHeard), findsOneWidget);

      volume.muted = false;
      await tester.pumpAndSettle();
      expect(find.text(l10n.drillRaiseVolume), findsNothing);
      expect(find.text(l10n.drillChooseHeard), findsOneWidget);
    });
  });

  group('recordings', () {
    group('playing a card', () {
      Card house({String? audio = recording}) => Card(
        id: 'zz-9001',
        deckId: 'zz-en-home',
        target: 'ఇల్లు',
        native: 'home',
        audio: audio,
      );

      test('plays its recording in place of the phone\'s voice', () async {
        final clips = FakeClipPlayer();
        final tts = FixedTtsEngine(const <String>{'te'});
        final state = AppState.test(
          tts: tts,
          clips: clips,
          media: const _At('/phone'),
        );
        addTearDown(state.dispose);
        expect(await state.speakCard(house(), testlang), isNull);
        expect(clips.played, <(String, double)>[('/phone/$recording', 1.0)]);
        expect(tts.spoken, isEmpty);
        await state.speakCard(house(), testlang, slower: true);
        expect(clips.played.last.$2, 0.7);
      });
    });
  });

  group('the speaker', () {
    group('a tap', () {
      testWidgets(
        'a tap plays the word; no speaker where the phone has no voice',
        (tester) async {
          usePhone(tester);
          final tts = FixedTtsEngine(const <String>{'es'});
          await pumpAsked(
            tester,
            skill: Skill.recognition,
            state: voiced(tts: tts),
          );
          final l10n = l10nOf(tester);
          expect(speaker, findsOneWidget);
          expect(tts.spoken, isEmpty, reason: 'not automatically, by default');

          await tester.tap(speaker);
          await tester.pumpAndSettle();
          expect(tts.spoken.single.text, 'la casa');

          await tapVisible(tester, find.text(l10n.drillShowAnswer));
          expect(speaker, findsOneWidget);
          expect(tts.spoken, hasLength(1));

          usePhone(tester);
          await pumpAsked(
            tester,
            skill: Skill.recognition,
            state: AppState.test(),
          );
          expect(speaker, findsNothing);
        },
      );
    });

    group('words played automatically', () {
      AppState autoplaying(FixedTtsEngine tts) =>
          voiced(tts: tts, settings: settingsWith((s) => s.autoplay = true));

      testWidgets(
        'no speaker until the answer is in, typed or chosen, so a word '
        'never gives its answer away',
        (tester) async {
          usePhone(tester);
          final tts = FixedTtsEngine(const <String>{'es'});
          await pumpAsked(
            tester,
            skill: Skill.production,
            state: autoplaying(tts),
          );
          final l10n = l10nOf(tester);
          expect(speaker, findsNothing);
          await tester.enterText(find.byType(TextField), 'la casa');
          await tester.pump();
          await tapVisible(tester, find.text(l10n.drillCheck));
          expect(find.text(l10n.feedbackCorrect), findsOneWidget);
          expect(speaker, findsOneWidget);
          expect(tts.spoken.single.text, 'la casa');

          {
            usePhone(tester);
            final tts = FixedTtsEngine(const <String>{'es'});
            final state = await pumpAsked(
              tester,
              skill: Skill.production,
              state: autoplaying(tts),
              ask: Ask.chooseWord,
            );
            expect(speaker, findsNothing);
            expect(tts.spoken, isEmpty);
            await tapVisible(
              tester,
              find.text(cardOf(state, spanish, 'la casa').target),
            );
            expect(speaker, findsOneWidget);
            expect(tts.spoken.single.text, 'la casa');
          }
        },
      );
    });
  });

  group('tap to hear', () {
    group('a word tile', () {
      testWidgets(
        'a word tile says its word when tapped; with sound off the button '
        'is greyed out and says why',
        (tester) async {
          usePhone(tester);
          for (final autoplay in <bool>[false, true]) {
            final tts = FixedTtsEngine(const <String>{'es'});
            await pumpMatch(
              tester,
              state: tapVoiced(
                tts: tts,
                settings: settingsWith((s) => s.autoplay = autoplay),
              ),
            );
            expect(find.byType(MatchDrill), findsOneWidget);
            expect(tts.spoken, isEmpty, reason: 'not before it is tapped');
            final pairs = pairsOf(tester);

            await tapText(tester, pairs[0].word);
            expect(tts.spoken.map((s) => s.text), <String>[
              pairs[0].word,
            ], reason: 'autoplay $autoplay');
            expect(tts.spoken.single.bcp47, startsWith('es'));

            // Every word tile does, the first tap or a later one.
            await tapText(tester, pairs[1].word);
            expect(tts.spoken.map((s) => s.text), <String>[
              pairs[0].word,
              pairs[1].word,
            ], reason: 'autoplay $autoplay');
          }

          {
            usePhone(tester);
            final semantics = tester.ensureSemantics();
            final tts = FixedTtsEngine(const <String>{'es'});
            final state = await pumpMatch(
              tester,
              state: tapVoiced(
                tts: tts,
                settings: settingsWith((s) => s.soundOn = false),
              ),
            );
            final l10n = l10nOf(tester);
            expect(toggle, findsOneWidget);
            expect(iconOf(tester), Icons.volume_off_outlined);
            final node = tester.getSemantics(toggle);
            expect(node.value, l10n.speakerMuted);
            // The setting itself is still on, and still says so.
            expect(node.label, l10n.drillMatchHearOn);

            for (final pair in pairsOf(tester)) {
              await tapText(tester, pair.word);
              await tapText(tester, pair.word);
            }
            expect(tts.spoken, isEmpty);

            await tapToggle(tester);
            expect(find.text(l10n.speakerSoundOff), findsOneWidget);
            expect(
              state.settings.matchTapToHear,
              isTrue,
              reason: 'not flipped',
            );
            expect(tts.spoken, isEmpty);
            semantics.dispose();
          }
        },
      );
    });
  });

  group('the Voices page', () {
    Future<void> tapInstall(WidgetTester tester, AppState state) async {
      usePhone(tester);
      // Tall enough for every bundled language's row and what is under them.
      tester.view.physicalSize = const Size(390 * 3, 8000 * 3);
      await pumpScreen(tester, const VoicesPage(), state: state);
      await scrollTo(tester, find.text(l10nOf(tester).voicesInstall));
      await tester.tap(find.text(l10nOf(tester).voicesInstall));
      await tester.pumpAndSettle();
    }

    void expectExplained(WidgetTester tester) {
      final l10n = l10nOf(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.voicesInstallTitle), findsOneWidget);
      expect(find.text(l10n.voicesInstallSteps), findsOneWidget);
    }

    testWidgets('the languages learned come first; Install opens the phone\'s '
        'settings, or explains how when nothing opens', (tester) async {
      usePhone(tester);
      final semantics = tester.ensureSemantics();
      final state = await pumpScreen(
        tester,
        const VoicesPage(),
        state: AppState.test(
          tts: FixedTtsEngine(const <String>{'es'}),
          settings: SettingsNotifier(
            spokenLanguages: const <String>['en'],
            learningLanguages: const <String>['es'],
          )..reviewLanguages = const <String>{'hi'},
        ),
      );
      await tester.pumpAndSettle();
      final l10n = l10nOf(tester);
      final es = _language(state, 'es');
      final hi = _language(state, 'hi');
      expect(state.languages.length, greaterThan(1));
      expect(find.byType(LanguageVoiceCard), findsOneWidget);
      expect(find.textContaining(es.name, findRichText: true), findsOneWidget);
      expect(find.textContaining(hi.name, findRichText: true), findsNothing);
      final others = find.text(l10n.voicesOtherLanguages);
      expect(others, findsOneWidget);
      expect(
        tester.getSemantics(others),
        isSemantics(hasExpandedState: true, isExpanded: false),
      );

      await tester.ensureVisible(others);
      await tester.tap(others);
      await tester.pumpAndSettle();
      expect(
        find.byType(LanguageVoiceCard, skipOffstage: false),
        findsNWidgets(_voiced(state)),
      );
      expect(
        find.textContaining(hi.name, findRichText: true, skipOffstage: false),
        findsOneWidget,
      );
      semantics.dispose();

      final phone = FixedSystemSettings();
      await tapInstall(tester, AppState.test(systemSettings: phone));
      expect(phone.voiceSettingsAsked, 1);
      expect(find.byType(AlertDialog), findsNothing);

      {
        final phone = FixedSystemSettings(opens: VoiceSettingsPage.none);
        await tapInstall(tester, AppState.test(systemSettings: phone));
        expect(phone.voiceSettingsAsked, 1);
        expectExplained(tester);
        await tester.tap(find.text(l10nOf(tester).commonGotIt));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
    });
  });

  group('voice cards', () {
    testWidgets('one card per language, the languages learned first; a voice '
        'removed since it was chosen falls back to the default', (
      tester,
    ) async {
      _useTallPhone(tester);
      final state = await _speaking(FixedSpeechEngine(onDevice: {'hi', 'es'}));
      state.settings.learningLanguages = const <String>['te'];
      await pumpScreen(tester, const VoicesPage(), state: state);
      final l10n = l10nOf(tester);
      // Only Telugu, learned, until the other languages are unfolded (#463).
      expect(find.byType(LanguageVoiceCard), findsOneWidget);
      await _tap(tester, find.text(l10n.voicesOtherLanguages));
      // The IPA has no voice of its own, so it has no card (ADR-0041).
      final voiced = state.languages.where((l) => !l.isIpa).length;
      final cards = tester.widgetList<LanguageVoiceCard>(
        find.byType(LanguageVoiceCard),
      );
      expect(cards, hasLength(voiced));
      expect(cards.first.language.code, 'te');
      // A course's other voices, such as ur-PK beside hi-IN, list too (#641).
      final otherVoices = <LanguageInfo>[
        for (final l in state.languages)
          if (!l.isIpa)
            for (final block in state.voiceBlocksOf(l.code))
              if (block.ttsTag != l.ttsTag) block,
      ].length;
      expect(
        find.text(l10n.voicesListening),
        findsNWidgets(voiced + otherVoices),
      );
      expect(find.text(l10n.voicesSpeakingPart), findsNWidgets(voiced));
      // No second list for speech below the voices.
      expect(find.text('Recognising your speech'), findsNothing);
      final hindi = _card('Hindustani');
      expect(
        find.descendant(of: hindi, matching: find.text(l10n.voicesPlay)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hindi, matching: find.text(l10n.voicesSay)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: hindi,
          matching: find.text(l10n.voicesSpeechOnDevice),
        ),
        findsOneWidget,
      );
      // Without a voice, Install a voice in place of Play.
      final telugu = _card('Telugu');
      expect(
        find.descendant(of: telugu, matching: find.text(l10n.voicesInstallOne)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: telugu, matching: find.text(l10n.voicesPlay)),
        findsNothing,
      );

      {
        _useTallPhone(tester);
        final tts = FixedTtsEngine(const <String>{'es'});
        final state = AppState.test(tts: tts);
        state.settings.chooseVoice('es', 'a-voice-since-removed');
        await pumpScreen(tester, const VoicesPage(), state: state);
        final l10n = l10nOf(tester);
        expect(find.text(l10n.voicesVoice), findsNothing);
        await _tap(tester, find.text(l10n.voicesPlay));
        expect(tts.spoken.single.voice, isNull);
      }
    });

    group('a rude word is never offered to say or played', () {
      test('a rude word is never offered to say, nor played', () async {
        final state = await reviewState();
        addTearDown(state.dispose);
        final telugu = _language(state, 'te');
        final words = speechTestWords(state, telugu).map((c) => c.id);
        expect(words, isNot(contains(rudeCard)));
        expect(words, containsAll(<String>[alikeCard, plainCard]));

        {
          // With no path, the decks come in the order of their files, and the
          // rude deck's sorts before the words'.
          final state = AppState.test(
            decks: MemoryDeckSource(
              reviewCourse()..remove('decks/te/te-path.yaml'),
            ),
          );
          addTearDown(state.dispose);
          await state.load();
          final telugu = _language(state, 'te');
          expect(
            state.decks.where((d) => d.language.code == 'te').first.id,
            rudeDeck,
          );
          expect(VoicesPage.sampleFor(state, telugu), 'విధవ');
        }
      });
    });
  });

  group('voice apps', () {
    testWidgets('a course lists every voice it uses, says the backup, suggests '
        'a download and lists the voice apps', (tester) async {
      _useTallPhone(tester);
      final state = _state(_NamedTts(<String>{'hi-in'}));
      await pumpScreen(tester, VoicesPage(apps: _apps), state: state);
      final l10n = l10nOf(tester);
      final card = _hindustani();

      expect(
        find.descendant(
          of: card,
          matching: find.text(l10n.voicesInUseAutomatic('hi-IN')),
        ),
        findsOneWidget,
        reason: 'hi-IN is installed and in use',
      );
      // ur-PK is listed too, with the voice that stands in for it.
      expect(
        find.descendant(
          of: card,
          matching: find.text(l10n.deckVoiceBackup('ur-PK', 'hi-IN')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(l10n.voicesDownloadHint)),
        findsOneWidget,
      );
      // Open where a voice is missing, with the apps that cover the course.
      for (final name in <String>['eSpeak NG', 'Google Speech Services']) {
        expect(
          find.descendant(of: card, matching: find.text(name)),
          findsOneWidget,
          reason: name,
        );
      }
    });
  });
}
