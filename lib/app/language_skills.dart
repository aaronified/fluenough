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
    final code = language.code;
    final stored = settings.languageSkillsOf(code);
    if (stored != null) {
      // Skills are kept for the whole app, the learned lists per profile: a
      // profile whose own list disagrees with the stored Learn (another
      // profile edited it) reads its own list instead.
      final skills = LanguageSkills.fromStored(stored);
      if (skills.anyLearn == learningCodes.contains(code)) return skills;
    }
    final read = language.scriptsReadIn(settings.scriptsRead);
    final legacy = skillsFromLegacy(
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
    // English is known in every skill until the learner says otherwise
    // (#926); and the Latin script is known for everyone.
    if (code == 'en' && legacy.isAllLeave) return englishKnownByDefault();
    return withLatinKnown(legacy, skillScripts(language));
  }

  /// Makes English known in all four skills for a learner who has no entry
  /// for it (#926): an install from before, or one just set up. The older
  /// lists follow, so that everything reading "languages known" sees it.
  /// English goes last: the languages are in the learner's order. A choice
  /// made on the Languages page is an entry, and is kept, even all Leave. A
  /// first launch (no spoken language yet) is left to the setup, which calls
  /// this after it has saved the answers.
  void ensureEnglishKnown() {
    if (settings.spokenLanguages.isEmpty) return;
    if (settings.languageSkillsOf('en') != null) return;
    if (learningCodes.contains('en')) return;
    settings.setLanguageSkills('en', englishKnownByDefault().toStored());
    final spoken = settings.spokenLanguages;
    if (!spoken.contains('en')) {
      settings.spokenLanguages = <String>[...spoken, 'en'];
    }
    if (settings.scriptsRead['en'] != true) {
      settings.scriptsRead = <String, bool>{
        ...settings.scriptsRead,
        'en': true,
      };
    }
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
    } else if (spoken.contains(code)) {
      // The sole spoken language stays listed, but reads nothing, as the
      // page (back in the pool) says.
      for (final script in skillScripts(language)) {
        answers[_readKey(language, script)] = false;
      }
    }
    settings.spokenLanguages = spoken;
    settings.scriptsRead = answers;
  }

  /// Whether any profile learns [code], by its own list or the one a profile
  /// without its own follows.
  bool _anyProfileLearns(String code) {
    if (learningCodes.contains(code)) return true;
    for (final profile in profiles) {
      if ((profile.languages ?? settings.learningLanguages).contains(code)) {
        return true;
      }
    }
    return false;
  }

  /// At an app open: removes the decks of every language the Languages page
  /// edited and left with no Learn skill. Know needs no decks, and a
  /// language back in the pool needs none either; progress stays in the
  /// review log, by card id. A language never edited there is untouched.
  Future<void> removeUnneededDecks() async {
    final downloads = deckDownloads;
    if (downloads == null) return;
    for (final code in settings.languagesWithSkills.toList()) {
      final stored =
          settings.languageSkillsOf(code) ?? const <String, String>{};
      final skills = LanguageSkills.fromStored(stored);
      if (skills.anyLearn) continue;
      // An entry that holds keys but reads as nothing is unreadable, not
      // Leave: keep it and its decks.
      if (skills.isAllLeave && stored.isNotEmpty) continue;
      // Skills are kept for the whole app: another profile that still learns
      // the language keeps its decks.
      if (_anyProfileLearns(code)) continue;
      if (downloads.hasDecks(code)) await downloads.remove(code);
      // English's Leave is the learner's choice, kept: forgetting it would
      // make English known again (#926).
      if (skills.isAllLeave && code != 'en') {
        settings.setLanguageSkills(code, null);
      }
    }
  }
}
