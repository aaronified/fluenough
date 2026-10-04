import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'today_numbers.dart';

/// Today's lessons (ADR-0024), above the reviews: for each language with
/// words left to teach, its lesson, then "Another lesson" once today's is
/// done.
class LessonCard extends StatelessWidget {
  const LessonCard({super.key, required this.lessons});

  final List<TodayLesson> lessons;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.todayLessonSection,
      child: Container(
        padding: const EdgeInsetsDirectional.all(24),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.hero),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (i, lesson) in lessons.indexed) ...<Widget>[
              if (i > 0) const SizedBox(height: 20),
              _Lesson(lesson: lesson, named: lessons.length > 1),
            ],
          ],
        ),
      ),
    );
  }
}

/// One language's lesson: what it teaches, and the button that starts it.
class _Lesson extends StatelessWidget {
  const _Lesson({required this.lesson, required this.named});

  final TodayLesson lesson;

  /// Whether the title names the language: more than one is learned.
  final bool named;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSecondaryContainer;
    final name = lesson.language.name;
    final title = lesson.done
        ? named
              ? l10n.todayLessonDoneTitleIn(name)
              : l10n.todayLessonDoneTitle
        : named
        ? l10n.todayLessonTitleIn(name)
        : l10n.todayLessonTitle;
    final request = DrillRequest.lesson(language: lesson.language.code);
    void start() => AppNavigator.startDrill(context, request);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.sectionTitle.copyWith(color: fg),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lesson.reading
                    ? l10n.todayLessonReading
                    : l10n.todayLessonWords(lesson.words),
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: fg.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (lesson.done)
          FilledButton.tonalIcon(
            style: AppButtonStyles.tall(context),
            onPressed: start,
            icon: const Icon(Icons.add_rounded, size: 24),
            label: Text(l10n.todayAnotherLesson),
          )
        else
          FilledButton.icon(
            style: AppButtonStyles.tall(context),
            onPressed: start,
            icon: const Icon(Icons.school_outlined, size: 24),
            label: Text(l10n.todayLessonStart),
          ),
      ],
    );
  }
}
