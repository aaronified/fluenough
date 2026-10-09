import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/bar_row.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/language_chips.dart';
import '../../ui/widgets/pace_parts.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/segmented.dart';
import '../../ui/widgets/stat_tile.dart';
import 'heatmap.dart';
import 'leeches.dart';
import 'stats_numbers.dart';

/// The Progress tab: range, stat tiles, the activity grid, correct by skill with How you learn under it, weakest tags, leeches. Shows a disabled empty state while `Feature.stats` is incoming.
///
/// Design screen `stats`. Every number is computed from the review log and
/// the current scheduling states (`StatsNumbers`), none from the design.
///
/// The numbers are one language's: a chip per language the log has reviews
/// in names it, most recently reviewed first, and "All languages" after
/// them counts every review together when there are several languages, or
/// reviews whose language cannot be told. The tab opens on the first chip.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key, this.initialRange = StatsRange.month});

  /// The range shown first: 30 days, as in the design.
  final StatsRange initialRange;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late StatsRange _range = widget.initialRange;

  /// Whether the learner has chosen a language chip, and which: a code, or
  /// null for All. Until they choose, the tab shows the language reviewed
  /// last.
  bool _chosen = false;
  String? _language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final header = TabHeader(title: l10n.statsTitle);

    if (state.features.isIncoming(Feature.stats)) {
      return _Frame(
        header: header,
        child: EmptyState(
          icon: Icons.insights_outlined,
          title: l10n.statsIncomingTitle,
          body: l10n.statsIncomingBody,
          action: const IncomingBadge(),
        ),
      );
    }

    final actions = LeechActions.of(state.progress);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[state.progress, actions]),
      builder: (context, _) {
        if (state.progress.log.isEmpty) {
          return _Frame(
            header: header,
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: l10n.statsNoReviews,
            ),
          );
        }
        final languageOf = languageLookupOf(state);
        final practised = practisedLanguages(
          state.progress,
          languages: state.languages,
          languageOf: languageOf,
        );
        // All languages is offered beside two or more languages, or beside
        // one when some reviews cannot be placed in any, so that every
        // review is counted somewhere.
        final several =
            practised.length > 1 ||
            (practised.isNotEmpty &&
                state.progress.log.any((e) => languageOf(e.deckId) == null));
        // A chosen language whose reviews can no longer be placed, its decks
        // gone from the catalog, falls back to the first chip.
        final language =
            several &&
                _chosen &&
                (_language == null || practised.any((l) => l.code == _language))
            ? _language
            : practised.firstOrNull?.code;
        return _Frame(
          header: header,
          controls: Padding(
            padding: const EdgeInsetsDirectional.only(top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (practised.isNotEmpty) ...<Widget>[
                  LanguageChips(
                    languages: practised,
                    decks: state.decks,
                    semanticLabel: l10n.statsLanguageGroup,
                    allLabel: several ? l10n.statsLanguageAll : null,
                    // The language shown first is the first chip, on screen
                    // whatever the width.
                    allLast: true,
                    selected: language,
                    onSelected: (code) => setState(() {
                      _chosen = true;
                      _language = code;
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                  ),
                  child: Segmented<StatsRange>(
                    semanticLabel: l10n.statsRangeGroup,
                    selected: _range,
                    onSelected: (range) => setState(() => _range = range),
                    options: <SegmentOption<StatsRange>>[
                      for (final range in StatsRange.values)
                        SegmentOption<StatsRange>(
                          value: range,
                          label: range.days == null
                              ? l10n.statsRangeAll
                              : l10n.statsRangeDays(range.days!),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          child: _StatsBody(
            state: state,
            actions: actions,
            range: _range,
            language: language,
            languageOf: languageOf,
          ),
        );
      },
    );
  }
}

/// The tab's fixed title (and range choice) over its scrolling content.
class _Frame extends StatelessWidget {
  const _Frame({required this.header, required this.child, this.controls});

  final Widget header;
  final Widget? controls;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          ?controls,
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.state,
    required this.actions,
    required this.range,
    required this.language,
    required this.languageOf,
  });

  final AppState state;
  final LeechActions actions;
  final StatsRange range;

  /// The language counted, by code, or null for every review.
  final String? language;
  final LanguageLookup languageOf;

  bool _counts(String deckId) =>
      language == null || languageOf(deckId) == language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cardOf = cardLookupOf(state);
    final numbers = StatsNumbers.of(
      state.progress,
      now: state.now(),
      range: range,
      cardOf: cardOf,
      deckFilter: language == null ? null : _counts,
    );
    final leeches = findLeeches(state.progress, cardOf: cardOf)
        .where(
          (l) =>
              _counts(l.card.deckId) &&
              actions.statusOf(l.key) == LeechStatus.active,
        )
        .length;

    final count = NumberFormat.decimalPattern(l10n.localeName);
    final remembered = numbers.remembered;
    final all = range == StatsRange.all;
    final tiles = <(String, String)>[
      (count.format(numbers.reviews), l10n.statsReviews),
      (
        remembered == null
            ? '–' // ui-literal-ok: a dash for "no value" is not language
            : l10n.commonPercent(remembered),
        l10n.statsRemembered,
      ),
      if (all)
        (count.format(numbers.longestStreak), l10n.statsLongestStreak)
      else
        (count.format(numbers.streak), l10n.statsDayStreak),
      (
        count.format(numbers.learned),
        all ? l10n.statsCardsLearned : l10n.statsNewCardsLearned,
      ),
    ];

    Widget tileRow(int first) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = first; i < first + 2; i++) ...<Widget>[
            if (i > first) const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                value: tiles[i].$1,
                label: tiles[i].$2,
                variant: StatTileVariant.large,
              ),
            ),
          ],
        ],
      ),
    );

    BarRow bar(String label, Tally tally, {Color? color}) => BarRow(
      label: label,
      value: tally.ratio,
      valueText: l10n.commonPercent(tally.ratio),
      semanticsLabel: l10n.statsBarSemantics(label, tally.ratio),
      color: color,
    );

    // Before any fit, what will happen and where: Settings.
    final howYouLearn = PaceStrip(
      title: l10n.howYouLearnTitle,
      subtitle: state.pacing.fitted
          ? l10n.howYouLearnCardMore
          : l10n.howYouLearnCardBefore,
      onTap: () => AppNavigator.openHowYouLearn(context, language: language),
    );

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      children: <Widget>[
        tileRow(0),
        const SizedBox(height: 8),
        tileRow(2),
        const SizedBox(height: 16),
        ReviewHeatmap(numbers: numbers),
        const SizedBox(height: 16),
        // One skills section: the bars, then How you learn, which says
        // what the learner's answers have done to each skill's pace.
        if (numbers.bySkill.isNotEmpty)
          StatsSection(
            title: l10n.statsBySkill,
            children: <Widget>[
              for (final MapEntry(key: skill, value: tally)
                  in numbers.bySkill.entries)
                bar(skill.label(l10n), tally),
              howYouLearn,
            ],
          )
        else
          howYouLearn,
        if (numbers.weakestTags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          StatsSection(
            title: l10n.statsWeakestTags,
            children: <Widget>[
              for (final MapEntry(key: tag, value: tally)
                  in numbers.weakestTags.entries)
                bar(tag, tally, color: scheme.tertiary),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _LeechesRow(count: leeches, language: language),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          child: Text(
            l10n.statsFootnote,
            style: theme.textTheme.bodySmall!.copyWith(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// "4 leeches · Cards you keep missing", which opens Leeches, in
/// [language] when one is counted. While `Feature.leeches` is incoming it is
/// dimmed, with the badge under its text so that it still fits at large text
/// sizes.
class _LeechesRow extends StatelessWidget {
  const _LeechesRow({required this.count, required this.language});

  final int count;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final incoming = isIncoming(context, Feature.leeches);
    final title = l10n.statsLeeches(count);
    final fg = scheme.onErrorContainer;
    Widget dim(Widget child) =>
        incoming ? Opacity(opacity: kIncomingOpacity, child: child) : child;

    final row = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 16, 16),
      child: Row(
        children: <Widget>[
          dim(Icon(Icons.warning_amber_rounded, color: fg)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                dim(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.statsLeechesSubtitle,
                        style: theme.textTheme.bodyMedium!.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
                if (incoming) ...<Widget>[
                  const SizedBox(height: 8),
                  const IncomingBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          dim(Icon(Icons.chevron_right, color: fg)),
        ],
      ),
    );

    final tile = Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(AppRadii.group),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: incoming
            ? () => showIncomingSnackBar(context)
            : () => AppNavigator.openLeeches(context, language: language),
        child: row,
      ),
    );

    return incoming
        ? Semantics(
            container: true,
            button: true,
            enabled: false,
            label: l10n.incomingSemanticsLabel(title),
            hint: l10n.incomingSemanticsHint,
            excludeSemantics: true,
            onTap: () => showIncomingSnackBar(context),
            child: tile,
          )
        : MergeSemantics(child: tile);
  }
}
