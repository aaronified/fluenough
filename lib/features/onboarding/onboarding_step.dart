import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/app_state.dart';
import '../../app/language_skills.dart';
import '../../app/skill.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/languages/language_skills.dart';
import '../../core/sound/sound_check.dart';
import '../../l10n/app_localizations.dart';

/// One screen of the first launch (#118). `OnboardingFlow` draws the top
/// bar, the slot above the button and the button; a step draws only its
/// content, between them.
///
/// To add a step, define one in its own file and add it to
/// `onboardingSteps`. A question (`asks: true`) gets "Next", Back, the
/// question progress bar and "Continue" when it is last, for free.
@immutable
class OnboardingStep {
  const OnboardingStep({
    required this.id,
    required this.content,
    this.pages = 1,
    this.asks = false,
    this.skippable = false,
    this.action,
    this.blocked,
    this.marker,
  });

  /// Stable: the gallery and tests start the flow at a step by its id.
  final String id;

  final Widget Function(BuildContext context, OnboardingPosition at) content;

  /// More than 1 for the tour: its slides. Next walks them before leaving.
  final int pages;

  /// A question: counted in "Question x of y".
  final bool asks;

  /// Shows Skip, which goes on to the next step, on every page but the last,
  /// and on a step with one page.
  final bool skippable;

  /// The main button's label. Null: "Next", or "Continue" on the last step.
  final String Function(AppLocalizations l10n)? action;

  /// Why the main button is disabled, shown above it, or null while it is
  /// enabled. Null: always enabled.
  final String? Function(OnboardingAnswers answers, AppLocalizations l10n)?
  blocked;

  /// Drawn above the button on a step with pages: the tour's dots.
  final Widget Function(BuildContext context, int page)? marker;
}

/// What the flow hands a step's content.
@immutable
class OnboardingPosition {
  const OnboardingPosition({
    required this.page,
    required this.onPage,
    required this.answers,
    required this.choices,
    required this.firstVisit,
  });

  /// This step's page; 0 on a step without pages.
  final int page;

  /// A swipe reports the page it settled on here.
  final ValueChanged<int> onPage;

  final OnboardingAnswers answers;

  /// `assets/languages.yaml`, read once as the flow starts; null until read.
  final List<SpokenLanguage>? choices;

  /// False when the learner has come back to this step: entrances play once.
  final bool firstVisit;
}

/// One language the learner set on the first launch: its entry in
/// `assets/languages.yaml`, and the skills they chose for it.
@immutable
class ChosenLanguage {
  const ChosenLanguage(this.language, this.skills);

  final SpokenLanguage language;
  final LanguageSkills skills;
}

/// The answers so far. Nothing reaches the settings before the last step's
/// button.
class OnboardingAnswers extends ChangeNotifier {
  OnboardingAnswers({Map<String, ChosenLanguage> chosen = const {}})
    : _chosen = Map<String, ChosenLanguage>.of(chosen);

  final Map<String, ChosenLanguage> _chosen;

  /// The languages the learner set, in the order they set them, each with its
  /// skills (Learn and Know, owner, 2026-11-01). English is not among them:
  /// it is fixed as known and saved with them.
  List<ChosenLanguage> get chosen =>
      List<ChosenLanguage>.unmodifiable(_chosen.values);

  /// The skills set for [code], or null: not chosen.
  LanguageSkills? skillsFor(String code) => _chosen[code]?.skills;

  /// Sets [language]'s skills. A language with every skill Leave is not in
  /// the list: it is dropped. English is fixed and ignored.
  void setSkills(SpokenLanguage language, LanguageSkills skills) {
    if (language.code == englishCode) return;
    if (skills.isAllLeave) {
      if (_chosen.remove(language.code) == null) return;
    } else {
      _chosen[language.code] = ChosenLanguage(language, skills);
    }
    notifyListeners();
  }

  /// What the sound check found (#89), or null if it was not run, which
  /// leaves both switches as they are.
  SoundCheckResult? get soundCheck => _soundCheck;
  SoundCheckResult? _soundCheck;
  set soundCheck(SoundCheckResult? result) {
    if (result == _soundCheck) return;
    _soundCheck = result;
    notifyListeners();
  }

  /// Writes every answer. English, fixed as known, goes last: it puts the
  /// spoken languages in the learner's order, and saving them is what ends
  /// the first launch (`lib/app.dart`), so nothing may follow it.
  ///
  /// Each language is saved as its skills, and the older lists follow
  /// ([LanguageSkillsOnState.applySkills]): what is learned, what is spoken,
  /// the scripts read. A language to learn starts its download, as adding it
  /// on the Languages page does. With nothing to learn, the learning
  /// languages are still asked next (`lib/app.dart`).
  void saveTo(AppState state) {
    if (_soundCheck case final check?) {
      state.settings.setSkillEnabled(Skill.speaking, check.speaks);
      if (check.hears case final on?) {
        state.settings.setSkillEnabled(Skill.listening, on);
      }
    }
    for (final c in _chosen.values) {
      state.applySkills(c.language, c.skills);
    }
    state.settings
      ..setLanguageSkills(englishCode, englishKnownByDefault().toStored())
      ..scriptsRead = <String, bool>{...state.settings.scriptsRead, 'en': true}
      ..spokenLanguages = <String>[
        for (final code in state.settings.spokenLanguages)
          if (code != englishCode) code,
        englishCode,
      ];
    if (state.deckDownloads != null) {
      for (final c in _chosen.values) {
        if (c.skills.anyLearn) {
          unawaited(state.downloadLanguage(c.language.code));
        }
      }
    }
  }
}

/// What one run of the sound check found.
@immutable
class SoundCheckResult {
  const SoundCheckResult({
    required this.speaks,
    required this.hears,
    this.failure,
    this.noRecogniser = false,
    this.beep = false,
    this.refusals = 0,
  });

  /// Whether speaking works: it recorded, and the phone has a recogniser.
  final bool speaks;

  /// Whether listening works: false if playback failed or wasn't heard,
  /// null while the learner hasn't said whether they heard it.
  final bool? hears;

  /// Why the recording failed, or null if it worked.
  final RecordFailure? failure;

  /// It recorded, but the phone has no speech recogniser.
  final bool noRecogniser;

  /// A beep was played, there being no recording.
  final bool beep;

  /// How many times the microphone was refused, across tries. From the
  /// second, Android no longer asks.
  final int refusals;

  SoundCheckResult heard(bool heard) => SoundCheckResult(
    speaks: speaks,
    hears: heard,
    failure: failure,
    noRecogniser: noRecogniser,
    beep: beep,
    refusals: refusals,
  );
}
