import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/models/reading.dart' show ReadingQuestion;
import '../../core/models/recommendation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';
import 'culture_parts.dart';
import 'recommendations_page.dart' show briefingLine;

/// What opens the questions of a completed work.
class WorkQuestionsRequest {
  const WorkQuestionsRequest({
    required this.language,
    required this.recommendationId,
  });

  final String language;
  final String recommendationId;
}

/// The comprehension questions of a work the learner completed (approved
/// mockup `culture-recommendations`, screen 4): one at a time with choices, in
/// the language the learner reads best of those the question is written in;
/// a right choice is marked, a miss shows what to re-read. Not graded against a
/// score, and nothing is written to the review log here: the same questions
/// come back in lessons and reviews as reading items, scheduled, for as long as
/// the work is marked completed.
class WorkQuestionsPage extends StatefulWidget {
  const WorkQuestionsPage({super.key, required this.request});

  final WorkQuestionsRequest request;

  @override
  State<WorkQuestionsPage> createState() => _WorkQuestionsPageState();
}

class _WorkQuestionsPageState extends State<WorkQuestionsPage> {
  int _index = 0;
  int? _chosen;
  int _right = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final request = widget.request;
    final work = state.catalogWithAboveLevel.recommendations[request.language]
        ?.byId(request.recommendationId);
    if (work == null) {
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: state.status == CatalogStatus.loading
            ? Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.commonLoadingDecks,
                ),
              )
            : EmptyState(
                icon: Icons.quiz_outlined,
                title: l10n.recWorkNotFound,
              ),
      );
    }
    return ListenableBuilder(
      listenable: state.recommendationProgress,
      builder: (context, _) => _build(context, state, work),
    );
  }

  Widget _build(BuildContext context, AppState state, Recommendation work) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = cultureLanguage(state, widget.request.language);
    final spoken = cultureSpoken(context, state);
    final questions = state.recommendationProgress.questionsOf(work);
    final appBar = AppBar(
      title: Text(work.title, style: theme.textTheme.titleMedium),
      actions: const <Widget>[ReportButton()],
    );
    if (questions.isEmpty) {
      return Scaffold(
        appBar: appBar,
        body: EmptyState(
          icon: Icons.quiz_outlined,
          title: work.questions.isEmpty
              ? l10n.recNoQuestions
              : l10n.recQuestionsLocked,
          body: work.questions.isEmpty ? null : l10n.recQuestionsLockedBody,
        ),
      );
    }
    final finished = _index >= questions.length;
    if (finished) {
      return Scaffold(
        appBar: appBar,
        body: EmptyState(
          icon: Icons.check_circle_outline,
          title: l10n.recQuestionsDone,
          body: l10n.recQuestionsScore(_right, questions.length),
          action: FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.commonDone),
          ),
        ),
      );
    }
    final question = questions[_index];
    final lang = question.languageFor(spoken);
    String text(Map<String, String> by) =>
        by[lang] ?? by['en'] ?? (by.values.isEmpty ? '' : by.values.first);
    final options = <String>[
      if (question.isTrueFalse) ...<String>[
        l10n.readingTrue,
        l10n.readingFalse,
      ] else
        for (final o in question.options) text(o),
    ];
    final answered = _chosen != null;
    final right = answered && question.isRight(_chosen!);
    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          16,
          8,
          16,
          24,
        ).clearingSystemBar(context),
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Text(
              l10n.recQuestionsIntro(info.name),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.recQuestionOf(_index + 1, questions.length),
                style: theme.textTheme.titleSmall!.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Text(
              text(question.prompt),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, option) in options.indexed)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: _Option(
                label: option,
                state: !answered
                    ? _OptionState.idle
                    : question.isRight(i)
                    ? _OptionState.right
                    : i == _chosen
                    ? _OptionState.wrong
                    : _OptionState.idle,
                onTap: answered ? null : () => _answer(question, i),
              ),
            ),
          if (answered) ...<Widget>[
            const SizedBox(height: 4),
            _Feedback(
              right: right,
              reread: briefingLine(work.briefingFor(spoken)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => setState(() {
                _index++;
                _chosen = null;
              }),
              child: Text(
                _index + 1 >= questions.length
                    ? l10n.recQuestionsFinish
                    : l10n.recQuestionsNext,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Text(
              l10n.recQuestionsNote,
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _answer(ReadingQuestion question, int choice) {
    AppScope.read(context).haptics.select();
    setState(() {
      _chosen = choice;
      if (question.isRight(choice)) _right++;
    });
  }
}

enum _OptionState { idle, right, wrong }

/// A choice: a large target with a tick when it is the right one, a cross when
/// it was the learner's wrong one; the words carry the meaning too.
class _Option extends StatelessWidget {
  const _Option({required this.label, required this.state, this.onTap});

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, colour) = switch (state) {
      _OptionState.right => (Icons.check_circle, scheme.primary),
      _OptionState.wrong => (Icons.cancel_outlined, scheme.error),
      _OptionState.idle => (Icons.radio_button_unchecked, scheme.outline),
    };
    final said = switch (state) {
      _OptionState.right => l10n.recOptionRight,
      _OptionState.wrong => l10n.recOptionWrong,
      _OptionState.idle => '',
    };
    return Semantics(
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      label: said.isEmpty ? label : l10n.recOptionLabel(label, said),
      excludeSemantics: true,
      child: Material(
        color: state == _OptionState.right
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.field),
        clipBehavior: Clip.antiAlias,
        // hint-ok: shows text
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, color: colour),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Right", or "Not quite" with the line of the work to think of again.
class _Feedback extends StatelessWidget {
  const _Feedback({required this.right, required this.reread});

  final bool right;
  final String reread;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              right ? l10n.recFeedbackRight : l10n.recFeedbackWrong,
              style: theme.textTheme.titleSmall!.copyWith(
                color: right ? scheme.primary : scheme.error,
              ),
            ),
            if (!right && reread.isNotEmpty) ...<Widget>[
              const SizedBox(height: 2),
              Text(l10n.recReread(reread), style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
