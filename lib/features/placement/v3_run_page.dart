import 'package:flutter/material.dart' hide Card;

import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/placement/placement_questions.dart' show PlacementSkill;
import '../../core/placement/v3_result.dart';
import '../../core/placement/v3_session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';
import 'find_level_labels.dart' show FindLevelRecheck;
import 'placement_questions.dart' show PlacementShell;
import 'v3_question_view.dart';
import 'v3_result_page.dart';

/// Two listens in a row, over the whole run, that heard nothing give the
/// microphone up.
const int _unheardLimit = 2;

/// Find my level's V3 run (wiki/Plan-Placement-V3.md, step 7): one question
/// at a time from a [V3Run], the script check first where the course has one,
/// a pause at the soft stop (about 22 questions) with "Keep going" and "See my
/// result", the five-minute budget in the progress wave, and the result at
/// the end.
///
/// Nothing is written while it runs: [onProgress] is told after each change
/// so that the host can save the run (it is resumed within 7 days), and
/// [onFinish] writes the result when the learner presses Done. Leaving
/// part-way (the close button or Back) pauses the run; the page pops with
/// `false`. Done pops with `true`.
class V3RunPage extends StatefulWidget {
  const V3RunPage({
    super.key,
    required this.run,
    required this.restart,
    required this.languageName,
    required this.language,
    required this.native,
    required this.onProgress,
    required this.onFinish,
    this.cardOf,
    this.recheck,
  });

  final V3Run run;

  /// A new run after "I do read it" or "Check the letters again".
  final V3Run Function(V3ScriptStart start) restart;

  final String languageName;
  final LanguageInfo language;
  final LanguageInfo native;

  /// Told after every answer and change: saves the paused run.
  final ValueChanged<V3Run> onProgress;

  /// Writes the result, with the learner's changed starts (a class per
  /// skill). Throws when the write fails.
  final void Function(V3Result result, Map<PlacementSkill, int> overrides)
  onFinish;

  final Card? Function(String id)? cardOf;

  /// A Check again over credit nobody confirmed: the result offers its two
  /// choices in place of Done.
  final FindLevelRecheck? recheck;

  @override
  State<V3RunPage> createState() => _V3RunPageState();
}

class _V3RunPageState extends State<V3RunPage> {
  late V3Run _run = widget.run;
  V3Result? _result;
  bool _failed = false;
  int _unheardInARow = 0;

  void _changed() {
    if (!_run.finished) widget.onProgress(_run);
    setState(() {});
  }

  void _listened({required bool heard}) {
    _unheardInARow = heard ? 0 : _unheardInARow + 1;
    if (_unheardInARow >= _unheardLimit) {
      _unheardInARow = 0;
      _run.giveUpMicrophone();
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.findLevelSkippedSaying,
      );
      _changed();
    }
  }

  void _pause() {
    if (_run.events.isNotEmpty) {
      showAppSnackBar(context, AppLocalizations.of(context)!.findLevelPaused);
    }
    Navigator.of(context).pop(false);
  }

  void _restart(V3ScriptStart start) {
    final run = widget.restart(start);
    widget.onProgress(run);
    setState(() {
      _run = run;
      _result = null;
      _failed = false;
    });
  }

  void _done(Map<PlacementSkill, int> overrides) {
    try {
      widget.onFinish(_result!, overrides);
    } on Object catch (error, stack) {
      debugPrint('Find my level: writing the outcome failed: $error\n$stack');
      setState(() => _failed = true);
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _keepOld(VoidCallback keep) {
    try {
      keep();
    } on Object catch (error, stack) {
      debugPrint('Find my level: writing the choice failed: $error\n$stack');
      showAppSnackBar(
        context,
        AppLocalizations.of(context)!.findLevelFinishFailed,
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final recheck = widget.recheck;
    if (_run.finished) {
      final result = _result ??= V3Result.of(_run);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _pause();
        },
        child: V3ResultPage(
          result: result,
          failed: _failed,
          onDone: _done,
          onRestart: _restart,
          recheck: recheck == null
              ? null
              : FindLevelRecheck(
                  before: recheck.before,
                  onUse: recheck.onUse,
                  onKeep: () => _keepOld(recheck.onKeep),
                ),
        ),
      );
    }
    final question = _run.question;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: question == null
          ? V3SoftStop(
              onKeepGoing: () {
                _run.keepGoing();
                _changed();
              },
              onStop: () {
                _run.stop();
                _changed();
              },
            )
          : PlacementShell(
              onClose: _pause,
              deckName: widget.languageName,
              // The wave is the share of the five minutes and 40 questions
              // used.
              progress: _run.progress,
              reportDetail: '${question.id} in find my level',
              child: V3QuestionView(
                key: ValueKey<String>('${question.id}#${_run.answered}'),
                question: question,
                number: _run.number,
                language: widget.language,
                native: widget.native,
                run: _run,
                cardOf: widget.cardOf,
                onChanged: _changed,
                onListened: _listened,
              ),
            ),
    );
  }
}

/// The pause at the soft stop: the check could end here, or go on for a
/// sharper answer.
class V3SoftStop extends StatelessWidget {
  const V3SoftStop({
    super.key,
    required this.onKeepGoing,
    required this.onStop,
  });

  final VoidCallback onKeepGoing;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
                      l10n.findLevelSoftStopTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.findLevelSoftStopBody,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton(
                    key: const ValueKey<String>('find-level-see-result'),
                    style: AppButtonStyles.tall(context),
                    onPressed: onStop,
                    child: Text(l10n.findLevelSeeResult),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey<String>('find-level-keep-going'),
                    style: AppButtonStyles.tall(context),
                    onPressed: onKeepGoing,
                    child: Text(l10n.findLevelKeepGoing),
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
