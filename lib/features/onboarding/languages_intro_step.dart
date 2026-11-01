import 'package:flutter/material.dart';

import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import '../languages/skill_widgets.dart';
import '../profiles/spoken_languages_picker.dart';
import 'onboarding_step.dart';
import 'question_heading.dart';

/// The first launch's explanation of what comes next (owner, 2026-11-01:
/// "During onboarding, show the language screen and explain the options, and
/// then let the users choose what they know and what they want to learn";
/// the approved mockup `skill-pills-onboarding`, screen 1): what Learn, Know
/// and Not learning mean, what the pills' icons say, and that two ticks mean
/// a placement check confirmed a level. Plain words only: the pills are drawn
/// as the learner will see them, and no skill is given a name of its own.
final OnboardingStep languagesIntroStep = OnboardingStep(
  id: 'languages-intro',
  skippable: true,
  action: (l10n) => l10n.onboardingLanguagesAction,
  content: (context, at) => const LanguagesIntro(),
);

class LanguagesIntro extends StatelessWidget {
  const LanguagesIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge!;
    final spoken = l10n.languagesSkillSpoken;
    Widget spokenPill(SkillMark mark) => SkillBadge(
      kind: SkillKind.hear,
      combined: true,
      big: true,
      mark: mark,
      name: spoken,
    );
    Widget term(SkillMark mark, String name, String meaning) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          spokenPill(mark),
          const SizedBox(height: 6),
          Text.rich(
            _boldTerm(l10n.onboardingLanguagesTerm(name, meaning), name),
          ),
        ],
      ),
    );
    final step = ExcludeSemantics(
      child: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    Widget skill(SkillKind kind, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(kind.icon, size: 20, color: theme.colorScheme.onSurface),
        const SizedBox(width: 6),
        Text(label, style: body),
      ],
    );
    // A column in a scroll view, not a lazy list: it is short, and every part
    // of it is there for a screen reader and a test to find.
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          QuestionHeading(
            title: l10n.onboardingLanguagesTitle,
            body: l10n.onboardingLanguagesIntro,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
            child: DefaultTextStyle.merge(
              style: body,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  term(
                    SkillMark.learn,
                    l10n.languagesStateLearn,
                    l10n.onboardingLanguagesLearnMeaning,
                  ),
                  term(
                    SkillMark.know,
                    l10n.languagesStateKnow,
                    l10n.onboardingLanguagesKnowMeaning,
                  ),
                  term(
                    SkillMark.leave,
                    l10n.languagesPillLeave,
                    l10n.onboardingLanguagesLeaveMeaning,
                  ),
                  Text(l10n.onboardingLanguagesIcons),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: <Widget>[
                      skill(SkillKind.read, l10n.languagesSkillRead),
                      skill(SkillKind.write, l10n.languagesSkillWrite),
                      skill(SkillKind.hear, l10n.languagesSkillHear),
                      skill(SkillKind.speak, l10n.languagesSkillSpeak),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.onboardingLanguagesPairs),
                  const SizedBox(height: 8),
                  // The four steps a tap goes through.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      spokenPill(SkillMark.leave),
                      step,
                      spokenPill(SkillMark.learn),
                      step,
                      spokenPill(SkillMark.know),
                      step,
                      spokenPill(SkillMark.knowBoth),
                    ],
                  ),
                  const SizedBox(height: 14),
                  spokenPill(SkillMark.knowBothCovered),
                  const SizedBox(height: 6),
                  Text(
                    l10n.onboardingLanguagesChecked(l10n.languagesFindLevel),
                  ),
                ],
              ),
            ),
          ),
          PickerNote(
            icon: Icons.lock_outline,
            text: l10n.onboardingSpokenPrivacy(
              l10n.navSettings,
              l10n.languagesTitle,
            ),
          ),
        ],
      ),
    );
  }
}

/// [text] with its first [term] in bold.
TextSpan _boldTerm(String text, String term) {
  final at = text.indexOf(term);
  if (at < 0) return TextSpan(text: text);
  return TextSpan(
    children: <TextSpan>[
      TextSpan(text: text.substring(0, at)),
      TextSpan(
        text: term,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      TextSpan(text: text.substring(at + term.length)),
    ],
  );
}
