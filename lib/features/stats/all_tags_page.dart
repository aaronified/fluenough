import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/bar_row.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import 'stats_numbers.dart';

/// How many words a tag's practice asks about at most, as a quick revision's
/// largest size does.
const int kTagPracticeCount = 20;

/// Every tag the learner has answered cards of in [range], weakest first,
/// each with its bar and a Practise button (#499).
///
/// Counts the language the bar at the top shows, or every review with its
/// All button on, as Progress does. Practise starts a capped, random set of
/// the words taught that carry the tag, in that language, due or not; every
/// answer is recorded (ADR-0033).
class AllTagsPage extends StatelessWidget {
  const AllTagsPage({super.key, required this.range});

  final StatsRange range;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsAllTagsTitle),
        actions: const <Widget>[ReportButton()],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: state.progress,
          builder: (context, _) {
            final language = state.progressLanguage;
            final languageOf = languageLookupOf(state);
            final numbers = StatsNumbers.of(
              state.progress,
              now: state.now(),
              range: range,
              cardOf: cardLookupOf(state),
              deckFilter: language == null
                  ? null
                  : (id) => languageOf(id) == language,
              tagCount: 1 << 30,
            );
            if (numbers.weakestTags.isEmpty) {
              return EmptyState(
                icon: Icons.sell_outlined,
                title: l10n.statsAllTagsEmpty,
              );
            }
            // The tags of the words that can be practised now.
            final practisable = <String>{
              for (final item
                  in state
                      .buildSession(
                        DrillRequest(revise: true, language: language),
                      )
                      .items)
                ...item.card.tags,
            };
            final scheme = Theme.of(context).colorScheme;
            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
              children: <Widget>[
                for (final MapEntry(key: tag, value: tally)
                    in numbers.weakestTags.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        BarRow(
                          label: tag,
                          value: tally.ratio,
                          valueText: l10n.commonPercent(tally.ratio),
                          semanticsLabel: l10n.statsBarSemantics(
                            tag,
                            tally.ratio,
                          ),
                          color: scheme.tertiary,
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Semantics(
                            label: l10n.statsTagPractiseLabel(tag),
                            excludeSemantics: true,
                            child: TextButton(
                              onPressed: practisable.contains(tag)
                                  ? () => AppNavigator.startDrill(
                                      context,
                                      DrillRequest.tag(
                                        tag,
                                        count: kTagPracticeCount,
                                        language: language,
                                      ),
                                    )
                                  : null,
                              child: Text(l10n.statsTagPractise),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
