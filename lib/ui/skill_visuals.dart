import 'package:flutter/material.dart';

import '../app/skill.dart';
import '../l10n/app_localizations.dart';

/// How a [Skill] looks and is named, the same on every screen.
///
/// The design's Tabler icons map onto Material ones: an eye for recognition, a
/// keyboard for production, an ear for listening, a microphone for speaking,
/// a letter form for grammar, headphones for minimal pairs. Colours are in
/// `ModeColors`.
extension SkillVisuals on Skill {
  IconData get icon => switch (this) {
    Skill.recognition => Icons.visibility_outlined,
    Skill.production => Icons.keyboard_outlined,
    Skill.listening => Icons.hearing,
    Skill.speaking => Icons.mic_none,
    Skill.grammar => Icons.text_fields,
    Skill.pair => Icons.headphones_outlined,
  };

  /// "Recognition", "Minimal pairs"…
  String label(AppLocalizations l10n) => switch (this) {
    Skill.recognition => l10n.skillRecognition,
    Skill.production => l10n.skillProduction,
    Skill.listening => l10n.skillListening,
    Skill.speaking => l10n.skillSpeaking,
    Skill.grammar => l10n.skillGrammar,
    Skill.pair => l10n.skillPair,
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
        Skill.pair => l10n.skillPairDeckDesc,
      };

  /// The line under a skill's switch in Settings.
  String settingsDescription(AppLocalizations l10n) => switch (this) {
    Skill.recognition => l10n.skillRecognitionSettingsDesc,
    Skill.production => l10n.skillProductionSettingsDesc,
    Skill.listening => l10n.skillListeningSettingsDesc,
    Skill.speaking => l10n.skillSpeakingSettingsDesc,
    Skill.grammar => l10n.skillGrammarSettingsDesc,
    Skill.pair => l10n.skillPairSettingsDesc,
  };
}
