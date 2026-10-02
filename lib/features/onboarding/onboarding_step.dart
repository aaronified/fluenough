import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_state.dart';
import '../../app/skill.dart';
import '../../core/data/spoken_languages.dart';
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

  /// Shows Skip, which goes on to the next step, on every page but the last.
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

/// The answers so far. Nothing reaches the settings before the last step's
/// button.
class OnboardingAnswers extends ChangeNotifier {
  OnboardingAnswers({List<String> spoken = const <String>[]})
    : _spoken = List<String>.unmodifiable(spoken);

  List<String> _spoken;

  /// The languages the learner speaks, best known first.
  List<String> get spoken => _spoken;
  set spoken(List<String> codes) {
    if (listEquals(codes, _spoken)) return;
    _spoken = List<String>.unmodifiable(codes);
    notifyListeners();
  }

  /// What the sound check found (#89): whether speaking and listening
  /// work on this phone. Null for one not checked, which leaves its switch
  /// as it is.
  bool? get canSpeak => _canSpeak;
  bool? get canHear => _canHear;
  bool? _canSpeak;
  bool? _canHear;

  void soundChecked({bool? speaking, bool? listening}) {
    if (speaking == _canSpeak && listening == _canHear) return;
    _canSpeak = speaking;
    _canHear = listening;
    notifyListeners();
  }

  /// Writes every answer. The spoken languages go last: saving them is what
  /// ends the first launch (`lib/app.dart`), so nothing may follow them.
  void saveTo(AppState state) {
    if (_canSpeak case final on?) {
      state.settings.setSkillEnabled(Skill.speaking, on);
    }
    if (_canHear case final on?) {
      state.settings.setSkillEnabled(Skill.listening, on);
    }
    state.settings.spokenLanguages = _spoken;
  }
}
