import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_downloads.dart';
import '../../app/language_offer.dart';
import '../../app/language_skills.dart';
import '../../app/placement.dart' show ScriptStanding;
import '../../app/placement_credit.dart';
import '../../core/data/spoken_languages.dart' show SpokenLanguage;
import '../../core/decks/font_check.dart';
import '../../core/decks/language_catalog.dart';
import '../../core/models/deck.dart' show LanguageInfo;
import '../../core/languages/language_skills.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hint.dart';
import '../../ui/widgets/snack.dart';
import '../downloads/download_text.dart';
import '../fonts/font_check_sheet.dart';
import '../placement/course_line.dart';
import '../placement/language_row.dart';
import '../placement/placed_review_choice.dart';
import '../placement/placement_page.dart';
import 'language_views.dart';
import 'skill_widgets.dart';

/// Opens [view]'s skills sheet over [context]'s screen, as the Languages
/// page does: [all] names the languages for placement, and a language whose
/// last skill goes to Leave is toasted, with Undo. The Decks path's "Add it"
/// opens it too.
Future<void> showLanguageSkills(
  BuildContext context,
  AppState state,
  List<SpokenLanguage> all,
  LanguageView view,
) {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => LanguageSkillsSheet(
      view: view,
      names: <String, String>{for (final l in all) l.code: l.name},
      onPooled: (previous) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.languagesToastPool(view.name)),
              action: SnackBarAction(
                label: l10n.languagesUndo,
                onPressed: () => state.applySkills(view.language, previous),
              ),
            ),
          );
      },
    ),
  );
}

/// A language's sheet on the Languages page (#907, the mockup
/// `languages-merged`, approved 2026-10-30): its dialect, one pill for each
/// skill (Speak and Hear, then Read and Write for each script) that cycles
/// Leave, Know, Learn, the minutes a day, Find my level and Placed words.
/// A skill changed to Learn leaves the bottom button as Check, which tests
/// the sound or whether the script shows on the phone.
///
/// For a language already on the page every change is saved at once and
/// toasted; for [draft], a language being added, nothing is saved until
/// "Add". Pops `true` when a draft was added.
///
/// On the first launch (owner, 2026-11-01) the same sheet is shown with
/// [onSet]: nothing is saved either way, and the skills are handed to
/// [onSet] by "Add" (a [draft]) or "Done" (a language already chosen, with
/// its [initial] skills), because nothing reaches the settings before the
/// last step of the first launch.
class LanguageSkillsSheet extends StatefulWidget {
  const LanguageSkillsSheet({
    super.key,
    required this.view,
    this.draft = false,
    this.others = const <String, LanguageSkills>{},
    this.names = const <String, String>{},
    this.onPooled,
    this.initial,
    this.onSet,
  });

  final LanguageView view;
  final bool draft;

  /// The skills to start from: for a [draft], what the Know sheet answered
  /// (the scripts known from other languages are added to it); with [onSet]
  /// and no [draft], the skills the language has so far.
  final LanguageSkills? initial;

  /// The first launch: called with the skills when the sheet is confirmed,
  /// instead of saving them. Null on the Languages page.
  final ValueChanged<LanguageSkills>? onSet;

  /// The skills of the languages already on the page, by name, for a draft:
  /// a script known there starts as Know here.
  final Map<String, LanguageSkills> others;

  /// Language names by code, for placement.
  final Map<String, String> names;

  /// Called with the skills a language had when its last skill went to
  /// Leave, so that the page can offer Undo.
  final void Function(LanguageSkills previous)? onPooled;

  @override
  State<LanguageSkillsSheet> createState() => _LanguageSkillsSheetState();
}

class _LanguageSkillsSheetState extends State<LanguageSkillsSheet> {
  late final AppState _state;
  late LanguageSkills _skills;
  final Set<SkillKey> _pending = <SkillKey>{};
  Map<SkillKey, String> _auto = const <SkillKey, String>{};
  bool _busy = false;

  LanguageView get _view => widget.view;

  /// Whether nothing is saved from here: a language being added, or the first
  /// launch, which keeps its answers until its last step.
  bool get _isDraft => widget.draft || widget.onSet != null;
  String get _code => _view.code;
  List<SkillKey> get _shape => _state.skillShape(_view.language);
  List<String> get _scripts => _state.skillScripts(_view.language);
  bool get _several => _scripts.length > 1;

  @override
  void initState() {
    super.initState();
    _state = AppScope.read(context);
    if (widget.draft) {
      _auto = autoKnownFrom(scripts: _scripts, others: widget.others);
      final initial = widget.initial;
      _skills = LanguageSkills(<SkillKey, SkillState>{
        for (final key in _auto.keys) key: SkillState.know,
        if (initial != null)
          for (final key in initial.held) key: initial.stateOf(key),
      });
    } else if (widget.initial case final initial?) {
      _skills = initial;
    } else {
      _skills = _state.skillsOf(_view.language);
    }
  }

  bool get _locked => _code == englishCode;

  bool _covers() => levelCovers(
    levelFound: _state.levelFound(_code),
    taught: _view.canLearn,
    english: _locked,
  );

  void _toast(String message) => showAppSnackBar(context, message);

  bool get _needsDownload {
    final downloads = _state.deckDownloads;
    return downloads != null &&
        !downloads.hasDecks(_code) &&
        !downloads.isDownloading(_code);
  }

  void _startDownload() {
    if (_state.deckDownloads != null) {
      unawaited(_state.downloadLanguage(_code));
    }
  }

  /// A tap on the Spoken pill: Speak and Hear together (Leave, Learn, Hear,
  /// Hear and Speak).
  Future<void> _cycleSpoken() {
    final l10n = AppLocalizations.of(context)!;
    final next = _skills.cycledSpoken(canLearn: _view.canLearn);
    return _change(
      next,
      const <SkillKey>[SkillKey(SkillKind.speak), SkillKey(SkillKind.hear)],
      name: _view.name,
      skill: next.spokenLevel == SpokenLevel.hear
          ? l10n.languagesToastPhraseHear
          : l10n.languagesToastPhraseSpoken,
      state: _stateOf(next.spokenLevel),
      toLearn: next.spokenLevel == SpokenLevel.learn,
    );
  }

  /// A tap on a script's pill: its Read and Write together (Leave, Learn,
  /// Read, Read and Write).
  Future<void> _cycleScript(String script) {
    final l10n = AppLocalizations.of(context)!;
    final next = _skills.cycledScript(script, canLearn: _view.canLearn);
    final scriptName = l10n.scriptNameOr(script, _view.name);
    return _change(
      next,
      _skills.keysOfScript(script),
      name: _view.name,
      skill: next.scriptLevelOf(script) == ScriptLevel.read
          ? l10n.languagesToastPhraseRead(scriptName)
          : l10n.languagesToastPhraseScript(scriptName),
      state: _stateOf(next.scriptLevelOf(script)),
      toLearn: next.scriptLevelOf(script) == ScriptLevel.learn,
    );
  }

  /// A tap on the Gestures pill: Leave, Know, Learn, Leave (Learn skipped
  /// where there are no decks to learn).
  Future<void> _cycleGesture() {
    final l10n = AppLocalizations.of(context)!;
    const key = SkillKey(SkillKind.gesture);
    final next = _skills.cycled(key, canLearn: _view.canLearn);
    final level = next.stateOf(key);
    return _change(
      next,
      const <SkillKey>[key],
      name: _view.name,
      skill: l10n.languagesToastPhraseGestures,
      state: level,
      toLearn: level == SkillState.learn,
    );
  }

  /// What a pill's level means for its toast: learning, already known, or
  /// neither (the levels Hear, Hear and Speak, Read and Read and Write are
  /// all Know).
  SkillState _stateOf(Enum level) => switch (level) {
    SpokenLevel.learn || ScriptLevel.learn => SkillState.learn,
    SpokenLevel.leave || ScriptLevel.leave => SkillState.leave,
    _ => SkillState.know,
  };

  Future<void> _change(
    LanguageSkills next,
    List<SkillKey> keys, {
    required String name,
    required String skill,
    required SkillState state,
    required bool toLearn,
  }) async {
    final before = _skills;
    if (!_isDraft &&
        toLearn &&
        !before.anyLearn &&
        _needsDownload &&
        !await _confirmDownload()) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _skills = next;
      for (final key in keys) {
        // A gesture skill has nothing to check.
        toLearn && !key.kind.isGesture
            ? _pending.add(key)
            : _pending.remove(key);
      }
      _auto = <SkillKey, String>{
        for (final e in _auto.entries)
          if (!keys.contains(e.key)) e.key: e.value,
      };
    });
    _toast(
      AppLocalizations.of(context)!
          .languagesToastSkill(name, skill, state.name),
    );
    if (_isDraft) return;
    _state.applySkills(_view.language, next);
    if (!before.anyLearn && next.anyLearn) _startDownload();
    if (next.isAllLeave) {
      widget.onPooled?.call(before);
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDownload() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.languagesDownloadTitle(_view.name)),
        content: Text(
          l10n.languagesDownloadBody(formatSize(l10n, _view.course?.size ?? 0)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.languagesDownloadGo),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ---------------------------------------------------------------------------
  // The checks

  Future<void> _runChecks() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      for (final check in checksOwed(_pending.toList())) {
        final ok = switch (check) {
          SoundCheck() => await _soundCheck(),
          ScriptCheck(:final script) => await _scriptCheck(script),
        };
        if (!mounted) return;
        if (!ok) return;
        setState(() {
          _pending.removeWhere(
            (k) => switch (check) {
              SoundCheck() => !k.kind.isScript,
              ScriptCheck(:final script) => k.script == script,
            },
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _soundCheck() async {
    final l10n = AppLocalizations.of(context)!;
    final voice = _state.voiceBlocksOf(_code).firstOrNull;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SoundCheckDialog(
        state: _state,
        name: _view.name,
        sample: _view.language.ownName,
        voice: voice,
      ),
    );
    if (!mounted) return false;
    _toast(
      ok == true
          ? l10n.languagesToastSoundOk(_view.name)
          : l10n.languagesToastSoundBad(_view.name),
    );
    return ok == true;
  }

  Future<bool> _scriptCheck(String script) async {
    final l10n = AppLocalizations.of(context)!;
    final fonts = _state.fontCheck;
    if (scriptSamples.containsKey(script) &&
        fonts.stateOf(script) == FontCheckState.notChecked) {
      await showFontCheckSheet(context, script);
    }
    if (!mounted) return false;
    final name = l10n.scriptNameOr(script, _view.name);
    final ok =
        !scriptSamples.containsKey(script) ||
        switch (fonts.stateOf(script)) {
          FontCheckState.phoneFont || FontCheckState.downloaded => true,
          _ => false,
        };
    _toast(
      ok
          ? l10n.languagesToastScriptOk(_view.name, name)
          : l10n.languagesToastScriptBad(_view.name, name),
    );
    return ok;
  }

  // ---------------------------------------------------------------------------
  // The rest

  Future<void> _commit() async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.onSet case final onSet?) {
      onSet(_skills);
      Navigator.of(context).pop(true);
      return;
    }
    if (_skills.anyLearn && _needsDownload && !await _confirmDownload()) return;
    if (!mounted) return;
    _state.applySkills(_view.language, _skills);
    if (_skills.anyLearn) _startDownload();
    _toast(l10n.languagesToastAdded(_view.name));
    Navigator.of(context).pop(true);
  }

  void _minutes(int direction) {
    final l10n = AppLocalizations.of(context)!;
    final settings = _state.settings;
    final now = settings.dailyMinutesFor(_code);
    final next = stepMinutes(now, direction);
    if (next == now) return;
    settings.setDailyMinutes(_code, next);
    _toast(l10n.languagesToastMinutes(_view.name, next));
  }

  Future<void> _checkUpdates() async {
    final l10n = AppLocalizations.of(context)!;
    final downloads = _state.deckDownloads;
    if (downloads == null) return;
    _toast(l10n.languagesToastChecking(_view.name));
    await downloads.checkForUpdates(
      _state.settings.spokenLanguages,
      force: true,
    );
    if (!mounted) return;
    _toast(
      downloads.indexStatus == IndexStatus.failed
          ? l10n.languagesToastCheckFailed(_view.name)
          : downloads.updates.containsKey(_code)
          ? l10n.languagesToastUpdate(_view.name)
          : l10n.languagesToastUpToDate(_view.name),
    );
  }

  void _findLevel() {
    final l10n = AppLocalizations.of(context)!;
    final downloads = _state.deckDownloads;
    if (downloads != null && !downloads.hasDecks(_code)) {
      _toast(l10n.languagesLevelNeedsDecks);
      return;
    }
    final code = _code;
    final state = _state;
    final native = state.courseNative(code);
    final skipped = state.scriptLessonsSkipped(code, native: native);
    final course = _view.course;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/placement'),
        builder: (_) => PlacementPage(
          languages: <String>[code],
          asked: <String>{code},
          alphabet: <String, bool>{
            if (course?.scriptDecks ?? false)
              code: state.settings.learnsAlphabet(code),
          },
          natives: <String, String>{code: ?native},
          languageNames: widget.names,
          onFinished: (found) {
            final settings = state.settings;
            final replaced = <String>{
              for (final entry in state.decks)
                if (entry.language.code == code) entry.id,
            };
            Navigator.of(context).pop();
            settings.placedDecks = <String>{
              for (final id in settings.placedDecks)
                if (!replaced.contains(id)) id,
              ...?found.placed[code],
            };
            state.creditPlacement(
              code,
              placed: found.placed[code] ?? const <String>{},
              standings:
                  found.scripts[code] ?? const <String, ScriptStanding>{},
              native: native,
            );
            settings.setPlacedReview(
              code,
              found.review[code] ?? settings.placedReviewOf(code),
            );
            if (skipped && settings.learnsAlphabet(code)) {
              state.skipScriptLessons(code, true, native: native);
            }
            if (mounted) setState(() {});
            showAppSnackBar(
              context,
              AppLocalizations.of(context)!.languagesToastLevel(_view.name),
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final typed = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.languagesDeleteTitle(_view.name)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.languagesDeleteBody(_view.name)),
                const SizedBox(height: 12),
                TextField(
                  controller: typed,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.languagesDeleteType(_view.name),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: typed.text == _view.name
                  ? () => Navigator.of(context).pop(true)
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.commonDelete),
            ),
          ],
        ),
      ),
    );
    typed.dispose();
    if (ok != true || !mounted) return;
    var next = _skills;
    for (final key in _skills.held) {
      if (_skills.stateOf(key) == SkillState.learn) {
        next = next.withState(key, SkillState.leave);
      }
    }
    _state.applySkills(_view.language, next);
    await _state.deckDownloads?.remove(_code);
    if (!mounted) return;
    _toast(l10n.languagesToastDeleted(_view.name));
    if (next.isAllLeave) {
      widget.onPooled?.call(_skills);
      Navigator.of(context).pop();
    } else {
      setState(() {
        _skills = next;
        _pending.clear();
      });
    }
  }

  void _showInfo() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => _InfoDialog(
        view: _view,
        skills: _skills,
        draft: _isDraft,
        state: _state,
        scripts: _scripts,
        title: _view.title,
        close: l10n.languagesInfoClose,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Building

  @override
  Widget build(BuildContext context) {
    final downloads = _state.deckDownloads;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[_state.settings, downloads]),
      builder: (context, _) => _sheet(context),
    );
  }

  Widget _sheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final downloads = _state.deckDownloads;
    final hasDecks = downloads?.hasDecks(_code) ?? false;
    final progress = _view.course?.progressFor(
      _state.settings.spokenLanguages,
      native: _state.courseNative(_code),
    );
    final tag = stageTag(
      l10n,
      progress?.stage,
      planned: progress?.hasPlan ?? false,
    );
    final nLearn = _skills.count(SkillState.learn, _shape);
    final nKnow = _skills.count(SkillState.know, _shape);
    final meta = _isDraft
        ? l10n.languagesDraftMeta
        : <String>[
            if (nLearn > 0) l10n.languagesMetaLearning(nLearn),
            l10n.languagesMetaKnown(nKnow, _shape.length),
          ].join(' · ');
    final download = downloads?.progressOf(_code);
    final pendingDecks =
        !_isDraft &&
        hasDecks &&
        !_skills.anyLearn &&
        _state.settings.languageSkillsOf(_code) != null;
    final dialect = dialectOf(l10n, _view.language);
    final checks = _pending.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 20, end: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _view.title,
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!_isDraft && _view.canLearn && (hasDecks || _skills.anyLearn))
                LabelledIconButton(
                  label: l10n.languagesUpdateIcon,
                  hint: l10n.hintUpdate,
                  onPressed: _checkUpdates,
                  icon: const Icon(Icons.sync),
                ),
              LabelledIconButton(
                label: l10n.languagesInfoIcon(_view.name),
                hint: l10n.hintInfo,
                onPressed: _showInfo,
                icon: Text(
                  'i', // ui-literal-ok: the info glyph, not prose; its label is the Semantics label
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 2, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (tag != null)
                      StageTag(tag: tag)
                    else if (!_view.canLearn)
                      _PlainBadge(text: l10n.languagesNoCourse),
                    Text(
                      meta,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (progress != null) ...<Widget>[
                  const SizedBox(height: 12),
                  CourseLine(levels: progress.levels),
                ],
                if (download != null && !_isDraft) ...<Widget>[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: download.total == 0
                        ? null
                        : download.done / download.total,
                  ),
                ],
                if (_locked) ...<Widget>[
                  const SizedBox(height: 8),
                  _Note(text: l10n.languagesEnglishLocked),
                ] else if (!_view.canLearn) ...<Widget>[
                  const SizedBox(height: 8),
                  _Note(text: l10n.languagesNoCourseNote(_view.name)),
                ],
                if (pendingDecks) ...<Widget>[
                  const SizedBox(height: 4),
                  _Note(text: l10n.languagesDecksRemoved),
                ],
                if (!_isDraft && _view.canLearn && !_locked) ...<Widget>[
                  _levelRow(context),
                  _placedRow(context),
                ],
                if (_view.language.isSign) ...<Widget>[
                  _Heading(
                    icon: SkillKind.gesture.icon,
                    text: l10n.languagesGestures,
                  ),
                  _skillRow(
                    context,
                    tile: _Tile(icon: SkillKind.gesture.icon),
                    title: l10n.languagesGestures,
                    keys: const <SkillKey>[SkillKey(SkillKind.gesture)],
                    pill: _gesturePill(context),
                  ),
                ] else if (!_view.language.scriptOnly) ...<Widget>[
                  _Heading(icon: Icons.mic_none, text: l10n.languagesSpeakHear),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l10n.languagesDialectLabel,
                          style: theme.textTheme.labelMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(dialect, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
                  _skillRow(
                    context,
                    tile: const _Tile(icon: Icons.mic_none),
                    title: l10n.languagesSkillSpoken,
                    keys: const <SkillKey>[
                      SkillKey(SkillKind.speak),
                      SkillKey(SkillKind.hear),
                    ],
                    pill: _spokenPill(context),
                  ),
                ],
                if (_scripts.isNotEmpty)
                  _Heading(
                    icon: Icons.translate,
                    text: _several
                        ? l10n.languagesScriptsRW
                        : l10n.languagesScriptRW,
                  ),
                for (final script in _scripts)
                  _skillRow(
                    context,
                    tile: _Tile(
                      glyph: scriptGlyph(
                        script,
                        l10n.scriptNameOr(script, _view.name),
                      ),
                    ),
                    title: l10n.scriptNameOr(script, _view.name),
                    keys: _skills.keysOfScript(script),
                    pill: _scriptPill(context, script),
                  ),
                if (!_isDraft && _skills.anyLearn) _learningBlock(context),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
            child: Row(
              children: <Widget>[
                if (!_isDraft && hasDecks)
                  LabelledIconButton(
                    label: l10n.languagesDeleteData,
                    hint: l10n.hintDelete,
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: checks
                        ? _runChecks
                        : widget.draft
                        ? (_skills.isAllLeave ? null : _commit)
                        : widget.onSet != null
                        ? _commit
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      checks
                          ? l10n.languagesCheck
                          : widget.draft
                          ? (_skills.isAllLeave
                                ? l10n.languagesSetOne
                                : l10n.languagesAddLanguage(_view.name))
                          : l10n.languagesDone,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _levelRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final found = _state.levelFound(_code);
    return _LinkRow(
      key: const ValueKey<String>('languages-level'),
      icon: Icons.flag_outlined,
      title: found ? l10n.languagesFitMyLevel : l10n.languagesFindLevel,
      subtitle: found
          ? l10n.languagesLevelFoundSub
          : l10n.languagesLevelNotFoundSub,
      onTap: _findLevel,
    );
  }

  Widget _placedRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = _state.settings;
    final choice = settings.placedReviewOf(_code);
    return _LinkRow(
      key: const ValueKey<String>('languages-placed'),
      icon: Icons.layers_outlined,
      title: l10n.placedReviewRow,
      subtitle: choice.title(l10n),
      onTap: () => showPlacedReviewSheet(
        context,
        language: _code,
        current: choice,
        onChanged: (picked) => settings.setPlacedReview(_code, picked),
      ),
    );
  }

  /// One row: its tile, its title and its one [pill] (for the stored [keys]),
  /// with what is known from elsewhere or still to fit under it.
  Widget _skillRow(
    BuildContext context, {
    required Widget tile,
    required String title,
    required List<SkillKey> keys,
    required Widget pill,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subs = <String>[];
    final autoKeys = <SkillKey>[
      for (final k in keys)
        if (_auto.containsKey(k) && _skills.stateOf(k) == SkillState.know) k,
    ];
    if (autoKeys.isNotEmpty) {
      final from = _auto[autoKeys.first]!;
      final same = autoKeys.every((k) => _auto[k] == from);
      if (same && autoKeys.length == 2) {
        subs.add(l10n.languagesKnownFrom(l10n.languagesSkillReadWrite, from));
      } else {
        for (final k in autoKeys) {
          subs.add(l10n.languagesKnownFrom(k.kind.label(l10n), _auto[k]!));
        }
      }
    }
    if (needsLevelFit(
      reviewOn: _state.settings.reviewDecks,
      skills: _skills,
      rows: keys,
      covered: (_) => _covers(),
    )) {
      subs.add(l10n.languagesFitLevel);
    }
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              tile,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              pill,
            ],
          ),
          for (final sub in subs)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 48, top: 2),
              child: Text(
                sub,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The Gestures pill of a sign language: its own icon, with the tick once
  /// it is known.
  Widget _gesturePill(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const key = SkillKey(SkillKind.gesture);
    final state = _skills.stateOf(key);
    final covered = state == SkillState.know && _covers();
    final next = nextSkillState(state, canLearn: _view.canLearn);
    final name = l10n.languagesSkillGestures;
    return SkillBadge(
      key: const ValueKey<String>('skill-gesture'),
      kind: SkillKind.gesture,
      big: true,
      mark: markOf(state, covered: covered),
      name: name,
      hint: _locked ? null : l10n.languagesTapToChange(next.label(l10n)),
      onTap: _locked ? null : _cycleGesture,
    );
  }

  /// The one pill of Speak and Hear: the Hear icon, then the tick and the
  /// Speak icon once both are known.
  Widget _spokenPill(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final level = _skills.spokenLevel;
    final covered = level.isKnow && _covers();
    final next = nextSpokenLevel(level, canLearn: _view.canLearn);
    final name = l10n.languagesSkillSpoken;
    return SkillBadge(
      key: const ValueKey<String>('skill-spoken'),
      kind: SkillKind.hear,
      combined: true,
      big: true,
      mark: spokenMarkOf(level, covered: covered),
      name: name,
      hint: _locked ? null : l10n.languagesTapToChange(next.label(l10n)),
      onTap: _locked ? null : _cycleSpoken,
    );
  }

  /// The one pill of a script's Read and Write: the eye alone at Read, the eye and
  /// the keyboard at Read and Write, each with its tick.
  Widget _scriptPill(BuildContext context, String script) {
    final l10n = AppLocalizations.of(context)!;
    final level = _skills.scriptLevelOf(script);
    final covered = level.isKnow && _covers();
    final next = nextScriptLevel(level, canLearn: _view.canLearn);
    final name = scriptPillName(l10n, script, _view.name);
    return SkillBadge(
      key: ValueKey<String>('skill-script:$script'),
      kind: SkillKind.read,
      big: true,
      mark: scriptMarkOf(level, covered: covered),
      name: name,
      hint: _locked ? null : l10n.languagesTapToChange(next.label(l10n)),
      onTap: _locked ? null : () => _cycleScript(script),
      combined: true,
    );
  }

  Widget _learningBlock(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final minutes = _state.settings.dailyMinutesFor(_code);
    final cards = (minutes * 60 / 17.5).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Heading(
          icon: Icons.timer_outlined,
          text: l10n.languagesLearningHeading,
        ),
        Text(
          l10n.languagesMinutesLabel(_view.name),
          style: theme.textTheme.labelLarge!.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          children: <Widget>[
            _StepButton(
              key: const ValueKey<String>('minutes-less'),
              icon: Icons.remove,
              label: l10n.languagesMinutesLess,
              disabled: minutesAtEnd(minutes, -1),
              onStep: () => _minutes(-1),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.languagesMinutesMins(minutes),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _StepButton(
              key: const ValueKey<String>('minutes-more'),
              icon: Icons.add,
              label: l10n.languagesMinutesMore,
              disabled: minutesAtEnd(minutes, 1),
              onStep: () => _minutes(1),
            ),
          ],
        ),
        Text(
          l10n.languagesMinutesCards(cards),
          style: theme.textTheme.bodyMedium!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 12, bottom: 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall!.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 2),
          child: Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlainBadge extends StatelessWidget {
  const _PlainBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A round tile at the start of a row: an icon, or a script's glyph.
class _Tile extends StatelessWidget {
  const _Tile({this.icon, this.glyph});

  final IconData? icon;
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: icon != null
            ? Icon(icon, size: 22, color: scheme.onSecondaryContainer)
            : Text(
                glyph ?? '',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 16,
                  height: 1,
                  color: scheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: <Widget>[
            _Tile(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// The minutes stepper's round button: a tap steps once, holding it repeats
/// every 0.3 seconds. Disabled at an end of the range, still announced.
class _StepButton extends StatefulWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.label,
    required this.disabled,
    required this.onStep,
  });

  final IconData icon;
  final String label;
  final bool disabled;
  final VoidCallback onStep;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  Timer? _timer;

  static const Duration _tick = Duration(milliseconds: 300);

  void _down(PointerDownEvent _) {
    if (widget.disabled) return;
    widget.onStep();
    _timer?.cancel();
    _timer = Timer(_tick, () {
      _timer = Timer.periodic(_tick, (_) {
        if (!mounted || widget.disabled) return _stop();
        widget.onStep();
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: !widget.disabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.disabled ? null : widget.onStep,
      child: Listener(
        onPointerDown: _down,
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Opacity(
            opacity: widget.disabled ? 0.38 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: scheme.onSecondaryContainer),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sound test: plays a sample in the language's voice, then says whether
/// it played. Pops true when it did, false on Close.
class _SoundCheckDialog extends StatefulWidget {
  const _SoundCheckDialog({
    required this.state,
    required this.name,
    required this.sample,
    required this.voice,
  });

  final AppState state;
  final String name;
  final String sample;
  final LanguageInfo? voice;

  @override
  State<_SoundCheckDialog> createState() => _SoundCheckDialogState();
}

class _SoundCheckDialogState extends State<_SoundCheckDialog> {
  bool _running = true;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    setState(() => _running = true);
    final voice = widget.voice;
    var ok = true;
    // Decks not on the phone yet: there is no voice to ask, so nothing to
    // fail; the Voices page says what is missing once they are.
    if (voice != null) {
      final error = await widget.state.speak(widget.sample, voice);
      ok = error == null && widget.state.hasVoice(voice);
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _ok = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final title = _running
        ? l10n.languagesCheckSoundTitle
        : _ok
        ? l10n.languagesCheckSoundOk
        : l10n.languagesCheckSoundBad;
    final body = _running
        ? l10n.languagesCheckSoundBody(widget.name)
        : _ok
        ? l10n.languagesCheckSoundOkBody(widget.name)
        : l10n.languagesCheckSoundBadBody(widget.name);
    return AlertDialog(
      icon: Icon(
        _running
            ? Icons.hearing
            : _ok
            ? Icons.check_circle_outline
            : Icons.close,
        color: _running || _ok ? scheme.primary : scheme.error,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(body),
      actions: <Widget>[
        if (_running)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          )
        else if (_ok)
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDone),
          )
        else ...<Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonClose),
          ),
          TextButton(onPressed: _run, child: Text(l10n.languagesTestAgain)),
        ],
      ],
    );
  }
}

/// The i: the language's badge and family tag (#698), how much of B1 is written
/// and the learner's share, its A1 line, dialect, scripts, taught-from, sizes,
/// last update check, units built and words.
class _InfoDialog extends StatelessWidget {
  const _InfoDialog({
    required this.view,
    required this.skills,
    required this.draft,
    required this.state,
    required this.scripts,
    required this.title,
    required this.close,
  });

  final LanguageView view;
  final LanguageSkills skills;
  final bool draft;
  final AppState state;
  final List<String> scripts;
  final String title;
  final String close;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spoken = state.settings.spokenLanguages;
    final course = view.course;
    final progress = course?.progressFor(
      spoken,
      native: state.courseNative(view.code),
    );
    final downloads = state.deckDownloads;
    final tag = stageTag(
      l10n,
      progress?.stage,
      planned: progress?.hasPlan ?? false,
    );
    final share = skills.anyLearn ? state.learnedShare(view.code) : null;
    final onPhone = downloads == null ? 0 : downloads.sizeOnPhone(view.code);
    final checked = downloads?.checkedAt;
    final taught = course?.nativeFor(spoken)?.name;
    final family = languageFamilies.contains(view.language.family)
        ? view.language.family
        : null;

    Widget kv(String label, String value) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelLarge!.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Expanded(child: Text(title)),
          IconButton(
            tooltip: close,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (tag != null) StageTag(tag: tag),
                if (family != null)
                  _PlainBadge(
                    key: const ValueKey<String>('language-family'),
                    text: l10n.knownFamily(family),
                  ),
                if (progress != null && progress.hasPlan)
                  Text(l10n.languagesPercentB1(progress.percent)),
                if (share != null)
                  Text(
                    l10n.languagesYouPercent(B1Progress.percentOf(share)),
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (progress != null) ...<Widget>[
              const SizedBox(height: 12),
              CourseLine(levels: progress.levels),
            ],
            const SizedBox(height: 8),
            if (!view.language.scriptOnly && !view.language.isSign)
              kv(l10n.languagesInfoDialect, dialectOf(l10n, view.language)),
            for (final script in scripts)
              kv(
                scripts.length > 1
                    ? l10n.languagesScriptsRW
                    : l10n.languagesScriptRW,
                l10n.scriptNameOr(script, view.name),
              ),
            if (taught != null) kv(l10n.languagesInfoTaughtFrom, taught),
            if (course == null)
              Text(l10n.languagesInfoNoCourse(view.name))
            else ...<Widget>[
              kv(l10n.languagesInfoSize, formatSize(l10n, course.size)),
              if (!draft) ...<Widget>[
                kv(
                  l10n.languagesInfoOnPhone,
                  onPhone == 0
                      ? l10n.languagesInfoNothingYet
                      : formatSize(l10n, onPhone),
                ),
                kv(
                  l10n.languagesInfoLastCheck,
                  checked == null
                      ? l10n.languagesNeverChecked
                      : DateFormat.MMMEd(l10n.localeName)
                            .add_jm()
                            .format(checked.toLocal()),
                ),
              ],
              if (progress != null) ...<Widget>[
                kv(
                  l10n.languagesInfoUnits,
                  l10n.languagesInfoUnitsValue(
                    progress.unitsWritten,
                    progress.unitCount,
                  ),
                ),
                kv(l10n.languagesInfoWords, '${progress.courseWords}'),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
