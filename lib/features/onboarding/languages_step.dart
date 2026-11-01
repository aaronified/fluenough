import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/data/spoken_languages.dart';
import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import '../languages/language_pick_list.dart';
import '../languages/language_skills_sheet.dart';
import '../languages/language_views.dart';
import '../languages/languages_page.dart' show LanguageRow, LanguageSection;
import '../profiles/spoken_languages_picker.dart';
import 'onboarding_step.dart';
import 'question_heading.dart';

/// The first launch's question (owner, 2026-11-01; the approved mockup
/// `skill-pills-onboarding`, screens 2 to 4): the languages the learner
/// knows and the ones they want to learn, set on the Languages page's own
/// list and skills sheet. Nothing is saved until the last button
/// ([OnboardingAnswers.saveTo]). English is already known, fixed.
///
/// Needs at least one language besides English to go on: with only English
/// there is nothing to learn or to know yet.
final OnboardingStep languagesStep = OnboardingStep(
  id: 'languages',
  asks: true,
  blocked: (answers, l10n) =>
      answers.chosen.isEmpty ? l10n.onboardingSpokenNeedOne : null,
  content: (context, at) =>
      OnboardingLanguages(answers: at.answers, choices: at.choices),
);

/// Whether a language is first asked what script the learner reads
/// ([KnownLanguageSheet]): not a sign language, not a script-only course, not
/// one written in Latin letters alone (everyone who knows English reads
/// them), and one the list names a script for.
bool asksWhichScripts(SpokenLanguage language) =>
    !language.isSign &&
    !language.scriptOnly &&
    language.scripts.isNotEmpty &&
    !(language.scripts.length == 1 && language.scripts.first == latinScript);

/// What the Know sheet's [reply] says of [language]: reading a script
/// or speaking it means hearing and speaking it (as the older lists have
/// always read), and each script read is Read known. Nothing to Learn: the
/// skills sheet that follows asks that.
LanguageSkills skillsFromKnownReply(SpokenLanguage language, KnownReply reply) {
  if (reply.answer == KnownAnswer.remove) return LanguageSkills();
  var skills = LanguageSkills().withSpokenLevel(SpokenLevel.hearSpeak);
  for (final script in reply.scripts) {
    if (script.isEmpty) continue;
    skills = skills.withScriptLevel(script, ScriptLevel.read);
  }
  return skills;
}

/// The list of the languages set so far, in sections (Learning, Know), and
/// the button that adds one.
class OnboardingLanguages extends StatefulWidget {
  const OnboardingLanguages({
    super.key,
    required this.answers,
    required this.choices,
  });

  final OnboardingAnswers answers;

  /// `assets/languages.yaml`; null until read.
  final List<SpokenLanguage>? choices;

  @override
  State<OnboardingLanguages> createState() => _OnboardingLanguagesState();
}

class _OnboardingLanguagesState extends State<OnboardingLanguages> {
  @override
  void initState() {
    super.initState();
    // The courses a learner can pick to learn come from the deck index.
    final downloads = AppScope.read(context).deckDownloads;
    if (downloads != null && downloads.index == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(downloads.refreshIndex()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.choices;
    if (all == null) return const Center(child: CircularProgressIndicator());
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[
        widget.answers,
        state.settings,
        state.deckDownloads,
      ]),
      builder: (context, _) {
        final views = <String, LanguageView>{
          for (final v in languageViews(state, all)) v.code: v,
        };
        final rows = <(LanguageView, LanguageSkills)>[
          for (final c in widget.answers.chosen)
            (views[c.language.code]!, c.skills),
          if (views[englishCode] case final english?)
            (english, englishKnownByDefault()),
        ];
        final learning = <(LanguageView, LanguageSkills)>[
          for (final r in rows)
            if (r.$2.anyLearn) r,
        ];
        final know = <(LanguageView, LanguageSkills)>[
          for (final r in rows)
            if (!r.$2.anyLearn) r,
        ];
        Widget row((LanguageView, LanguageSkills) r) => LanguageRow(
          key: ValueKey<String>('language-${r.$1.code}'),
          view: r.$1,
          skills: r.$2,
          onTap: () => _edit(context, all, r.$1, r.$2),
        );
        return ListView(
          padding: const EdgeInsetsDirectional.only(bottom: 24),
          children: <Widget>[
            QuestionHeading(
              title: l10n.onboardingLanguagesListTitle,
              body: l10n.onboardingLanguagesListBody,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (learning.isNotEmpty) ...<Widget>[
                    LanguageSection(
                      text: l10n.languagesSectionLearning(learning.length),
                    ),
                    for (final r in learning) row(r),
                  ],
                  if (know.isNotEmpty) ...<Widget>[
                    LanguageSection(
                      text: l10n.languagesSectionKnow(know.length),
                    ),
                    for (final r in know) row(r),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey<String>('onboarding-add-language'),
                    onPressed: () => _add(context, all),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.languagesAdd),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _add(BuildContext context, List<SpokenLanguage> all) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/onboarding/languages/add'),
          builder: (_) =>
              OnboardingAddLanguagePage(answers: widget.answers, all: all),
        ),
      );

  /// A language already on the list: its skills sheet, with what is set.
  Future<void> _edit(
    BuildContext context,
    List<SpokenLanguage> all,
    LanguageView view,
    LanguageSkills skills,
  ) => showSkillsSheet(
    context,
    answers: widget.answers,
    all: all,
    view: view,
    initial: skills,
    draft: false,
  );
}

/// Opens [view]'s skills sheet: as a draft, [initial] what the Know sheet
/// answered, for a language being added; else with the skills it has. Its
/// button hands the skills to [answers]; returns whether it did.
Future<bool> showSkillsSheet(
  BuildContext context, {
  required OnboardingAnswers answers,
  required List<SpokenLanguage> all,
  required LanguageView view,
  required LanguageSkills? initial,
  required bool draft,
}) async {
  final english = all.where((l) => l.code == englishCode).firstOrNull;
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => LanguageSkillsSheet(
      view: view,
      draft: draft,
      initial: initial,
      others: <String, LanguageSkills>{
        for (final c in answers.chosen)
          if (c.language.code != view.code) c.language.name: c.skills,
        if (english != null && view.code != englishCode)
          english.name: englishKnownByDefault(),
      },
      names: <String, String>{for (final l in all) l.code: l.name},
      onSet: (skills) => answers.setSkills(view.language, skills),
    ),
  );
  return added ?? false;
}

/// "Add a language" on the first launch: the Add page's list
/// ([LanguagePickList]), where a pick asks the Know sheet first (which script
/// is read, for a language written in more than one or in a script of its
/// own), then the skills sheet as a draft. Nothing is saved by the settings
/// until the last step. Adding goes back to the list.
class OnboardingAddLanguagePage extends StatefulWidget {
  const OnboardingAddLanguagePage({
    super.key,
    required this.answers,
    required this.all,
  });

  final OnboardingAnswers answers;
  final List<SpokenLanguage> all;

  @override
  State<OnboardingAddLanguagePage> createState() =>
      _OnboardingAddLanguagePageState();
}

class _OnboardingAddLanguagePageState extends State<OnboardingAddLanguagePage> {
  Future<void> _pick(LanguageView view) async {
    final language = view.language;
    final existing = widget.answers.skillsFor(view.code);
    LanguageSkills? initial = existing;
    if (existing == null && asksWhichScripts(language)) {
      final reply = await showModalBottomSheet<KnownReply>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => KnownLanguageSheet(
          language: language,
          current: null,
          chosen: false,
        ),
      );
      if (!mounted) return;
      // Left unanswered, the skills sheet starts empty: a learner who knows
      // nothing of the language still gets there.
      if (reply != null) initial = skillsFromKnownReply(language, reply);
    }
    if (!mounted) return;
    final added = await showSkillsSheet(
      context,
      answers: widget.answers,
      all: widget.all,
      view: view,
      initial: initial,
      draft: existing == null,
    );
    if (added && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languagesAddTitle)),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable?>[
            widget.answers,
            state.settings,
            state.deckDownloads,
          ]),
          builder: (context, _) => LanguagePickList(
            views: <LanguageView>[
              for (final v in languageViews(state, widget.all))
                if (v.code != englishCode) v,
            ],
            isAdded: (v) => widget.answers.skillsFor(v.code) != null,
            onPick: _pick,
          ),
        ),
      ),
    );
  }
}
