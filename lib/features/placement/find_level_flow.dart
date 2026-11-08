import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Card;

import '../../app/app_info.dart';
import '../../app/app_state.dart';
import '../../app/placement_plan.dart';
import '../../app/placement_profiles.dart';
import '../../app/placement_recheck.dart';
import '../../app/placement_run_setup.dart';
import '../../core/languages/language_skills.dart';
import '../../core/placement/assurance_model.dart';
import '../../core/placement/declaration_options.dart';
import '../../core/placement/placement_questions.dart';
import '../../core/placement/item_bank.dart' show ItemBank;
import '../../core/placement/item_registry.dart' show RegItem;
import '../../core/placement/saved_run.dart' show placementDeckSetKey;
import '../../core/placement/saved_v3_run.dart';
import '../../core/placement/v3_session.dart';
import '../../core/placement/skills_in_play.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/snack.dart';
import 'find_level_labels.dart';
import 'find_level_declaration.dart';
import 'find_level_preparing.dart';
import 'v3_run_page.dart';

/// What a tap of Find my level checks and what it is called, for a language
/// whose skills are [skills] (see [selectFindLevelSkills]).
///
/// [scripts] are the names of the course's own scripts in path order; reading
/// them takes a walk over the whole course, so a caller that asks often (a
/// row drawn on every build) keeps them ([findLevelScriptNames]).
FindLevelSkills findLevelSkillsOf(
  AppState state,
  String code, {
  required LanguageSkills skills,
  required List<SkillKey> shape,
  List<String>? scripts,
}) => selectFindLevelSkills(
  skills.stateOf,
  shape,
  verified: state.settings.verifiedSkillsOf(code),
  scripts: scripts ?? findLevelScriptNames(state, code),
  // Letters known from another language are not words known (owner,
  // 2026-11-07): worked out now, never stored.
  autoKnown: state.autoKnownKeysOf(code, shape),
);

/// The names of [code]'s own scripts, in path order, as
/// [AppState.placementScripts] finds them.
List<String> findLevelScriptNames(AppState state, String code) => <String>[
  for (final script in state.placementScripts(code)) script.script,
];

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
  // The question bank is made in the background from here on.
  final bank = state.placementBanks.jobFor(plan.data);
  // The calibration profile of this language and level, as the file has it
  // (the built-in default when it does not, or the kill switch is on).
  final profile = (await loadPlacementProfiles()).resolve(
    code,
    bandOfBuilt(built),
  );
  if (!context.mounted) return;
  final settings = state.settings;
  final pick = findLevelSkillsOf(
    state,
    code,
    skills: skills,
    shape: shape,
    scripts: <String>[for (final script in plan.scripts) script.script],
  );
  // Hear needs sound on and a voice, or its questions could not be heard.
  final canPlay = settings.soundOn && state.hasVoice(plan.language);
  // Say needs the recogniser for the language, and the long sentences are
  // said back in the learner's own language.
  final canSpeak =
      state.canHearAfterAsking(plan.language) &&
      state.canHearAfterAsking(plan.native);
  // A Check again: the credit an earlier version wrote and the learner has not
  // confirmed (point 17). The run is the same, and its end shows both levels.
  final unconfirmed = state.unconfirmedMomentsOf(code).isNotEmpty;
  final before = unconfirmed
      ? state.creditedLevelsOf(code, plan)
      : const <PlacementSkill, int>{};
  final deckSet = placementDeckSetKey(plan.data);
  int nowSeconds() => state.now().millisecondsSinceEpoch ~/ 1000;

  // A run paused within the last 7 days, on the same decks and app version.
  SavedV3Run? saved;
  var droppedForDevice = false;
  if (settings.placementRunOf(code) case final json?) {
    try {
      saved = SavedV3Run.fromJson(jsonDecode(json));
    } on FormatException {
      saved = null;
    }
    if (saved == null ||
        !saved.isFresh(
          nowSeconds: nowSeconds(),
          deckSet: deckSet,
          appVersion: AppInfo.version,
          profile: profile.version,
        )) {
      settings.setPlacementRun(code, null);
      saved = null;
    } else if (!saved.fitsDevice(audio: canPlay, recogniser: canSpeak)) {
      // A voice or recogniser the run was begun with is gone: its answers
      // would replay onto other questions, so the next one is asked as a new
      // run. The learner is told, and the saved run is deleted only when the
      // new one starts, so that backing out of the declaration keeps it.
      saved = null;
      droppedForDevice = true;
      showAppSnackBar(context, l10n.findLevelResumeDeviceChanged);
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
            saved!.events.where((e) => e != 'k' && e != 'm').length,
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

  final PlacementDeclaration? declaration;
  final Set<PlacementSkill> inPlay;
  final int seed;
  final bool audio;
  final bool recogniser;
  final V3ScriptStart scriptStart;
  if (saved != null) {
    declaration = saved.declaration;
    inPlay = saved.skills;
    seed = saved.seed;
    audio = saved.audio;
    recogniser = saved.recogniser;
    scriptStart = saved.scriptStart;
  } else {
    final wanted = <PlacementSkill>{...pick.skills, ...before.keys};
    if (wanted.isEmpty) {
      showAppSnackBar(context, l10n.findLevelNothingToCheck);
      return;
    }
    inPlay = placementSkillsForDevice(wanted, voice: canPlay);
    // Hear was the only skill and there is no voice: nothing can be checked,
    // so nothing is asked and nothing is written.
    if (inPlay.isEmpty) {
      showAppSnackBar(context, l10n.findLevelNothingToCheckNoVoice(name));
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
    seed = nowSeconds() & 0x7fffffff;
    audio = canPlay;
    recogniser = canSpeak;
    scriptStart = V3ScriptStart.ask;
  }

  // The questions are made from the decks, once per language and deck set,
  // in the background (it was started when Find my level opened, while the
  // learner answered the declaration): normally they are ready and kept.
  // A paused run is replayed on exactly the pool it began on: the whole
  // bank, or the first formats' items cut from it (the same list, whichever
  // way it is cut). It therefore waits for the whole bank. A new run begins on
  // the first formats when the whole bank is not ready (the audit's verdict
  // for the course is stored, so those items are audited), and takes the rest
  // when it arrives.
  var job = bank;
  var items = saved != null ? job.items : job.startable;
  if (items == null) {
    items = await navigator.push<List<RegItem>>(
      MaterialPageRoute<List<RegItem>>(
        settings: const RouteSettings(name: '/find-level-preparing'),
        builder: (_) => FindLevelPreparingPage(
          job: job,
          waitForAll: saved != null,
          retry: () => job = state.placementBanks.jobFor(plan.data),
        ),
      ),
    );
    // Back or Cancel: nothing is asked or written; the build goes on.
    if (items == null || !context.mounted) return;
  }

  var ready = items;
  final resumed = saved != null;
  final resumedStarter = saved?.starter == true;
  // The calibration profile of this language and level, as the file has it
  // (the built-in default when it does not, or the kill switch is on): a
  // resumed run reads the version it began with.
  var restarts = 0;
  V3Run newRun({
    Iterable<String> events = const <String>[],
    V3ScriptStart start = V3ScriptStart.ask,
    int? runSeed,
  }) {
    final whole = job.items;
    // A resumed run is what it was saved as; a new one begins on the whole
    // bank if it is there, else on what is ready.
    final onStarter = resumed && events.isNotEmpty
        ? resumedStarter
        : whole == null;
    return V3Run.replay(
      data: plan.data,
      skills: inPlay,
      audio: audio,
      recogniser: recogniser,
      seed: runSeed ?? seed,
      declaration: declaration,
      scriptStart: start,
      items: onStarter
          ? (whole != null ? ItemBank.starterOf(whole) : ready)
          : (whole ?? ready),
      startedWithStarter: onStarter,
      fullItems: whole,
      profile: profile,
      events: events,
    );
  }

  var current = newRun(
    events: saved?.events ?? const <String>[],
    start: scriptStart,
  );
  // The rest of the bank arrives while the run goes on: the run takes it.
  unawaited(
    job.result.then<void>((all) {
      ready = all;
      current.extendItems(all);
    }, onError: (Object _) {}),
  );
  var currentStart = scriptStart;
  var currentSeed = seed;

  void save(V3Run now) => settings.setPlacementRun(
    code,
    jsonEncode(
      SavedV3Run(
        language: code,
        declaration: declaration,
        skills: inPlay,
        seed: currentSeed,
        audio: audio,
        recogniser: recogniser,
        scriptStart: currentStart,
        starter: now.startedWithStarter,
        profile: profile.version,
        deckSet: deckSet,
        appVersion: AppInfo.version,
        savedAt: nowSeconds(),
        events: now.events,
      ).toJson(),
    ),
  );

  // The run that no longer fits this phone is replaced now that the new one
  // begins.
  if (droppedForDevice) settings.setPlacementRun(code, null);
  String? toast;
  final done = await navigator.push<bool>(
    MaterialPageRoute<bool>(
      settings: const RouteSettings(name: '/find-level'),
      builder: (_) => V3RunPage(
        run: current,
        languageName: name,
        language: plan.language,
        native: plan.native,
        cardOf: plan.data.cardById,
        // A new run: "I do read it" skips the script check, "Check the
        // letters again" asks it again.
        restart: (start) {
          restarts++;
          currentStart = start;
          currentSeed = (seed + restarts * 7919) & 0x7fffffff;
          current = newRun(start: start, runSeed: currentSeed);
          return current;
        },
        onProgress: save,
        // The outcome is written when Done is pressed, and the paused run
        // dropped once it is: a write that throws keeps the run to be
        // carried on.
        onFinish: (result, overrides) {
          // A re-check that placed nothing has nothing to put in place of
          // the old level: it is kept, and the toast says so.
          final placedAny =
              result.skills.any((s) => s.placed) || overrides.isNotEmpty;
          if (unconfirmed && !placedAny) {
            state.keepOldLevel(code);
            toast = l10n.findLevelToastOldKept(name);
            return;
          }
          state.settings.setPlacementProfile(code, profile.version);
          state.writePlacementV3(
            code,
            plan,
            result,
            overrides: overrides,
            native: native,
            recheck: unconfirmed,
          );
          if (unconfirmed) toast = l10n.findLevelToastNewSet(name);
        },
        recheck: unconfirmed
            ? FindLevelRecheck(
                before: before,
                onUse: () {},
                onKeep: () {
                  state.keepOldLevel(code);
                  toast = l10n.findLevelToastOldKept(name);
                },
              )
            : null,
      ),
    ),
  );
  if (done == true && context.mounted) {
    showAppSnackBar(context, toast ?? l10n.languagesToastLevel(name));
  }
}
