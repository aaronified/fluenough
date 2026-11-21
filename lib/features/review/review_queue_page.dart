import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/review/review_session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/system_bar.dart';
import 'flagged_page.dart';
import 'review_flow_page.dart';
import 'review_source.dart';
import 'review_waiting.dart';

/// Opens the Reviewing page: the review queue and the flagged cards.
Future<void> showReviewQueuePage(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/review-queue'),
        builder: (_) => const ReviewQueuePage(),
      ),
    );

/// The Reviewing page (ADR-0058, decision 10; docs/mockups/reviewer-ux.html,
/// frame 1a), reached from Settings > Reviewing: a Session tab, the unit the
/// reviewer goes on with and one Resume button, and a Flagged and contested
/// tab ([FlaggedList]) with its own "Review all N", the flagged-only mode.
class ReviewQueuePage extends StatelessWidget {
  const ReviewQueuePage({super.key});

  static const Key sessionTabKey = ValueKey<String>('queue-tab-session');
  static const Key flaggedTabKey = ValueKey<String>('queue-tab-flagged');
  static const Key resumeKey = ValueKey<String>('queue-resume');
  static const Key unitKey = ValueKey<String>('queue-unit-line');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final flagged = flaggedQueueOf(state).count;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.settingsRowReviewing),
              bottom: TabBar(
                tabs: <Widget>[
                  Tab(
                    key: ReviewQueuePage.sessionTabKey,
                    text: l10n.reviewQueueTabSession,
                  ),
                  Tab(
                    key: ReviewQueuePage.flaggedTabKey,
                    child: Semantics(
                      label: l10n.reviewQueueTabFlagged(flagged),
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 6,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              l10n.reviewFlaggedTitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (flagged > 0)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 1,
                                ),
                                child: Text(
                                  '$flagged',
                                  style: theme.textTheme.labelMedium!.copyWith(
                                    color: scheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: const TabBarView(
              children: <Widget>[_SessionTab(), FlaggedList()],
            ),
          ),
        );
      },
    );
  }
}

/// The Session tab: which course, the unit line and one button.
class _SessionTab extends StatefulWidget {
  const _SessionTab();

  @override
  State<_SessionTab> createState() => _SessionTabState();
}

class _SessionTabState extends State<_SessionTab> {
  String? _course;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sources = reviewSourcesOf(state);
    if (sources.isEmpty) {
      return EmptyState(
        icon: Icons.style_outlined,
        title: l10n.reviewQueueEmpty,
      );
    }
    final reviewing = state.reviewing;
    final run = reviewing.run;
    // The course the run is in, else the one picked, else the first.
    final key =
        _course ??
        (run != null && sources.any((s) => s.pair.key == run.course)
            ? run.course
            : sources.first.pair.key);
    final source = sources.firstWhere(
      (s) => s.pair.key == key,
      orElse: () => sources.first,
    );
    final resuming = run != null && run.course == source.pair.key;
    final shown = resuming
        ? run
        : ReviewQueueBuilder.startSession(
            source,
            reviews: reviewing.reviews,
            ownCode: reviewing.code?.toString(),
          );
    final names = languageNamesOf(state);
    final open = shown == null
        ? 0
        : ReviewQueueBuilder.firstOpen(source, shown.cards, reviewing.reviews);
    // The card the reviewer is on: the last one when all are finished.
    final at = shown == null
        ? 0
        : (open >= shown.cards.length ? shown.cards.length : open + 1);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        16,
        12,
        16,
        24,
      ).clearingSystemBar(context),
      children: <Widget>[
        if (sources.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final s in sources)
                  ChoiceChip(
                    label: Text(
                      l10n.reviewQueueCourse(
                        names[s.pair.target] ?? s.pair.target,
                        names[s.pair.native] ?? s.pair.native,
                      ),
                    ),
                    selected: s.pair.key == source.pair.key,
                    onSelected: (_) => setState(() => _course = s.pair.key),
                  ),
              ],
            ),
          ),
        if (shown != null) ...<Widget>[
          Semantics(
            container: true,
            label:
                '${shown.title}, ${l10n.reviewCardOf(at, shown.cards.length)}',
            excludeSemantics: true,
            child: Container(
              key: ReviewQueuePage.unitKey,
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.field),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(shown.title, style: theme.textTheme.titleMedium),
                  Text(
                    l10n.reviewCardOf(at, shown.cards.length),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: ReviewQueuePage.resumeKey,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
            onPressed: () => showReviewQueue(context, source.pair),
            child: Text(
              resuming ? l10n.reviewQueueResume : l10n.reviewQueueStart,
            ),
          ),
        ],
      ],
    );
  }
}
