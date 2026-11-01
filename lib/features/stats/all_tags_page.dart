import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/hint.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/theme.dart';
import 'stats_numbers.dart';

/// How many words a tag's practice asks about at most, as a quick revision's
/// largest size does.
const int kTagPracticeCount = 20;

/// Every tag of the languages counted, weakest first by default: the tags
/// taught, with their bar and the share of their taught pairs known now (the
/// measure of Weakest tags, [range] not applying), then those not taught, as
/// such. Each row is two lines and a thin bar (the tag and how many words are
/// taught, or "Nothing taught yet"), with a round play button inline (#499;
/// owner, 2026-10-24, 2026-10-26). A sort menu offers weakest first, A to Z
/// and most words; with a sort other than weakest first the tags with no
/// answer are mixed in by that sort.
///
/// Counts the language the bar at the top shows, or every language with its
/// All button on, as Progress does. Practise starts a capped, random set of
/// the words taught that carry the tag, in that language, due or not; every
/// answer is recorded (ADR-0033).
class AllTagsPage extends StatefulWidget {
  const AllTagsPage({super.key, required this.range});

  final StatsRange range;

  @override
  State<AllTagsPage> createState() => _AllTagsPageState();
}

enum _TagSort { weakest, az, words }

class _AllTagsPageState extends State<AllTagsPage> {
  _TagSort _sort = _TagSort.weakest;

  // How many words of each tag can be practised, worked out again only when
  // the language or the log changes, not on every rebuild.
  Map<String, int>? _practisable;
  String? _practisableLanguage;
  int _practisableLog = -1;
  String _practisableLearned = '';

  Map<String, int> _practisableFor(AppState state, String? language) {
    final log = state.progress.log.length;
    final learned = (state.learningCodes.toList()..sort()).join(',');
    if (_practisable == null ||
        _practisableLearned != learned ||
        _practisableLanguage != language ||
        _practisableLog != log) {
      final counts = <String, int>{};
      for (final item
          in state
              .buildSession(DrillRequest(revise: true, language: language))
              .items) {
        for (final tag in item.card.tags) {
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }
      _practisable = counts;
      _practisableLanguage = language;
      _practisableLog = log;
      _practisableLearned = learned;
    }
    return _practisable!;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsAllTagsTitle),
        actions: <Widget>[
          PopupMenuButton<_TagSort>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.statsTagSort,
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => <PopupMenuEntry<_TagSort>>[
              for (final (sort, label) in <(_TagSort, String)>[
                (_TagSort.weakest, l10n.statsTagSortWeakest),
                (_TagSort.az, l10n.statsTagSortAz),
                (_TagSort.words, l10n.statsTagSortWords),
              ])
                CheckedPopupMenuItem<_TagSort>(
                  value: sort,
                  checked: sort == _sort,
                  child: Text(label),
                ),
            ],
          ),
          const ReportButton(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            state.progress,
            // The numbers come back from an isolate (#857).
            state.progressNumbers,
          ]),
          builder: (context, _) {
            final language = state.progressLanguage;
            final numbers = state.progressNumbers.of(language);
            if (numbers == null) {
              return const Center(child: CircularProgressIndicator());
            }
            // Every tag of the decks learned, answered or not.
            final unanswered = <String>{
              for (final entry in state.decks)
                if (state.currentProfile.learns(entry.language.code) &&
                    (language == null || entry.language.code == language))
                  for (final card in entry.cards) ...card.tags,
            }..removeAll(numbers.weakestTags.keys);
            final rest = unanswered.toList()..sort();
            if (numbers.weakestTags.isEmpty && rest.isEmpty) {
              return EmptyState(
                icon: Icons.sell_outlined,
                title: l10n.statsAllTagsEmpty,
              );
            }
            final practisable = _practisableFor(state, language);
            final scheme = Theme.of(context).colorScheme;
            final theme = Theme.of(context);
            Widget row(String tag, Tally? tally) {
              final words = practisable[tag] ?? 0;
              final canPractise = words > 0;
              return Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSizes.textInset,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      spacing: 8,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(tag, style: theme.textTheme.titleMedium),
                              Text(
                                canPractise
                                    ? l10n.statsTagWordsTaught(words)
                                    : l10n.statsTagNothingTaughtYet,
                                style: theme.textTheme.bodySmall!.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          label: tally == null
                              ? l10n.statsTagUnansweredLabel(tag)
                              : l10n.statsBarSemantics(tag, tally.ratio),
                          excludeSemantics: true,
                          child: Text(
                            tally == null
                                ? l10n.statsTagUnansweredValue
                                : l10n.commonPercent(tally.ratio),
                            style: theme.textTheme.titleSmall!.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          enabled: canPractise,
                          label: l10n.statsTagPractiseLabel(tag),
                          excludeSemantics: true,
                          child: Hint(
                            message: l10n.hintPractise,
                            child: InkResponse(
                              onTap: canPractise
                                  ? () => AppNavigator.startDrill(
                                      context,
                                      DrillRequest.tag(
                                        tag,
                                        count: kTagPracticeCount,
                                        language: language,
                                      ),
                                    )
                                  : null,
                              radius: 24,
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: canPractise
                                          ? scheme.secondaryContainer
                                          : null,
                                      border: canPractise
                                          ? null
                                          : Border.all(
                                              color: scheme.outlineVariant,
                                            ),
                                    ),
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: canPractise
                                          ? scheme.onSecondaryContainer
                                          : scheme.outlineVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.mark),
                      child: LinearProgressIndicator(
                        value: tally?.ratio ?? 0,
                        minHeight: 6,
                        color: scheme.tertiary,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Weakest first is today's order: the tags answered, weakest
            // first, then those not, A to Z. Any other sort mixes them.
            final all = <(String, Tally?)>[
              for (final MapEntry(key: tag, value: tally)
                  in numbers.weakestTags.entries)
                (tag, tally),
              for (final tag in rest) (tag, null),
            ];
            switch (_sort) {
              case _TagSort.weakest:
                break;
              case _TagSort.az:
                all.sort((a, b) => a.$1.compareTo(b.$1));
              case _TagSort.words:
                all.sort((a, b) {
                  final byWords = (practisable[b.$1] ?? 0).compareTo(
                    practisable[a.$1] ?? 0,
                  );
                  return byWords != 0 ? byWords : a.$1.compareTo(b.$1);
                });
            }
            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
              children: <Widget>[
                for (final (tag, tally) in all) row(tag, tally),
              ],
            );
          },
        ),
      ),
    );
  }
}
