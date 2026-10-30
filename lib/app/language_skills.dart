import '../core/data/spoken_languages.dart';
import '../core/languages/language_skills.dart';
import 'app_state.dart';

/// What the Languages page reads and writes of the app (#907): each
/// language's skills, kept in Settings, and the older lists they stay in
/// step with, so that everything that reads "languages learned" or "languages
/// known" goes on working.
extension LanguageSkillsOnState on AppState {
  /// The scripts [language] has skills for, as decks name them: its own
  /// first; `latin` where the list names none.
  List<String> skillScripts(SpokenLanguage language) =>
      language.scripts.isEmpty ? const <String>['latin'] : language.scripts;

  /// The rows of [language]'s skills.
  List<SkillKey> skillShape(SpokenLanguage language) =>
      skillsOfLanguage(skillScripts(language), scriptOnly: language.scriptOnly);

  /// Where [script] of [language] is kept in `scripts_read`.
  String _readKey(SpokenLanguage language, String script) =>
      language.scripts.isEmpty ? language.code : language.readKey(script);

  /// What the learner said about [language]'s skills: what they set on the
  /// Languages page, else the older lists read as skills, so that nobody
  /// sees a change before they edit.
  LanguageSkills skillsOf(SpokenLanguage language) {
    final stored = settings.languageSkillsOf(language.code);
    if (stored != null) return LanguageSkills.fromStored(stored);
    final code = language.code;
    final read = language.scriptsReadIn(settings.scriptsRead);
    return skillsFromLegacy(
      scripts: skillScripts(language),
      learned: learningCodes.contains(code) && settings.learningChosen,
      known: settings.spokenLanguages.contains(code),
      learnedScripts: settings.scriptsLearned(
        code,
        primary: primaryScript(code),
      ),
      readsScript: (s) =>
          read?.contains(language.scripts.isEmpty ? '' : s) ?? false,
      scriptOnly: language.scriptOnly,
    );
  }

  /// Whether a level was found for [code] (placement credited its words).
  bool levelFound(String code) => settings.placedAtOf(code).isNotEmpty;

  /// Saves [next] as [language]'s skills and brings the older lists in step:
  /// a language with a Learn skill is learned, in the scripts whose Read or
  /// Write is Learn; one with Speak or Hear known is spoken; Read known is
  /// a script read. A language with every skill Leave is back in the pool.
  void applySkills(SpokenLanguage language, LanguageSkills next) {
    final code = language.code;
    settings.setLanguageSkills(code, next.toStored());

    // Learned.
    final learning = learningCodes;
    if (next.anyLearn) {
      if (!learning.contains(code)) {
        setLearningLanguages(<String>[...learning, code]);
      }
      settings.learningChosen = true;
      settings.setScriptsLearned(code, next.scriptsIn(SkillState.learn));
    } else if (learning.contains(code)) {
      setLearningLanguages(<String>[
        for (final c in learning)
          if (c != code) c,
      ]);
    }

    // Spoken, and the scripts read. The list is never left empty: that is
    // what sends a first launch to the setup screen.
    final spoken = <String>[...settings.spokenLanguages];
    final speaks =
        next.stateOf(const SkillKey(SkillKind.speak)) == SkillState.know ||
        next.stateOf(const SkillKey(SkillKind.hear)) == SkillState.know;
    final reads = next.scriptsIn(
      SkillState.know,
      kinds: const <SkillKind>{SkillKind.read},
    );
    final answers = Map<String, bool>.of(settings.scriptsRead);
    if (speaks || reads.isNotEmpty) {
      if (!spoken.contains(code)) spoken.add(code);
      for (final script in skillScripts(language)) {
        answers[_readKey(language, script)] = reads.contains(script);
      }
    } else if (spoken.contains(code) && spoken.length > 1) {
      spoken.remove(code);
      answers.removeWhere((key, _) => readKeyLanguage(key) == code);
    }
    settings.spokenLanguages = spoken;
    settings.scriptsRead = answers;
  }

  /// At an app open: removes the decks of every language the Languages page
  /// edited and left with no Learn skill. Know needs no decks, and a
  /// language back in the pool needs none either; progress stays in the
  /// review log, by card id. A language never edited there is untouched.
  Future<void> removeUnneededDecks() async {
    final downloads = deckDownloads;
    if (downloads == null) return;
    for (final code in settings.languagesWithSkills.toList()) {
      final skills = LanguageSkills.fromStored(
        settings.languageSkillsOf(code) ?? const <String, String>{},
      );
      if (skills.anyLearn) continue;
      if (downloads.hasDecks(code)) await downloads.remove(code);
      if (skills.isAllLeave) settings.setLanguageSkills(code, null);
    }
  }
}
