import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
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

/// Every tag of the languages counted, weakest first: the tags answered in
/// [range] with their bar and share remembered, then those not answered, as
/// such. Each has a Practise button (#499).
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

class _AllTagsPageState extends State<AllTagsPage> {
  // The tags of the words that can be practised, worked out again only when
  // the language or the log changes, not on every rebuild.
  Set<String>? _practisable;
  String? _practisableLanguage;
  int _practisableLog = -1;
  String _practisableLearned = '';

  Set<String> _practisableFor(AppState state, String? language) {
    final log = state.progress.log.length;
    final learned = (state.learningCodes.toList()..sort()).join(',');
    if (_practisable == null ||
        _practisableLearned != learned ||
        _practisableLanguage != language ||
        _practisableLog != log) {
      _practisable = <String>{
        for (final item
            in state
                .buildSession(DrillRequest(revise: true, language: language))
                .items)
          ...item.card.tags,
      };
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
              range: widget.range,
              cardOf: cardLookupOf(state),
              deckFilter: language == null
                  ? null
                  : (id) => languageOf(id) == language,
              tagCount: 1 << 30,
            );
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
            // A tooltip only on a disabled button, to say why.
            Widget withReason(bool enabled, String reason, Widget button) =>
                enabled ? button : Tooltip(message: reason, child: button);
            Widget row(String tag, Tally? tally) => Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  BarRow(
                    label: tag,
                    value: tally?.ratio ?? 0,
                    valueText: tally == null
                        ? l10n.statsTagUnansweredValue
                        : l10n.commonPercent(tally.ratio),
                    semanticsLabel: tally == null
                        ? l10n.statsTagUnansweredLabel(tag)
                        : l10n.statsBarSemantics(tag, tally.ratio),
                    color: scheme.tertiary,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Semantics(
                      label: l10n.statsTagPractiseLabel(tag),
                      hint: practisable.contains(tag)
                          ? null
                          : l10n.statsTagNothingTaught,
                      excludeSemantics: true,
                      child: withReason(
                        practisable.contains(tag),
                        l10n.statsTagNothingTaught,
                        TextButton(
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
                  ),
                ],
              ),
            );
            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
              children: <Widget>[
                for (final MapEntry(key: tag, value: tally)
                    in numbers.weakestTags.entries)
                  row(tag, tally),
                for (final tag in rest) row(tag, null),
              ],
            );
          },
        ),
      ),
    );
  }
}
