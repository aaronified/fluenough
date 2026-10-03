import 'dart:math';

import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/memory_progress.dart';
import '../../app/profile.dart';
import '../../app/session.dart';
import '../../app/settings.dart';
import '../../app/skill.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../core/speech/speech_engine.dart';
import '../../core/tts/fixed_tts_engine.dart';
import '../../core/updates/apk_install.dart';
import '../../core/updates/release_check.dart';

/// Fixture data for the debug gallery, and for widget tests that want the
/// design's people and a history to show.
///
/// Everything is built on the real bundled decks: no invented card ids ever
/// appear (AGENTS.md rule 1).
abstract final class GalleryFixtures {
  /// The design's first profile: PIN 1234.
  static const Profile aro = Profile(
    id: 'aro',
    name: 'Aro',
    languages: <String>{'hi', 'es'},
    shape: AvatarShape.cookie,
    tone: AvatarTone.primary,
    pin: '1234',
  );

  /// The design's second profile: Japanese, no PIN.
  static const Profile mira = Profile(
    id: 'mira',
    name: 'Mira',
    languages: <String>{'ja'},
    shape: AvatarShape.clover,
    tone: AvatarTone.tertiary,
  );

  /// A state on [app]'s already-loaded catalog, with voices for [voices]
  /// (Hindi and Spanish, as in the design; Japanese has none), the design's
  /// two profiles with [currentProfileId] current, and — unless [history] is
  /// false — twelve days of reviews, so there is a streak, cards due and a
  /// leech. The update check answers from [releases], never from GitHub,
  /// and an update installs through [installer], never for real.
  ///
  /// Call `load()` on the result before showing it; the gallery does.
  static AppState state(
    AppState app, {
    Set<String> voices = const <String>{'hi', 'es'},
    List<Profile> profiles = const <Profile>[aro, mira],
    String currentProfileId = 'aro',
    FeatureRegistry features = const FeatureRegistry.shipped(),
    bool history = true,
    SettingsNotifier? settings,
    SpeechEngine speech = const NullSpeechEngine(),
    ReleaseCheckEngine releases = const NullReleaseCheck(),
    ApkInstaller installer = const NullApkInstaller(),
  }) {
    final progress = MemoryProgress();
    if (history) seedHistory(progress, app.decks, app.now());
    return AppState(
      catalog: app.deckCatalog,
      progress: progress,
      tts: FixedTtsEngine(voices),
      speech: speech,
      features: features,
      clock: app.now,
      releases: releases,
      installer: installer,
      settings: settings,
      profiles: profiles,
      currentProfileId: currentProfileId,
      // The same order of options in every screenshot.
      random: Random(0),
    );
  }

  /// The decks the design's history is drawn on. Only these get history,
  /// so the gallery's numbers stay the same as content decks are added.
  static const Set<String> historyDecks = <String>{
    'es-en-core-100',
    'ja-en-hiragana',
  };

  /// Twelve days of reviews ending yesterday, on the first cards of each of
  /// [historyDecks]: a 12-day streak, those cards due today, and one card
  /// forgotten five times over, a leech at #19's default threshold.
  static void seedHistory(
    MemoryProgress progress,
    List<DeckEntry> decks,
    DateTime now,
  ) {
    final today = dateOnly(now);
    final events =
        <
          ({DateTime at, String deck, String card, DrillMode mode, int grade})
        >[];
    for (final entry in decks) {
      final cards = entry.cards;
      // Grammar cards are drilled in their own mode, which the fixture's
      // history does not use.
      if (cards.isEmpty ||
          entry.deck.kind == DeckKind.grammar ||
          !historyDecks.contains(entry.id)) {
        continue;
      }
      for (var day = 12; day >= 1; day--) {
        final at = addDays(today, -day).add(const Duration(hours: 18));
        final i = (12 - day) % cards.length;
        events.add((
          at: at,
          deck: entry.id,
          card: cards[i].id,
          mode: DrillMode.recognition,
          grade: 4,
        ));
      }
      if (cards.length > 12) {
        final leech = cards[12];
        for (var day = 10; day >= 1; day--) {
          events.add((
            at: addDays(today, -day).add(const Duration(hours: 19)),
            deck: entry.id,
            card: leech.id,
            mode: DrillMode.production,
            grade: day.isEven ? 4 : 1,
          ));
        }
      }
    }
    events.sort((a, b) => a.at.compareTo(b.at));
    for (final e in events) {
      progress.record(
        deckId: e.deck,
        cardId: e.card,
        mode: e.mode,
        grade: e.grade,
        now: e.at,
      );
    }
  }

  /// The design's summary: seven answers over four minutes, six correct.
  static SessionResult sessionResult(DateTime now) {
    SessionAnswer a(Skill skill, bool ok) =>
        SessionAnswer(skill: skill, grade: ok ? 4 : 1);
    return SessionResult(
      answers: <SessionAnswer>[
        a(Skill.recognition, true),
        a(Skill.production, true),
        a(Skill.production, true),
        a(Skill.listening, false),
        a(Skill.grammar, true),
        a(Skill.pair, true),
        a(Skill.recognition, true),
      ],
      startedAt: now.subtract(const Duration(minutes: 4)),
      endedAt: now,
    );
  }
}
