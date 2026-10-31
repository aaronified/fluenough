import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/review/question_log.dart';
import '../../l10n/app_localizations.dart';

/// The choice of how many daily questions a day (#519, owner, 2026-10-13:
/// "decided by the user during reviewer onboarding", default 10): one chip
/// each, 0 meaning off. Used in How reviewing works, and in Settings under
/// Reviewing through [showQuestionsPerDay].
class QuestionsPerDayChoice extends StatelessWidget {
  const QuestionsPerDayChoice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reviewing = AppScope.of(context).reviewing;
    return ListenableBuilder(
      listenable: AppScope.of(context).settings,
      builder: (context, _) => Semantics(
        container: true,
        label: l10n.reviewQuestionsPerDayTitle,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final count in questionsPerDayChoices)
              ChoiceChip(
                label: Text(
                  count == 0
                      ? l10n.reviewQuestionsPerDayOff
                      : l10n.reviewQuestionsPerDayChoice(count),
                ),
                selected: reviewing.questionsPerDay == count,
                onSelected: (_) => reviewing.questionsPerDay = count,
              ),
          ],
        ),
      ),
    );
  }
}

/// Settings > Reviewing > Questions a day: the choice in a dialog.
Future<void> showQuestionsPerDay(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.reviewQuestionsPerDayTitle),
      content: const QuestionsPerDayChoice(),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.reviewHowGotIt),
        ),
      ],
    );
  },
);
