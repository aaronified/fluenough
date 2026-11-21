import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/placement_run_setup.dart';
import '../../app/reviewer_check_records.dart';
import '../../core/models/deck.dart';
import '../../core/placement/placement_data.dart';
import '../../core/placement/reviewer_check_bank.dart';
import '../../core/placement/reviewer_check_run.dart';
import '../../core/placement/reviewer_check_status.dart';
import '../../core/placement/v3_result.dart';
import '../../core/review/facets.dart';
import '../../core/review/review_quorum.dart' show ReviewCheck;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import '../drill/choice_tile.dart';
import '../placement/placement_questions.dart' show PlacementFrame;
import 'review_source.dart' show otherChecksOf;
import 'review_waiting.dart' show languageNamesOf;

// The reviewer check's screens (ADR-0058, decision 1; the reviewer-ux mockup,
// frames 5d and 5e): the list of courses it can be taken for, the questions,
// the result, and the quiet offer under a top-band placement. None of it
// exists while `kReviewerCheckEnabled` is false.
//
// The questions show no feedback and no score, now or after.

/// The cards of [plan]'s course that are checked twice, as the check reads
/// them: each deck's published facet checks.
CheckedTwice _checkedTwiceOf(PlacementRunPlan plan) {
  final checks = <String, Map<Facet, List<ReviewCheck>>>{
    for (final entry in plan.decks) ...otherChecksOf(entry, entry.cards),
  };
  return checkedTwiceFrom(checks, plan.data.cardById);
}

/// What a course's row shows.
ReviewerCheckRow _rowOf(AppState state, String code) {
  final record = state.settings.reviewerCheckOf(code);
  if (!record.canTake(state.now())) return ReviewerCheckRow.cooldown;
  final plan = state.placementRunPlan(code, native: state.courseNative(code));
  if (plan == null) return ReviewerCheckRow.askForKey;
  return ReviewerBank.mayOffer(plan.data, _checkedTwiceOf(plan))
      ? ReviewerCheckRow.take
      : ReviewerCheckRow.askForKey;
}

/// Settings > Reviewing > Take the check (frame 5d): a row for each course
/// the learner is learning. A course taken in the last week shows the days
/// left; a course with too few checked cards, or no Find my level, says to
/// use a reviewer key.
class ReviewerCheckCoursesPage extends StatelessWidget {
  const ReviewerCheckCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewerCheckTitle)),
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) {
          final names = languageNamesOf(state);
          final codes = state.learningCodes.toList()
            ..sort((a, b) => (names[a] ?? a).compareTo(names[b] ?? b));
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              16,
              8,
              16,
              24,
            ).clearingSystemBar(context),
            children: <Widget>[
              GroupedList.settings(
                children: <Widget>[
                  for (final code in codes) _row(context, state, code, names),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AppState state,
    String code,
    Map<String, String> names,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final name = names[code] ?? code;
    return switch (_rowOf(state, code)) {
      ReviewerCheckRow.take => GroupedTile(
        title: name,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(startReviewerCheck(context, code, name)),
      ),
      ReviewerCheckRow.cooldown => GroupedTile(
        title: name,
        subtitle: l10n.reviewerCheckCooldown(
          state.settings.reviewerCheckOf(code).cooldownDays(state.now()),
        ),
      ),
      ReviewerCheckRow.askForKey => GroupedTile(
        title: name,
        subtitle: l10n.reviewerCheckUseKey,
      ),
    };
  }
}

/// Opens the check for [code]'s course.
Future<void> startReviewerCheck(
  BuildContext context,
  String code,
  String name,
) async {
  final state = AppScope.read(context);
  final navigator = Navigator.of(context);
  final plan = state.placementRunPlan(code, native: state.courseNative(code));
  if (plan == null) return;
  await navigator.push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/reviewer-check'),
      builder: (_) => ReviewerCheckPage(code: code, name: name, plan: plan),
    ),
  );
}

/// The check itself: the questions are made, then asked one at a time with
/// no sign of right or wrong, then the result.
class ReviewerCheckPage extends StatefulWidget {
  const ReviewerCheckPage({
    super.key,
    required this.code,
    required this.name,
    required this.plan,
  });

  final String code;
  final String name;
  final PlacementRunPlan plan;

  @override
  State<ReviewerCheckPage> createState() => _ReviewerCheckPageState();
}

class _ReviewerCheckPageState extends State<ReviewerCheckPage> {
  ReviewerCheckRun? _run;
  bool _failed = false;
  bool _recorded = false;
  bool _thin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_prepare()));
  }

  Future<void> _prepare() async {
    final state = AppScope.read(context);
    try {
      final job = state.placementBanks.jobFor(widget.plan.data);
      final items = await job.result;
      if (!mounted) return;
      final bank = ReviewerBank.build(
        data: widget.plan.data,
        items: items,
        checkedTwice: _checkedTwiceOf(widget.plan),
      );
      if (!ReviewerCheckRun.isAvailable(bank)) {
        setState(() => _thin = true);
        return;
      }
      final record = state.settings.reviewerCheckOf(widget.code);
      final audio =
          state.settings.soundOn && state.hasVoice(widget.plan.language);
      final run = ReviewerCheckRun(
        bank: bank,
        seed: state.now().millisecondsSinceEpoch & 0x7fffffff,
        audio: audio,
        seen: record.used.toSet(),
      );
      setState(() => _run = run);
      _afterStep();
    } on Object catch (error) {
      state.log.warning('Reviewer check (${widget.code}): $error');
      if (mounted) setState(() => _failed = true);
    }
  }

  LanguageInfo get _language => widget.plan.language;

  /// After each answer: save at the end, play a heard question.
  void _afterStep() {
    final run = _run;
    if (run == null || !mounted) return;
    if (run.finished) {
      _record(run);
    } else if (run.question case final q? when q.isHeard) {
      unawaited(_play(q));
    }
  }

  void _record(ReviewerCheckRun run) {
    if (_recorded) return;
    _recorded = true;
    final state = AppScope.read(context);
    try {
      final settings = state.settings;
      settings.setReviewerCheck(
        widget.code,
        settings
            .reviewerCheckOf(widget.code)
            .afterAttempt(run.result, state.now()),
      );
      // Only that it ended and whether it passed: never a score.
      state.log.event(
        'Reviewer check for ${widget.code}: '
        '${run.result.passed ? 'passed' : 'not yet'}',
      );
    } on Object catch (error) {
      state.log.warning('Reviewer check not saved: $error');
    }
  }

  Future<void> _play(ReviewerQuestion q) async {
    final state = AppScope.read(context);
    final text = q.audio;
    if (text == null) return;
    final card = widget.plan.data.cardById(q.item.cardId);
    final failed = await (card != null
        ? state.speakCard(card, _language)
        : state.speak(text, _language));
    if (!mounted) return;
    if (failed != null && _run?.question?.id == q.id) {
      // A question that cannot be heard is left out, never a miss.
      setState(() => _run!.skipUnplayable());
      _afterStep();
    }
  }

  void _step(void Function(ReviewerCheckRun run) act) {
    final run = _run;
    if (run == null) return;
    setState(() => act(run));
    _afterStep();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final run = _run;
    if (_thin) return _message(context, l10n.reviewerCheckUseKey);
    if (_failed) return _message(context, l10n.findLevelFinishFailed);
    if (run == null) return _preparing(context);
    if (run.finished) return _resultPage(context, run);
    return _question(context, run, run.question!);
  }

  Widget _message(BuildContext context, String text) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewerCheckTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.gutter),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _preparing(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final job = AppScope.read(context).placementBanks.jobFor(widget.plan.data);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewerCheckTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.gutter),
          child: ValueListenableBuilder<double>(
            valueListenable: job.progress,
            builder: (context, progress, _) => Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: <Widget>[
                LinearProgressIndicator(value: progress),
                Text(l10n.reviewerCheckPreparing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _question(
    BuildContext context,
    ReviewerCheckRun run,
    ReviewerQuestion q,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = switch (q.format) {
      'F3' => l10n.placementQuestion,
      'F28' => l10n.findLevelFillGap,
      _ => l10n.findLevelWordMeaning,
    };
    final shown = <Widget>[
      if (q.shown case final text? when text.isNotEmpty)
        q.shownIsTarget
            ? TargetText.hero(text, language: _language)
            : Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
      if (q.hasGap)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TargetText.hero(
            '${q.gapBefore}＿＿${q.gapAfter}',
            language: _language,
          ),
        ),
      if (q.isHeard)
        OutlinedButton.icon(
          onPressed: () => unawaited(_play(q)),
          icon: const Icon(Icons.volume_up_outlined),
          label: Text(l10n.placementHearPlay),
        ),
    ];
    return PlacementFrame(
      key: ValueKey<String>('reviewer-check-${q.id}'),
      number: run.answered + 1,
      title: Text(title),
      shown: shown.isEmpty
          ? null
          : Column(mainAxisSize: MainAxisSize.min, children: shown),
      children: <Widget>[
        Semantics(
          container: true,
          label: l10n.drillOptionsGroup,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final (i, option) in q.options.indexed) ...<Widget>[
                if (i > 0) const SizedBox(height: 10),
                ChoiceTile(
                  key: ValueKey<String>('reviewer-check-option-$i'),
                  right: false,
                  chosen: false,
                  answered: false,
                  onTap: () => _step((r) => r.answer(i)),
                  label: (style) => q.optionsAreTarget
                      ? TargetText.card(
                          option,
                          language: _language,
                          fontSize: 22,
                        )
                      : Text(option, style: style),
                ),
              ],
            ],
          ),
        ),
      ],
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('reviewer-check-also-right'),
          onPressed: () => _step((r) => r.alsoRight()),
          child: Text(l10n.reviewerCheckAlsoRight),
        ),
        TextButton(
          key: const ValueKey<String>('reviewer-check-dont-know'),
          onPressed: () => _step((r) => r.dontKnow()),
          child: Text(l10n.reviewerCheckDontKnow),
        ),
      ],
    );
  }

  Widget _resultPage(BuildContext context, ReviewerCheckRun run) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.read(context);
    final passed = run.result.passed;
    final days = state.settings
        .reviewerCheckOf(widget.code)
        .cooldownDays(state.now());
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewerCheckTitle)),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 12,
                children: <Widget>[
                  Icon(
                    passed ? Icons.verified_outlined : Icons.schedule_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  Text(
                    passed
                        ? l10n.reviewerCheckPassedTitle
                        : l10n.reviewerCheckNotYetTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    passed
                        ? l10n.reviewerCheckPassedBody(widget.name)
                        : l10n.reviewerCheckNotYetBody(days),
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            FilledButton(
              key: const ValueKey<String>('reviewer-check-done'),
              style: AppButtonStyles.tall(context),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.languagesDone),
            ),
          ],
        ),
      ),
    );
  }
}

/// The quiet offer under a placement result that reached the top band
/// (frame 5e): "Help check <language> cards?", made once per course. It
/// counts as made as soon as it is shown, so "No thanks", Done or leaving
/// ends it for good.
class ReviewerCheckOffer extends StatefulWidget {
  const ReviewerCheckOffer({
    super.key,
    required this.result,
    required this.data,
    required this.code,
    required this.name,
  });

  final V3Result result;
  final PlacementLanguageData data;
  final String code;
  final String name;

  @override
  State<ReviewerCheckOffer> createState() => _ReviewerCheckOfferState();
}

class _ReviewerCheckOfferState extends State<ReviewerCheckOffer> {
  bool _show = false;
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppScope.read(context);
      final record = state.settings.reviewerCheckOf(widget.code);
      if (!record.shouldOffer || !topBandReached(widget.result, widget.data)) {
        return;
      }
      state.settings.setReviewerCheck(widget.code, record.withOffered());
      setState(() => _show = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_show || _decided) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: <Widget>[
        Text(
          l10n.reviewerCheckOfferTitle(widget.name),
          style: theme.textTheme.bodyLarge,
        ),
        FilledButton.tonal(
          key: const ValueKey<String>('reviewer-check-offer-take'),
          onPressed: () {
            setState(() => _decided = true);
            unawaited(startReviewerCheck(context, widget.code, widget.name));
          },
          child: Text(l10n.reviewerCheckOfferTake),
        ),
        TextButton(
          key: const ValueKey<String>('reviewer-check-offer-no'),
          onPressed: () => setState(() => _decided = true),
          child: Text(l10n.reviewerCheckOfferNo),
        ),
      ],
    );
  }
}
