import 'package:flutter/material.dart' hide Card;

import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/placement/placement_session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';
import 'find_level_question.dart';
import 'find_level_summary.dart';
import 'placement_questions.dart' show PlacementShell;

/// Find my level's run (wiki/Plan-Placement-V2.md, section 5): one question
/// at a time from a [PlacementSession], with no fixed total, a checkpoint at
/// every 25 questions, and a minimal summary at the end.
///
/// Nothing is written while it runs: [onProgress] is told after each answer
/// so that the host can save the run (it is resumed within 7 days), and
/// [onFinish] is called once when the run ends or the learner stops, to
/// write the outcome. Leaving part-way (the close button or Back) pauses the
/// run; the page pops with `false`. Done on the summary pops with `true`.
class FindLevelRunPage extends StatefulWidget {
  const FindLevelRunPage({
    super.key,
    required this.session,
    required this.languageName,
    required this.language,
    required this.native,
    required this.onProgress,
    required this.onFinish,
    this.cardOf,
  });

  final PlacementSession session;

  /// The language's name, above each question.
  final String languageName;

  /// The language learned, as its decks write it.
  final LanguageInfo language;

  /// The language the course is taught from.
  final LanguageInfo native;

  /// Told after every answer, checkpoint choice and microphone change.
  final ValueChanged<PlacementSession> onProgress;

  /// Told once, when the run ends: writes the outcome.
  final ValueChanged<PlacementSession> onFinish;

  final Card? Function(String id)? cardOf;

  @override
  State<FindLevelRunPage> createState() => _FindLevelRunPageState();
}

class _FindLevelRunPageState extends State<FindLevelRunPage> {
  bool _finished = false;

  PlacementSession get _session => widget.session;

  void _afterChange() {
    widget.onProgress(_session);
    if (_session.isDone) _finish();
  }

  void _finish() {
    if (_finished) return;
    setState(() => _finished = true);
    widget.onFinish(_session);
  }

  void _answer(bool right) {
    setState(() => _session.answer(right));
    _afterChange();
  }

  void _giveUpMicrophone() {
    setState(_session.dropMicrophone);
    showAppSnackBar(
      context,
      AppLocalizations.of(context)!.findLevelSkippedSaying,
    );
    _afterChange();
  }

  void _keepGoing() {
    setState(_session.keepGoing);
    _afterChange();
  }

  /// The close button and Back: the run is kept, and nothing is written.
  void _pause() {
    if (_session.events.isNotEmpty) {
      showAppSnackBar(context, AppLocalizations.of(context)!.findLevelPaused);
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_finished) {
      return FindLevelSummary(
        run: _session.run,
        onDone: () => Navigator.of(context).pop(true),
      );
    }
    if (_session.isDone) {
      // A run that has nothing to ask (or resumed at its end): write it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finish();
      });
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.learnLoading),
        ),
      );
    }
    final question = _session.question;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: question == null
          ? FindLevelCheckpoint(
              count: _session.asked,
              lines: findLevelStandings(l10n, _session.run),
              onKeepGoing: _keepGoing,
              onStop: _finish,
            )
          : PlacementShell(
              onClose: _pause,
              deckName: widget.languageName,
              // Placement has no total: the wave only grows with the
              // questions asked.
              progress: _session.asked / (_session.asked + 12),
              reportDetail:
                  '${question.cardId ?? '-'} in find my level '
                  '${question.request.variant.label}',
              child: FindLevelQuestionView(
                key: ValueKey<Object>(question),
                question: question,
                number: _session.asked + 1,
                language: widget.language,
                native: widget.native,
                cardOf: widget.cardOf,
                onAnswer: _answer,
                onGiveUpMicrophone: _giveUpMicrophone,
              ),
            ),
    );
  }
}

/// The pause every 25 questions (section 5.4): where the learner stands, per
/// skill, and the choice to keep going or stop here.
class FindLevelCheckpoint extends StatelessWidget {
  const FindLevelCheckpoint({
    super.key,
    required this.count,
    required this.lines,
    required this.onKeepGoing,
    required this.onStop,
  });

  final int count;
  final List<String> lines;
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
                  Text(
                    l10n.findLevelCheckpointTitle(count),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.findLevelCheckpointBody,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(line, style: theme.textTheme.titleMedium),
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
                    key: const ValueKey<String>('find-level-keep-going'),
                    style: AppButtonStyles.tall(context),
                    onPressed: onKeepGoing,
                    child: Text(l10n.findLevelKeepGoing),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey<String>('find-level-stop-here'),
                    style: AppButtonStyles.tall(context),
                    onPressed: onStop,
                    child: Text(l10n.findLevelStopHere),
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
