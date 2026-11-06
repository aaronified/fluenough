import 'dart:convert';

import 'package:flutter/material.dart' hide Card;

import '../../app/app_info.dart';
import '../../app/app_state.dart';
import '../../app/placement_plan.dart';
import '../../app/placement_run_setup.dart';
import '../../core/languages/language_skills.dart';
import '../../core/placement/assurance_model.dart';
import '../../core/placement/declaration_options.dart';
import '../../core/placement/placement_questions.dart';
import '../../core/placement/placement_run.dart';
import '../../core/placement/placement_session.dart';
import '../../core/placement/saved_run.dart';
import '../../core/placement/skills_in_play.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/snack.dart';
import 'find_level_declaration.dart';
import 'find_level_run_page.dart';

/// What a tap of Find my level checks and what it is called, for a language
/// whose skills are [skills] (see [selectFindLevelSkills]).
FindLevelSkills findLevelSkillsOf(
  AppState state,
  String code, {
  required LanguageSkills skills,
  required List<SkillKey> shape,
}) => selectFindLevelSkills(
  skills.stateOf,
  shape,
  verified: state.settings.verifiedSkillsOf(code),
  scripts: <String>[
    for (final script in state.placementScripts(code)) script.script,
  ],
);

/// Find my level, after the decks are on the phone (wiki/Plan-Placement-V2.md,
/// steps 3 and 4): a paused run is offered back; else the declaration
/// ("How well do you know it?"), whose Back cancels everything and writes
/// nothing and whose Beginner starts from the beginning with nothing asked;
/// else the run, which writes its outcome when it ends.
///
/// [built] is how many levels the path is written to the end of
/// (`B1Progress.builtLevel`): below A1 nothing is offered.
Future<void> startFindLevel(
  BuildContext context, {
  required AppState state,
  required String code,
  required String name,
  required int built,
  required LanguageSkills skills,
  required List<SkillKey> shape,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final navigator = Navigator.of(context);
  if (built < builtA1) return;
  final native = state.courseNative(code);
  final plan = state.placementRunPlan(code, native: native);
  if (plan == null) {
    showAppSnackBar(context, l10n.findLevelNoCourse(name));
    return;
  }
  final settings = state.settings;
  final pick = findLevelSkillsOf(state, code, skills: skills, shape: shape);
  final deckSet = placementDeckSetKey(plan.data);
  int nowSeconds() => state.now().millisecondsSinceEpoch ~/ 1000;

  // A run paused within the last 7 days, on the same decks and app version.
  SavedPlacementRun? saved;
  if (settings.placementRunOf(code) case final json?) {
    try {
      saved = SavedPlacementRun.fromJson(jsonDecode(json));
    } on FormatException {
      saved = null;
    }
    if (saved == null ||
        !saved.isFresh(
          nowSeconds: nowSeconds(),
          deckSet: deckSet,
          appVersion: AppInfo.version,
        )) {
      settings.setPlacementRun(code, null);
      saved = null;
    }
  }
  if (saved != null && saved.events.isNotEmpty) {
    final carryOn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.findLevelResumeTitle),
        content: Text(
          l10n.findLevelResumeBody(
            name,
            saved!.events.where((e) => e.startsWith('a')).length,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.findLevelResumeNew),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.findLevelResumeGo),
          ),
        ],
      ),
    );
    if (carryOn == null || !context.mounted) return;
    if (!carryOn) {
      settings.setPlacementRun(code, null);
      saved = null;
    }
  } else {
    saved = null;
  }

  final PlacementDeclaration declaration;
  final Set<PlacementSkill> inPlay;
  final int seed;
  final bool microphone;
  if (saved != null) {
    declaration = saved.declaration;
    inPlay = saved.skills;
    seed = saved.seed;
    microphone = saved.microphone;
  } else {
    if (pick.skills.isEmpty) {
      showAppSnackBar(context, l10n.findLevelNothingToCheck);
      return;
    }
    final answer = await navigator.push<PlacementDeclaration>(
      MaterialPageRoute<PlacementDeclaration>(
        settings: const RouteSettings(name: '/find-level-declaration'),
        builder: (_) => FindLevelDeclarationPage(
          language: name,
          options: declarationOptionsFor(built),
        ),
      ),
    );
    // Back: the whole of Find my level is cancelled and nothing is written.
    if (answer == null || !context.mounted) return;
    // Beginner skips the run: nothing is asked, credited or stored, and the
    // learner starts from the beginning with the skills as they are.
    if (answer == PlacementDeclaration.beginner) {
      showAppSnackBar(context, l10n.findLevelBeginnerToast(name));
      return;
    }
    declaration = answer;
    // Hear needs a voice, or the questions could not be heard.
    inPlay = <PlacementSkill>{
      for (final skill in pick.skills)
        if (skill != PlacementSkill.hear ||
            (settings.soundOn && state.hasVoice(plan.language)))
          skill,
    };
    seed = nowSeconds() & 0x7fffffff;
    // Say needs the recogniser for the language, and the long sentences are
    // said back in the learner's own language.
    microphone = state.canHear(plan.language) && state.canHear(plan.native);
  }

  final downloads = state.deckDownloads;
  final config = PlacementRunConfig(
    deckCount: plan.data.deckCount,
    skills: inPlay,
    declaration: declaration,
    seed: seed,
    // Verified needs the path complete to B1 and every deck on the phone.
    pathCompleteToB1: built >= builtB1,
    allDecksDownloaded:
        downloads == null ||
        (!downloads.isDownloading(code) &&
            downloads.missing(code, settings.spokenLanguages).isEmpty),
    microphone: microphone,
    grammarUnitDecks: <int>[
      for (final (i, deck) in plan.data.decks.indexed)
        if (deck.isGrammar) i,
    ],
    // Taken by the owner, 2026-11-05 (section 6.2).
    extraScriptQuestion: true,
  );
  final session = PlacementSession.replay(
    config,
    plan.data,
    saved?.events ?? const <String>[],
  );

  void save(PlacementSession now) => settings.setPlacementRun(
    code,
    jsonEncode(
      SavedPlacementRun(
        language: code,
        declaration: declaration,
        skills: inPlay,
        seed: seed,
        microphone: microphone,
        deckSet: deckSet,
        appVersion: AppInfo.version,
        savedAt: nowSeconds(),
        events: now.events,
      ).toJson(),
    ),
  );

  final done = await navigator.push<bool>(
    MaterialPageRoute<bool>(
      settings: const RouteSettings(name: '/find-level'),
      builder: (_) => FindLevelRunPage(
        session: session,
        languageName: name,
        language: plan.language,
        native: plan.native,
        cardOf: plan.data.cardById,
        onProgress: save,
        onFinish: (finished) {
          settings.setPlacementRun(code, null);
          state.writePlacementRun(code, plan, finished.run, native: native);
        },
      ),
    ),
  );
  if (done == true && context.mounted) {
    showAppSnackBar(context, l10n.languagesToastLevel(name));
  }
}
