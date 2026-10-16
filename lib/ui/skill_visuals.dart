import 'package:flutter/material.dart';

import '../app/skill.dart';
import '../l10n/app_localizations.dart';

/// How a [Skill] looks and is named, the same on every screen.
///
/// The design's Tabler icons map onto Material ones: an eye for recognition, a
/// keyboard for production, an ear for listening, a microphone for speaking,
/// a letter form for grammar, an open book for reading, headphones for
/// minimal pairs. Colours are in
/// `ModeColors`.
extension SkillVisuals on Skill {
  IconData get icon => switch (this) {
    Skill.recognition => Icons.visibility_outlined,
    Skill.production => Icons.keyboard_outlined,
    Skill.listening => Icons.hearing,
    Skill.speaking => Icons.mic_none,
    Skill.grammar => Icons.text_fields,
    Skill.reading => Icons.menu_book_outlined,
    Skill.pair => Icons.headphones_outlined,
  };

  /// "Recognition", "Minimal pairs"…
  String label(AppLocalizations l10n) => switch (this) {
    Skill.recognition => l10n.skillRecognition,
    Skill.production => l10n.skillProduction,
    Skill.listening => l10n.skillListening,
    Skill.speaking => l10n.skillSpeaking,
    Skill.grammar => l10n.skillGrammar,
    Skill.reading => l10n.skillReading,
    Skill.pair => l10n.skillPair,
  };

  /// A skill's title on its switch in Settings, in the learner's words
  /// (docs/plans/settings-wording.md): "Seen words", "Written words",
  /// "Heard words", "Spoken words"; grammar and reading keep their [label];
  /// minimal pairs is "Phonemic contrasts", practice with the sounds the
  /// learner's own languages do not have. Decks and pills keep [label].
  String settingsLabel(AppLocalizations l10n) => switch (this) {
    Skill.recognition => l10n.skillRecognitionSettingsTitle,
    Skill.production => l10n.skillProductionSettingsTitle,
    Skill.listening => l10n.skillListeningSettingsTitle,
    Skill.speaking => l10n.skillSpeakingSettingsTitle,
    Skill.pair => l10n.skillPairSettingsTitle,
    Skill.grammar || Skill.reading => label(l10n),
  };

  /// The line under a skill on a deck's screen. [language] is the deck's
  /// language name, from the deck file.
  String deckDescription(AppLocalizations l10n, String language) =>
      switch (this) {
        Skill.recognition => l10n.skillRecognitionDeckDesc(language),
        Skill.production => l10n.skillProductionDeckDesc(language),
        Skill.listening => l10n.skillListeningDeckDesc,
        Skill.speaking => l10n.skillSpeakingDeckDesc(language),
        Skill.grammar => l10n.skillGrammarDeckDesc,
        Skill.reading => l10n.skillReadingDeckDesc,
        Skill.pair => l10n.skillPairDeckDesc,
      };

  /// The line under a skill's switch in Settings while it is on: what the
  /// learner is asked.
  String settingsOn(AppLocalizations l10n) => switch (this) {
    Skill.recognition => l10n.skillRecognitionSettingsOn,
    Skill.production => l10n.skillProductionSettingsOn,
    Skill.listening => l10n.skillListeningSettingsOn,
    Skill.speaking => l10n.skillSpeakingSettingsOn,
    Skill.grammar => l10n.skillGrammarSettingsOn,
    Skill.reading => l10n.skillReadingSettingsOn,
    Skill.pair => l10n.skillPairSettingsOn,
  };

  /// The line under a skill's switch in Settings while it is off: what is
  /// no longer asked.
  String settingsOff(AppLocalizations l10n) => switch (this) {
    Skill.recognition => l10n.skillRecognitionSettingsOff,
    Skill.production => l10n.skillProductionSettingsOff,
    Skill.listening => l10n.skillListeningSettingsOff,
    Skill.speaking => l10n.skillSpeakingSettingsOff,
    Skill.grammar => l10n.skillGrammarSettingsOff,
    Skill.reading => l10n.skillReadingSettingsOff,
    Skill.pair => l10n.skillPairSettingsOff,
  };
}
