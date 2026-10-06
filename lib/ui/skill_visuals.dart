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

  /// A skill's title on its switch in Settings: [label] for every skill but
  /// minimal pairs, which Settings calls "Phonemic contrasts". What the
  /// switch turns on is the learning of sounds that change a word's meaning,
  /// not the minimal-pairs drill's own name, which stays on decks and pills.
  String settingsLabel(AppLocalizations l10n) => switch (this) {
    Skill.pair => l10n.skillPairSettingsTitle,
    _ => label(l10n),
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

  /// The line under a skill's switch in Settings.
  String settingsDescription(AppLocalizations l10n) => switch (this) {
    Skill.recognition => l10n.skillRecognitionSettingsDesc,
    Skill.production => l10n.skillProductionSettingsDesc,
    Skill.listening => l10n.skillListeningSettingsDesc,
    Skill.speaking => l10n.skillSpeakingSettingsDesc,
    Skill.grammar => l10n.skillGrammarSettingsDesc,
    Skill.reading => l10n.skillReadingSettingsDesc,
    Skill.pair => l10n.skillPairSettingsDesc,
  };
}
