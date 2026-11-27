// Fixtures for the achievements screens' tests (#323, #324): real reports from
// the engine over the in-memory course of `achievement_fixture.dart`, and
// plain results for the sheets.

import 'package:fluenough/core/achievements/achievement.dart';
import 'package:fluenough/core/achievements/achievement_evaluator.dart';
import 'package:fluenough/core/achievements/achievement_facts.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';

import 'achievement_fixture.dart';

/// Day 0 of the fixture logs.
final DateTime screensStart = DateTime.utc(2026, 3, 2);

/// The report of a course learned up to its A1 mark, one card a day, every
/// card known the day after its first answer: A1 earned, A2 and the 100
/// words in progress, a streak of more than 30 days, and the first lesson.
AchievementReport learnedToA1({AchievementFacts? facts}) {
  final course = facts ?? courseFacts();
  final log = FixtureLog(screensStart);
  var day = 0;
  for (final id in course.cardIdsUpTo(20)) {
    if (id.startsWith('zz-q')) {
      log.answer(id, log.day(day), mode: DrillMode.reading);
    } else {
      log.know(id, day);
    }
    day++;
  }
  return evaluateAchievements(log: log.events, facts: course);
}

/// The report of a course nothing has been answered in.
AchievementReport untouched({AchievementFacts? facts}) => evaluateAchievements(
  log: FixtureLog(screensStart).events,
  facts: facts ?? courseFacts(),
);

/// The app-wide badges alone: a language with no decks loaded.
AchievementReport appOnly() => evaluateAchievements(log: const []);

/// An earned result of [def], dated [at].
AchievementResult earned(AchievementDef def, DateTime at, {int need = 10}) =>
    AchievementResult(
      def: def,
      status: AchievementStatus.earned,
      have: need,
      need: need,
      earnedAt: at,
    );

/// A result of [def] that has got [have] of [need] of the way.
AchievementResult inProgress(
  AchievementDef def,
  int have,
  int need, {
  List<String> cards = const <String>[],
}) => AchievementResult(
  def: def,
  status: AchievementStatus.inProgress,
  have: have,
  need: need,
  cards: cards,
);

/// A result of [def] that has not been started.
AchievementResult locked(AchievementDef def, {int need = 10}) =>
    AchievementResult(
      def: def,
      status: AchievementStatus.locked,
      have: 0,
      need: need,
    );

/// A Hindustani card in Devanagari, for the sheets.
const Card hindiCard = Card(
  id: 'hi-9001',
  deckId: 'hi-core',
  target: 'मैं',
  native: 'I',
  reading: 'main',
);

/// A second Hindustani card.
const Card hindiCardTwo = Card(
  id: 'hi-9002',
  deckId: 'hi-core',
  target: 'तुम',
  native: 'you',
  reading: 'tum',
);

/// A Bengali card.
const Card bengaliCard = Card(
  id: 'bn-9001',
  deckId: 'bn-core',
  target: 'আমি',
  native: 'I',
  reading: 'āmi',
);

/// A Bengali card, second.
const Card bengaliCardTwo = Card(
  id: 'bn-9002',
  deckId: 'bn-core',
  target: 'তুমি',
  native: 'you',
  reading: 'tumi',
);

/// A Bengali card, third.
const Card bengaliCardThree = Card(
  id: 'bn-9003',
  deckId: 'bn-core',
  target: 'আপনি',
  native: 'you (formal)',
  reading: 'āpni',
);

/// An Urdu card, in the Perso-Arabic script, which runs right to left.
const Card urduCard = Card(
  id: 'ur-9001',
  deckId: 'ur-core',
  target: 'میں',
  native: 'I',
  reading: 'main',
);

const LanguageInfo hindustani = LanguageInfo(
  code: 'hi',
  iso639_3: 'hin',
  name: 'Hindustani',
  script: 'devanagari',
);

const LanguageInfo bengali = LanguageInfo(
  code: 'bn',
  iso639_3: 'ben',
  name: 'Bengali',
  script: 'bengali',
);

const LanguageInfo urdu = LanguageInfo(
  code: 'ur',
  iso639_3: 'urd',
  name: 'Urdu',
  script: 'perso_arabic',
  rtl: true,
);
