import 'package:flutter/material.dart';

import '../../core/placement/joint_model.dart' show PlacementConfidence;
import '../../core/placement/placement_questions.dart' show PlacementSkill;
import '../../core/placement/script_gate.dart' show ScriptLevel;
import '../../core/placement/v3_result.dart';
import '../../core/placement/v3_session.dart' show V3ScriptStart, V3Why;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'find_level_comparison.dart' show FindLevelRecheck;
import 'find_level_summary.dart' show findLevelSkillName;

/// The word for a confidence (how likely the true level is within a tenth of
/// the middle of the range): never a probability of "none" and never
/// "Verified".
String findLevelConfidenceWord(
  AppLocalizations l10n,
  PlacementConfidence confidence,
) => switch (confidence) {
  PlacementConfidence.high => l10n.findLevelLabelSure,
  PlacementConfidence.medium => l10n.findLevelLabelFairlySure,
  PlacementConfidence.low => l10n.findLevelLabelNotSureYet,
};

/// The headline of a placed skill: "Read: start at unit 14".
String findLevelResultHeadline(AppLocalizations l10n, V3SkillResult s) {
  final name = findLevelSkillName(l10n, s.skill);
  return switch (s.status) {
    V3Status.placed =>
      s.startUnit <= 0
          ? l10n.findLevelResultStartBeginning(name)
          : l10n.findLevelResultStart(name, s.startUnit),
    V3Status.selfRated => l10n.findLevelResultSelfRated(name),
    V3Status.needsScript => l10n.findLevelResultNeedsScript(name),
    V3Status.notTested => l10n.findLevelResultNotTested(name, switch (s.why) {
      V3Why.noDevice =>
        s.skill == PlacementSkill.say
            ? l10n.findLevelReasonNoMic
            : l10n.findLevelReasonNoSound,
      _ => l10n.findLevelReasonNotEnough,
    }),
  };
}

/// "Likely between unit 11 and unit 17" (the 80% range of a placed skill).
String findLevelResultRange(AppLocalizations l10n, V3SkillResult s) {
  if (s.highUnit <= s.lowUnit) return l10n.findLevelResultRangeOne(s.lowUnit);
  if (s.lowUnit <= 0) return l10n.findLevelResultRangeBeginning(s.highUnit);
  return l10n.findLevelResultRange(s.lowUnit, s.highUnit);
}

/// The end of a V3 run (wiki/Plan-Placement-V3.md, step 7): per skill a start
/// unit with the range the run is 80% sure of and a confidence word, or the
/// reason it was not placed; a way to change a start; and, when Read and
/// Write wait for the script, why and the way to check again.
class V3ResultPage extends StatefulWidget {
  const V3ResultPage({
    super.key,
    required this.result,
    required this.onDone,
    required this.onRestart,
    this.recheck,
    this.failed = false,
  });

  final V3Result result;

  /// Writes the result with the learner's changes (a class per skill).
  final void Function(Map<PlacementSkill, int> overrides) onDone;

  /// "I do read it" and "Check the letters again": a new run.
  final ValueChanged<V3ScriptStart> onRestart;

  /// A Check again over credit nobody confirmed: the two choices replace
  /// Done, and [FindLevelRecheck.before] says what the learner held.
  final FindLevelRecheck? recheck;

  /// Writing the result threw: say so (the run is kept, so Done tries again).
  final bool failed;

  @override
  State<V3ResultPage> createState() => _V3ResultPageState();
}

class _V3ResultPageState extends State<V3ResultPage> {
  /// The learner's changed starts, as a class of the path.
  final Map<PlacementSkill, int> _overrides = <PlacementSkill, int>{};

  V3Result get _r => widget.result;

  int _unitOfClass(int c) => c == 0 ? 0 : _r.levels.levelOf(c) + 1;

  /// The highest class whose unit is at most [unit].
  int _classOfUnit(int unit) {
    for (var c = _r.levels.topClass; c > 0; c--) {
      if (_unitOfClass(c) <= unit) return c;
    }
    return 0;
  }

  Future<void> _change(V3SkillResult s) async {
    final l10n = AppLocalizations.of(context)!;
    final top = _unitOfClass(_r.levels.topClass);
    var unit = _unitOfClass(_overrides[s.skill] ?? s.startClass);
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            l10n.findLevelChangeTitle(findLevelSkillName(l10n, s.skill)),
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                key: const ValueKey<String>('find-level-change-less'),
                tooltip: l10n.findLevelChangeLess,
                onPressed: unit > 0
                    ? () => setState(
                        () => unit = _unitOfClass(_classOfUnit(unit - 1)),
                      )
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  '$unit',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                key: const ValueKey<String>('find-level-change-more'),
                tooltip: l10n.findLevelChangeMore,
                onPressed: unit < top
                    ? () => setState(() {
                        var c = _classOfUnit(unit);
                        c = (c + 1).clamp(0, _r.levels.topClass);
                        unit = _unitOfClass(c);
                      })
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              key: const ValueKey<String>('find-level-change-use'),
              onPressed: () => Navigator.of(context).pop(_classOfUnit(unit)),
              child: Text(l10n.findLevelChangeUse),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _overrides[s.skill] = chosen);
    }
  }

  Widget _skill(BuildContext context, V3SkillResult s) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final changed = _overrides[s.skill];
    final shown = changed == null
        ? s
        : V3SkillResult(
            skill: s.skill,
            status: V3Status.placed,
            startUnit: _unitOfClass(changed),
            lowUnit: _unitOfClass(changed),
            highUnit: _unitOfClass(changed),
            startClass: changed,
            confidence: PlacementConfidence.high,
          );
    final headline = findLevelResultHeadline(l10n, shown);
    final lines = <String>[
      if (shown.placed && changed == null && s.rangeShown)
        findLevelResultRange(l10n, s),
      if (shown.placed && changed == null && s.confidence != null)
        findLevelConfidenceWord(l10n, s.confidence!),
      if (s.status == V3Status.selfRated) l10n.findLevelResultSelfRatedBody,
      if (s.status == V3Status.needsScript) l10n.findLevelResultNeedsScriptBody,
      if (changed == null &&
          shown.placed &&
          s.confidence == PlacementConfidence.low)
        l10n.findLevelNoteNotSureYet,
    ];
    return Semantics(
      container: true,
      child: Padding(
        key: ValueKey<String>('find-level-result-${s.skill.name}'),
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(headline, style: theme.textTheme.titleMedium),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  line,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (s.placed)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: ValueKey<String>('find-level-change-${s.skill.name}'),
                  onPressed: () => _change(s),
                  child: Text(l10n.findLevelChange),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final recheck = widget.recheck;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.gutter),
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.findLevelResultTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.findLevelResultIntro,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final s in _r.skills) _skill(context, s),
                  if (recheck != null)
                    for (final s in _r.skills)
                      if (recheck.before[s.skill] case final before?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            l10n.findLevelCompareLine(
                              findLevelSkillName(l10n, s.skill),
                              l10n.findLevelCompareUnit(before + 1),
                              s.startUnit <= 0
                                  ? l10n.findLevelCompareStart
                                  : l10n.findLevelCompareUnit(s.startUnit),
                              s.confidence == null
                                  ? ''
                                  : findLevelConfidenceWord(
                                      l10n,
                                      s.confidence!,
                                    ),
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                  if (_r.script?.level == ScriptLevel.partly)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        l10n.findLevelScriptPartly,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_r.needsScript) ...<Widget>[
                    FilledButton(
                      key: const ValueKey<String>('find-level-i-read-it'),
                      style: AppButtonStyles.tall(context),
                      onPressed: () => widget.onRestart(V3ScriptStart.skip),
                      child: Text(l10n.findLevelIReadIt),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const ValueKey<String>('find-level-check-letters'),
                      style: AppButtonStyles.tall(context),
                      onPressed: () => widget.onRestart(V3ScriptStart.ask),
                      child: Text(l10n.findLevelCheckLetters),
                    ),
                  ],
                  if (widget.failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        l10n.findLevelFinishFailed,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.gutter),
              child: recheck == null
                  ? SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey<String>('find-level-done'),
                        style: AppButtonStyles.tall(context),
                        onPressed: () => widget.onDone(_overrides),
                        child: Text(l10n.languagesDone),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        FilledButton(
                          key: const ValueKey<String>('find-level-use-new'),
                          style: AppButtonStyles.tall(context),
                          onPressed: () => widget.onDone(_overrides),
                          child: Text(l10n.findLevelUseNew),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          key: const ValueKey<String>('find-level-keep-old'),
                          style: AppButtonStyles.tall(context),
                          onPressed: recheck.onKeep,
                          child: Text(l10n.findLevelKeepOld),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
