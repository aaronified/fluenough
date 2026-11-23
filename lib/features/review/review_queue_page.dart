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
import 'review_loader.dart';
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
                                borderRadius: BorderRadius.circular(
                                  AppRadii.control,
                                ),
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
            // One language at a time, the languages the reviewer reviews are
            // read as the page opens, and what they hold is drawn as it
            // arrives.
            body: const ReviewLoader(
              child: TabBarView(
                children: <Widget>[_SessionTab(), FlaggedList()],
              ),
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

  Object? _memoReviews;
  Object? _memoDecks;
  String? _memoRuns;
  String? _memoCourse;
  List<ReviewSource> _sources = const <ReviewSource>[];
  ReviewSource? _source;
  ReviewRun? _run;
  ReviewRun? _shown;

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
    final reviewing = state.reviewing;
    // The sources and the session line are worked out again only when what
    // they read changes, not on every settings change.
    if (!identical(_memoReviews, reviewing.reviews) ||
        !identical(_memoDecks, state.decks) ||
        _memoRuns != state.settings.reviewRun ||
        _memoCourse != _course) {
      _memoReviews = reviewing.reviews;
      _memoDecks = state.decks;
      _memoRuns = state.settings.reviewRun;
      _memoCourse = _course;
      _sources = reviewSourcesOf(state);
      if (_sources.isNotEmpty) {
        // The course picked, else the first with a run, else the first.
        final withRun = _sources.where(
          (s) => reviewing.runOf(s.pair.key) != null,
        );
        final key = _course ?? (withRun.firstOrNull ?? _sources.first).pair.key;
        _source = _sources.firstWhere(
          (s) => s.pair.key == key,
          orElse: () => _sources.first,
        );
        _run = reviewing.runOf(_source!.pair.key);
        _shown =
            _run ??
            ReviewQueueBuilder.startSession(
              _source!,
              reviews: reviewing.reviews,
              ownCode: reviewing.code?.toString(),
            );
      }
    }
    final sources = _sources;
    if (sources.isEmpty) {
      if (anyReading(state, reviewLanguageCodes(state))) {
        return Center(
          child: CircularProgressIndicator(
            semanticsLabel: l10n.commonLoadingDecks,
          ),
        );
      }
      return EmptyState(
        icon: Icons.style_outlined,
        title: l10n.reviewQueueEmpty,
      );
    }
    final source = _source!;
    final resuming = _run != null;
    final shown = _shown;
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
