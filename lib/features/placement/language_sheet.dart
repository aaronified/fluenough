import 'package:flutter/material.dart';

import '../../core/decks/language_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/theme.dart';
import '../profiles/spoken_languages_picker.dart' show PickerHeading;
import 'course_line.dart';
import 'language_card.dart' show NativeChoiceField;
import 'language_row.dart';

/// What the sheet of Languages I'm learning says about one of a language's
/// scripts (#626): learning it already, or a choice to make.
@immutable
class SheetScript {
  const SheetScript({
    required this.code,
    this.reads = false,
    this.learning = false,
    this.decks,
    this.progress,
    this.sharedLearning = const <String>[],
    this.sharedKnown = const <String>[],
  });

  /// The script, as the decks name it: `devanagari`, `perso_arabic`.
  final String code;

  /// Whether the learner already reads it, through a language they know.
  final bool reads;

  /// Whether a learned language is learning it now.
  final bool learning;

  /// How many decks learning it includes, where the decks are on the phone.
  final int? decks;

  /// The learner's progress in its script decks, where they are on the
  /// phone: decks learned of all, and the share of their cards.
  final ({int decks, int learnedDecks, double share})? progress;

  /// The languages the learner learns, and those they know, that are
  /// written in it too, by their English names.
  final List<String> sharedLearning;
  final List<String> sharedKnown;
}

/// What the sheet answers.
enum SheetAction { learn, stop, find }

/// The sheet's answer (#626): learn the language with these scripts and
/// where to start, stop learning it, or find the learner's level in it.
@immutable
class SheetReply {
  const SheetReply.learn({
    required this.scripts,
    required this.findLanguage,
    required this.findScripts,
    this.native,
    this.scriptPassed = false,
  }) : action = SheetAction.learn;
  const SheetReply.stop()
    : action = SheetAction.stop,
      scripts = const <String>{},
      findLanguage = true,
      findScripts = const <String, bool>{},
      native = null,
      scriptPassed = false;
  const SheetReply.find()
    : action = SheetAction.find,
      scripts = const <String>{},
      findLanguage = true,
      findScripts = const <String, bool>{},
      native = null,
      scriptPassed = false;

  final SheetAction action;

  /// The scripts to learn, `learn` only. None is Latin letters only.
  final Set<String> scripts;

  /// Whether to find the learner's level in the language, or start at its
  /// beginning, and the same for each script (#481).
  final bool findLanguage;
  final Map<String, bool> findScripts;

  /// The language it is learned from, where the learner chose.
  final String? native;

  /// Whether the script test was passed in the sheet (#554).
  final bool scriptPassed;
}

/// Scripts written from right to left.
const Set<String> _rightToLeft = <String>{
  'arabic',
  'perso_arabic',
  'shahmukhi',
};

/// A language's bottom sheet in Languages I'm learning (#626, the approved
/// mockup `docs/mockups/languages-learning.html`). Its first screen holds the
/// course: how much is written, the course line (A1, A2, B1, culture), what
/// it is taught from, its size and units; for a language learned, "Find my
/// level" and its scripts' progress. "Learn this language", or "Stop
/// learning" for one learned, is fixed at the bottom, outside the scroll.
/// Learning leads to two more screens, each with Back: which scripts to
/// learn, one option for each script the language has; then where to start,
/// "Find my level" or "Start at the beginning", for the language and each
/// script chosen. Nothing is saved here: the page applies the answer when
/// Continue is pressed.
class LanguageSheet extends StatefulWidget {
  const LanguageSheet({
    super.key,
    required this.language,
    required this.spoken,
    required this.learned,
    required this.chosen,
    required this.knows,
    required this.scripts,
    required this.initialScripts,
    required this.storage,
    this.you,
    this.native,
    this.hasPlacement = true,
    this.findLanguage = true,
    this.findScripts = const <String, bool>{},
    this.confirmStop,
    this.scriptTest,
    this.scriptPassed = false,
  });

  final CatalogLanguage language;

  /// The languages the learner speaks, best known first.
  final List<String> spoken;

  /// Whether the learner learns it already.
  final bool learned;

  /// Whether it is newly chosen on this page, not saved yet.
  final bool chosen;

  /// Whether the learner knows the language: then learning it can be for a
  /// script alone.
  final bool knows;

  /// The scripts it has to learn, one option each; none for a language
  /// without script decks.
  final List<SheetScript> scripts;

  /// The scripts ticked when the sheet opens.
  final Set<String> initialScripts;

  /// "On the phone · 412 KB", or "Not on the phone · 4.1 MB".
  final String storage;

  /// "You: 8% of B1", or the words learned, for a language learned.
  final String? you;

  /// The language it is taught from, where the learner chose or the app
  /// suggests.
  final String? native;

  /// Whether there is a level to find: false for the IPA.
  final bool hasPlacement;

  /// Where to start, as chosen before: for the language and each script.
  final bool findLanguage;
  final Map<String, bool> findScripts;

  /// Asks whether to stop learning a language that is learned or chosen;
  /// the sheet closes only on yes.
  final Future<bool> Function()? confirmStop;

  /// The script test's offer (#554) for the language's own script, for a
  /// learner who reads it through another language they know, or null:
  /// whether the lessons are skipped now, and what to call with the result
  /// of a test.
  final Widget? Function(
    BuildContext context,
    bool passed,
    ValueChanged<bool> onResult,
  )?
  scriptTest;

  /// Whether the script test was passed before.
  final bool scriptPassed;

  @override
  State<LanguageSheet> createState() => _LanguageSheetState();
}

/// The screens of the sheet.
enum _Step { course, scripts, start }

class _LanguageSheetState extends State<LanguageSheet> {
  _Step _step = _Step.course;
  late final Set<String> _scripts = <String>{...widget.initialScripts};
  late bool _findLanguage = widget.findLanguage;
  late final Map<String, bool> _findScripts = <String, bool>{
    ...widget.findScripts,
  };
  late String? _native = widget.native;
  late bool _passed = widget.scriptPassed;

  bool get _hasScripts => widget.scripts.isNotEmpty;

  /// What step 2 asks about, in order: the language and each script chosen
  /// (a language learned asks only about a script added now; one the learner
  /// speaks is placed as a whole too, until scripts are placed apart: #481),
  /// when there is more than the language to place.
  List<String?> get _entries {
    final chosen = <String>[
      for (final s in widget.scripts)
        if (_scripts.contains(s.code)) s.code,
    ];
    if (widget.learned) {
      return <String?>[
        for (final code in chosen)
          if (!widget.initialScripts.contains(code)) code,
      ];
    }
    return <String?>[null, if (chosen.length > 1) ...chosen];
  }

  bool get _hasStart => widget.hasPlacement && _entries.isNotEmpty;

  void _learn() => Navigator.of(context).pop(
    SheetReply.learn(
      scripts: _scripts,
      findLanguage: _findLanguage,
      findScripts: <String, bool>{
        for (final code in _scripts) code: _findScripts[code] ?? true,
      },
      native: _native,
      scriptPassed: _passed,
    ),
  );

  void _afterCourse() {
    if (_hasScripts) {
      setState(() => _step = _Step.scripts);
    } else if (_hasStart) {
      setState(() => _step = _Step.start);
    } else {
      _learn();
    }
  }

  void _afterScripts() {
    if (_hasStart) {
      setState(() => _step = _Step.start);
    } else {
      _learn();
    }
  }

  Future<void> _stop() async {
    final ask = widget.confirmStop;
    if (ask != null && !await ask()) return;
    if (mounted) Navigator.of(context).pop(const SheetReply.stop());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = widget.language;
    final spoken = widget.spoken;
    final progress = language.progressFor(spoken, native: _native);
    final tag = stageTag(
      l10n,
      progress?.stage,
      planned: progress?.hasPlan ?? false,
    );
    final writing = progress != null && progress.hasPlan;
    final total = (_hasScripts ? 1 : 0) + (_hasStart ? 1 : 0);
    final number = _step == _Step.scripts ? 1 : (_hasScripts ? 2 : 1);
    final step = switch (_step) {
      _Step.course => null,
      _Step.scripts => l10n.pickerStepScripts(number, total),
      _Step.start =>
        total < 2
            ? l10n.pickerStepStartOnly
            : l10n.pickerStepStart(number, total),
    };
    final body = switch (_step) {
      _Step.course => _course(context, progress),
      _Step.scripts => _scriptsStep(context),
      _Step.start => _startStep(context),
    };
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (step != null)
                  Text(
                    step,
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Semantics(
                  header: true,
                  namesRoute: true,
                  child: Text.rich(
                    languageNames(context, language),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (_step == _Step.course) ...<Widget>[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (tag != null) StageTag(tag: tag),
                      if (writing)
                        Text(
                          l10n.pickerWritten(progress.percent),
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (widget.you case final you?)
                        Text(
                          you,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey<String>('sheet-scroll'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[body, const SizedBox(height: 8)],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
            child: _bottom(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // First screen

  Widget _course(BuildContext context, B1Progress? progress) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = widget.language;
    final writing = progress != null && progress.hasPlan;
    final tag = stageTag(l10n, progress?.stage, planned: writing);
    final options = language.spokenNatives(widget.spoken);
    final nativeCode = _native ?? language.nativeFor(widget.spoken)?.code;
    final nativeName = language.natives
        .where((n) => n.code == nativeCode)
        .map((n) => n.name)
        .firstOrNull;
    final names = <String>[
      for (final s in widget.scripts) l10n.scriptNameOr(s.code, language.name),
    ];
    final readsNames = <String>[
      for (final s in widget.scripts)
        if (s.reads) l10n.scriptNameOr(s.code, language.name),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.learned && widget.hasPlacement) ...<Widget>[
          PickerHeading(l10n.pickerSectionLevel),
          _Block(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${l10n.pickerFindBody(language.name)}'
                    '${widget.scripts.length > 1 ? ' ${l10n.pickerFindEachScript}' : ''}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  key: const ValueKey<String>('sheet-find'),
                  onPressed: () =>
                      Navigator.of(context).pop(const SheetReply.find()),
                  child: Text(l10n.placementFind),
                ),
              ],
            ),
          ),
        ],
        if (widget.learned && _hasScripts) ...<Widget>[
          PickerHeading(l10n.pickerSectionScripts),
          for (final script in widget.scripts) _learnedScript(context, script),
        ] else if (!widget.learned && widget.knows) ...<Widget>[
          PickerHeading(l10n.pickerSectionKnow),
          _Block(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  readsNames.isEmpty
                      ? l10n.pickerKnowSpeaks(language.name)
                      : l10n.pickerKnowReads(
                          language.name,
                          readsNames.join(l10n.commonListSeparator),
                        ),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  l10n.pickerKnowBody(language.name),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
        PickerHeading(l10n.pickerSectionCourse),
        if (progress != null && progress.hasPlan)
          _Block(child: CourseLine(levels: progress.levels)),
        if (progress != null)
          _Kv(
            label: writing
                ? l10n.pickerSheetWritten
                : l10n.pickerSheetCourseSize,
            value: writing
                ? l10n.pickerSheetWrittenValue(
                    progress.percent,
                    tag?.text ?? '',
                  )
                : l10n.pickerCourseSize(progress.courseWords),
            sub: writing ? tag?.label : null,
          ),
        if (names.isNotEmpty)
          _Kv(
            label: l10n.pickerSheetScript(names.length),
            value: names.join(l10n.commonListSeparator),
          ),
        if (!widget.learned && options.length >= 2 && _native != null)
          _Block(
            child: NativeChoiceField(
              language: language,
              options: options,
              chosen: _native!,
              onChosen: (picked) => setState(() => _native = picked),
            ),
          )
        else if (nativeName != null)
          _Kv(label: l10n.pickerTaughtFrom, value: nativeName),
        _Kv(label: l10n.pickerSheetSize, value: widget.storage),
        if (progress != null)
          _Kv(
            label: l10n.pickerSheetUnits,
            value: l10n.pickerUnitsWritten(
              progress.unitsWritten,
              progress.unitCount,
            ),
          ),
      ],
    );
  }

  /// A script of a learned language: its progress, or "Add this script".
  Widget _learnedScript(BuildContext context, SheetScript script) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final name = l10n.scriptNameOr(script.code, widget.language.name);
    final progress = script.progress;
    return _Block(
      key: ValueKey<String>('sheet-learned-${script.code}'),
      child: !script.learning
          ? Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        l10n.pickerScriptNotLearning,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const ValueKey<String>('sheet-add-script'),
                  onPressed: () => setState(() => _step = _Step.scripts),
                  child: Text(l10n.pickerAddScript),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.pickerScriptLearning(name),
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  progress == null
                      ? l10n.pickerScriptDecksSome
                      : l10n.pickerScriptDecksLearned(
                          progress.learnedDecks,
                          progress.decks,
                        ),
                  style: theme.textTheme.bodyLarge,
                ),
                if (progress != null) ...<Widget>[
                  const SizedBox(height: 6),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress.share,
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
                ..._sharedNotes(context, script),
                // The script test (#554), to take or retake for the script
                // the language's lessons teach.
                if (script.code == widget.language.script)
                  if (widget.scriptTest?.call(
                        context,
                        _passed,
                        (passed) => setState(() => _passed = passed),
                      )
                      case final offer?)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 8),
                      child: offer,
                    ),
              ],
            ),
    );
  }

  List<Widget> _sharedNotes(BuildContext context, SheetScript script) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final name = l10n.scriptNameOr(script.code, widget.language.name);
    String join(List<String> names) => names.join(l10n.commonListSeparator);
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return <Widget>[
      if (script.sharedLearning.isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 6),
          child: Text(
            l10n.pickerScriptSharedLearning(name, join(script.sharedLearning)),
            style: style,
          ),
        ),
      if (script.sharedKnown.isNotEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 6),
          child: Text(
            l10n.pickerScriptSharedKnown(name, join(script.sharedKnown)),
            style: style,
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Step 1: the scripts

  Widget _scriptsStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PickerHeading(
          l10n.pickerScriptsHeading,
          note: l10n.pickerScriptsPickAny,
        ),
        for (final script in widget.scripts) ...<Widget>[
          CheckboxListTile(
            key: ValueKey<String>('sheet-script-${script.code}'),
            controlAffinity: ListTileControlAffinity.trailing,
            contentPadding: const EdgeInsetsDirectional.only(
              start: 24,
              end: 12,
            ),
            title: Text(
              l10n.scriptNameOr(script.code, widget.language.name),
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.pickerScriptDirection(
                    _rightToLeft.contains(script.code) ? 'rtl' : 'ltr',
                  ),
                ),
                if (script.reads) Text(l10n.pickerScriptYouRead),
                if (script.decks case final decks?)
                  Text(l10n.pickerScriptDecks(decks)),
                ..._sharedNotes(context, script),
              ],
            ),
            value: _scripts.contains(script.code),
            onChanged: (on) => setState(
              () => (on ?? false)
                  ? _scripts.add(script.code)
                  : _scripts.remove(script.code),
            ),
          ),
          if (script.code == widget.language.script &&
              _scripts.contains(script.code))
            if (widget.scriptTest?.call(
                  context,
                  _passed,
                  (passed) => setState(() => _passed = passed),
                )
                case final offer?)
              _Block(child: offer),
        ],
        _Block(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.pickerScriptsNone,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: where to start

  Widget _startStep(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = widget.language;
    final entries = _entries;
    Widget notice(String text) => _Block(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final entry in entries) ...<Widget>[
          PickerHeading(
            entry == null
                ? l10n.pickerStartLanguage(language.name)
                : l10n.pickerStartScript(
                    l10n.scriptNameOr(entry, language.name),
                  ),
          ),
          RadioGroup<bool>(
            groupValue: entry == null
                ? _findLanguage
                : _findScripts[entry] ?? true,
            onChanged: (find) => setState(() {
              if (entry == null) {
                _findLanguage = find ?? true;
              } else {
                _findScripts[entry] = find ?? true;
              }
            }),
            child: Column(
              children: <Widget>[
                RadioListTile<bool>(
                  key: ValueKey<String>('sheet-find-${entry ?? 'language'}'),
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: 24,
                    end: 12,
                  ),
                  value: true,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(l10n.placementFind),
                  subtitle: Text(
                    entry == null
                        ? l10n.pickerFindLanguageBody
                        : l10n.pickerFindScriptBody,
                  ),
                ),
                RadioListTile<bool>(
                  key: ValueKey<String>('sheet-begin-${entry ?? 'language'}'),
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: 24,
                    end: 12,
                  ),
                  value: false,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(l10n.pickerStartBeginning),
                  subtitle: Text(
                    entry == null
                        ? l10n.pickerBeginLanguageBody
                        : l10n.pickerBeginScriptBody,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (entries.length > 1) notice(l10n.pickerStartSeparately),
        notice(l10n.pickerStartApplied),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // The fixed bottom

  Widget _bottom(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_step) {
      case _Step.course:
        return widget.learned || widget.chosen
            ? OutlinedButton(
                key: const ValueKey<String>('sheet-stop'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _stop,
                child: Text(l10n.pickerStopConfirm),
              )
            : FilledButton(
                key: const ValueKey<String>('sheet-learn'),
                style: AppButtonStyles.tall(context),
                onPressed: _afterCourse,
                child: Text(l10n.pickerLearnThis),
              );
      case _Step.scripts:
        return _stepButtons(
          back: () => setState(() => _step = _Step.course),
          forward: _afterScripts,
          label: _hasStart ? l10n.pickerNext : l10n.commonDone,
          key: _hasStart ? 'sheet-next' : 'sheet-done',
        );
      case _Step.start:
        return _stepButtons(
          back: () => setState(
            () => _step = _hasScripts ? _Step.scripts : _Step.course,
          ),
          forward: _learn,
          label: l10n.commonDone,
          key: 'sheet-done',
        );
    }
  }

  Widget _stepButtons({
    required VoidCallback back,
    required VoidCallback forward,
    required String label,
    required String key,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: <Widget>[
        TextButton.icon(
          key: const ValueKey<String>('sheet-back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: back,
          label: Text(l10n.commonBack),
        ),
        const Spacer(),
        FilledButton(
          key: ValueKey<String>(key),
          onPressed: forward,
          child: Text(label),
        ),
      ],
    );
  }
}

/// A block of the sheet on the 24 px line.
class _Block extends StatelessWidget {
  const _Block({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 24, 8),
    child: child,
  );
}

/// A fact about the course: its label, its value, and a line under it.
class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return _Block(
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelLarge!.copyWith(color: muted),
            ),
            Text(value, style: theme.textTheme.bodyLarge),
            if (sub != null)
              Text(
                sub!,
                style: theme.textTheme.bodyMedium!.copyWith(color: muted),
              ),
          ],
        ),
      ),
    );
  }
}
