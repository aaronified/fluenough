import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/achievements/achievement.dart';
import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import '../languages/skill_widgets.dart';
import '../stats/progress_tiles.dart' show LevelTile;

/// The words and icons of a badge (#323): its name, how it is earned and the
/// line that announces it, from the app's strings. Only the strings are
/// English until #46; a card's words are the course's own and are drawn by
/// the sheet.
extension AchievementTexts on AchievementDef {
  /// The name under the badge's icon: `100 words`, `Start`, `Family`.
  String name(AppLocalizations l10n) => switch (kind) {
    AchievementKind.level => LevelTile.levelName(l10n, level!),
    AchievementKind.wordCount => l10n.achvWords(_count(l10n, target)),
    AchievementKind.skillStart => l10n.achvStart,
    AchievementKind.skillMaster => l10n.achvMaster,
    AchievementKind.deckSet => _setName(l10n, setId!, full: false),
    AchievementKind.other => switch (other!) {
      AchievementOther.firstLesson => l10n.achvFirstLesson,
      AchievementOther.streak => l10n.achvDays(_count(l10n, target)),
      AchievementOther.answers => l10n.achvAnswersName(_count(l10n, target)),
    },
  };

  /// The name on its sheet and in a screen reader's label: `Read · Master`,
  /// `Family words`.
  String fullName(AppLocalizations l10n) => switch (kind) {
    AchievementKind.skillStart => l10n.achvSkillFull(
      skill!.kind.label(l10n),
      l10n.achvStart,
    ),
    AchievementKind.skillMaster => l10n.achvSkillFull(
      skill!.kind.label(l10n),
      l10n.achvMaster,
    ),
    AchievementKind.deckSet => _setName(l10n, setId!, full: true),
    _ => name(l10n),
  };

  /// How the badge is earned, in one sentence.
  String how(AppLocalizations l10n) => switch (kind) {
    AchievementKind.level => l10n.achvHowLevel(
      LevelTile.levelName(l10n, level!),
    ),
    AchievementKind.wordCount => l10n.achvHowWords(_count(l10n, target)),
    AchievementKind.skillStart => switch (skill!.kind) {
      SkillKind.hear => l10n.achvHowHearStart,
      SkillKind.speak => l10n.achvHowSpeakStart,
      SkillKind.read => l10n.achvHowReadStart,
      SkillKind.write => l10n.achvHowWriteStart,
      SkillKind.gesture => l10n.achvHowGestureStart,
    },
    AchievementKind.skillMaster => switch (skill!.kind) {
      SkillKind.hear => l10n.achvHowHearMaster,
      SkillKind.speak => l10n.achvHowSpeakMaster,
      SkillKind.read => l10n.achvHowReadMaster,
      SkillKind.write => l10n.achvHowWriteMaster,
      SkillKind.gesture => l10n.achvHowGestureMaster,
    },
    AchievementKind.deckSet => l10n.achvHowSet(
      _setName(l10n, setId!, full: true).toLowerCase(),
    ),
    AchievementKind.other => switch (other!) {
      AchievementOther.firstLesson => l10n.achvHowFirstLesson,
      AchievementOther.streak => l10n.achvHowDays(_count(l10n, target)),
      AchievementOther.answers => l10n.achvHowAnswers(_count(l10n, target)),
    },
  };

  /// The line that announces the badge once earned: "You now know 100
  /// words." [cards] is the number of cards a set asks for.
  String done(AppLocalizations l10n, {required int cards}) => switch (kind) {
    AchievementKind.level => l10n.achvDoneLevel(
      LevelTile.levelName(l10n, level!),
    ),
    AchievementKind.wordCount => l10n.achvDoneWords(_count(l10n, target)),
    AchievementKind.skillStart => how(l10n),
    AchievementKind.skillMaster => how(l10n),
    AchievementKind.deckSet => l10n.achvDoneSet(
      _count(l10n, cards),
      _setName(l10n, setId!, full: true).toLowerCase(),
    ),
    AchievementKind.other => switch (other!) {
      AchievementOther.firstLesson => l10n.achvDoneFirstLesson,
      AchievementOther.streak => l10n.achvDoneDays(_count(l10n, target)),
      AchievementOther.answers => l10n.achvDoneAnswers(_count(l10n, target)),
    },
  };

  /// The icon of a badge that is not a level.
  IconData get icon => switch (kind) {
    AchievementKind.level => Icons.emoji_events_outlined,
    AchievementKind.wordCount => Icons.menu_book,
    AchievementKind.skillStart => skill!.kind.icon,
    AchievementKind.skillMaster => skill!.kind.icon,
    AchievementKind.deckSet => _setIcon(setId!, grammarSet),
    AchievementKind.other => switch (other!) {
      AchievementOther.firstLesson => Icons.check,
      AchievementOther.streak => Icons.local_fire_department,
      AchievementOther.answers => Icons.star,
    },
  };
}

/// [n] as the learner's locale writes it: `1,000`.
String _count(AppLocalizations l10n, int n) =>
    NumberFormat.decimalPattern(l10n.localeName).format(n);

/// A count as text, for the tests and the other widgets of this feature.
String achievementCount(AppLocalizations l10n, int n) => _count(l10n, n);

/// [at] as a date in the learner's locale, in their own time zone.
String achievementDate(AppLocalizations l10n, DateTime at) =>
    DateFormat.yMMMd(l10n.localeName).format(at.toLocal());

/// The ids a path file may spell a set with, besides the ones named here.
const Map<String, String> _setAliases = <String, String>{
  'numbers': 'numbers-1-20',
  'past-tense': 'past',
  'future-tense': 'future',
  'noun-forms': 'nouns',
  'relative-clauses': 'relative',
  'conditional-clauses': 'conditional',
  'purpose-clauses': 'purpose',
  'causative-verbs': 'causative',
  'indefinite-words': 'indefinite',
  'concessive-clauses': 'concessive',
};

String _setName(AppLocalizations l10n, String id, {required bool full}) {
  final known = _setAliases[id] ?? id;
  final name = full ? _fullSetName(l10n, known) : _shortSetName(l10n, known);
  if (name != null) return name;
  // A set the app has no name for: its id, as words.
  final words = id.replaceAll('-', ' ');
  return words.isEmpty ? id : '${words[0].toUpperCase()}${words.substring(1)}';
}

String? _shortSetName(AppLocalizations l10n, String id) => switch (id) {
  'pronouns' => l10n.achvSetPronouns,
  'family' => l10n.achvSetFamily,
  'numbers-1-20' => l10n.achvSetNumbers120,
  'food' => l10n.achvSetFood,
  'festivals' => l10n.achvSetFestivals,
  'nouns' => l10n.achvSetNouns,
  'past' => l10n.achvSetPast,
  'future' => l10n.achvSetFuture,
  'relative' => l10n.achvSetRelative,
  'conditional' => l10n.achvSetConditional,
  'purpose' => l10n.achvSetPurpose,
  'causative' => l10n.achvSetCausative,
  'indefinite' => l10n.achvSetIndefinite,
  'passive' => l10n.achvSetPassive,
  'compound-verbs' => l10n.achvSetCompoundVerbs,
  'comparison' => l10n.achvSetComparison,
  'imperatives' => l10n.achvSetImperatives,
  'before-after' => l10n.achvSetBeforeAfter,
  'concessive' => l10n.achvSetConcessive,
  'reported-speech' => l10n.achvSetReportedSpeech,
  _ => null,
};

String? _fullSetName(AppLocalizations l10n, String id) => switch (id) {
  'pronouns' => l10n.achvSetPronounsFull,
  'family' => l10n.achvSetFamilyFull,
  'numbers-1-20' => l10n.achvSetNumbers120Full,
  'food' => l10n.achvSetFoodFull,
  'festivals' => l10n.achvSetFestivalsFull,
  'nouns' => l10n.achvSetNounsFull,
  'past' => l10n.achvSetPastFull,
  'future' => l10n.achvSetFutureFull,
  'relative' => l10n.achvSetRelativeFull,
  'conditional' => l10n.achvSetConditionalFull,
  'purpose' => l10n.achvSetPurposeFull,
  'causative' => l10n.achvSetCausativeFull,
  'indefinite' => l10n.achvSetIndefiniteFull,
  'passive' => l10n.achvSetPassiveFull,
  'compound-verbs' => l10n.achvSetCompoundVerbsFull,
  'comparison' => l10n.achvSetComparisonFull,
  'imperatives' => l10n.achvSetImperativesFull,
  'before-after' => l10n.achvSetBeforeAfterFull,
  'concessive' => l10n.achvSetConcessiveFull,
  'reported-speech' => l10n.achvSetReportedSpeechFull,
  _ => null,
};

IconData _setIcon(String id, bool grammar) {
  if (grammar) return Icons.notes;
  return switch (_setAliases[id] ?? id) {
    'pronouns' => Icons.people,
    'family' => Icons.people,
    'numbers-1-20' => Icons.numbers,
    'food' => Icons.restaurant,
    'festivals' => Icons.star,
    _ => Icons.translate,
  };
}
