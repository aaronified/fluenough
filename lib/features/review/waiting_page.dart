import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../decks/path_parts.dart' show joinParts;
import 'review_waiting.dart';
import 'send_reviews_sheet.dart';

/// "Waiting for review" (docs/plans/deck-browser.md): per language the
/// reviewer reviews, the units and decks no native speaker has signed off,
/// with the cards each has left; the offensive words not yet rated and
/// the pairs not yet confirmed; and what the reviewer has reviewed and not
/// sent. Opened from Settings, under Review decks.
///
/// A unit opens its review; the words waiting are counted, never named.
/// Offensive words, and the pairs that name one, are never in a unit's
/// review: each language with any has its own "Offensive words" row,
/// which the reviewer opens on purpose (owner, 2026-10-10).
class WaitingForReviewPage extends StatelessWidget {
  const WaitingForReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewSettingsWaiting),
        actions: const <Widget>[ReportButton()],
      ),
      // The reviews and the languages chosen are in the settings.
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final languages = reviewLanguagesOf(state);
    if (languages.isEmpty) {
      return EmptyState(
        icon: Icons.translate_outlined,
        title: l10n.reviewWaitingNoLanguages,
        action: FilledButton(
          onPressed: () => showReviewLanguages(context),
          child: Text(l10n.reviewWaitingChoose),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
          child: Text(
            l10n.reviewWaitingIntro,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final language in languages)
          _Language(waiting: waitingIn(state, language)),
      ],
    );
  }
}

/// One language's group: what waits in it, or that nothing does.
class _Language extends StatelessWidget {
  const _Language({required this.waiting});

  final WaitingLanguage waiting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = waiting.language;
    // What waits in the Offensive words review, counted, never named.
    final offensive = <String>[
      if (waiting.unrated.isNotEmpty)
        l10n.reviewWaitingUnrated(waiting.unrated.length),
      if (waiting.unconfirmed.isNotEmpty)
        l10n.reviewWaitingUnconfirmed(waiting.unconfirmed.length),
    ];
    // A unit opens its review; a deck outside the path, which has no unit
    // to review, opens its deck.
    void open(String deckId) => AppNavigator.openReview(context, deckId);

    return GroupedList.settings(
      header: language.name,
      children: <Widget>[
        if (waiting.isEmpty)
          GroupedTile(
            leading: const Icon(Icons.check_circle_outline),
            title: l10n.reviewWaitingNothing(language.name),
          ),
        for (final unit in waiting.units)
          GroupedTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: l10n.reviewWaitingUnit(unit.number, unit.title),
            subtitle: unit.decks.length == 1
                ? l10n.reviewWaitingCardsLeft(unit.decks.single.left)
                : <String>[
                    for (final d in unit.decks)
                      l10n.reviewWaitingDeckCards(d.deck.deck.name, d.left),
                  ].join('\n'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(unit.decks.first.deck.id),
          ),
        for (final d in waiting.decks)
          GroupedTile(
            leading: const Icon(Icons.style_outlined),
            title: d.deck.deck.name,
            subtitle: joinParts(l10n, <String>[
              l10n.reviewWaitingFrom(d.deck.deck.native.name),
              l10n.reviewWaitingCardsLeft(d.left),
            ]),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppNavigator.openDeck(context, d.deck.id),
          ),
        if (waiting.hasOffensiveReview)
          GroupedTile(
            leading: const Icon(Icons.bar_chart),
            title: l10n.reviewOffensiveTitle,
            subtitle: offensive.isEmpty
                ? l10n.reviewOffensiveNoneWaiting
                : offensive.join('\n'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                AppNavigator.openOffensiveReview(context, language.code),
          ),
        if (waiting.unsent.isNotEmpty)
          GroupedTile(
            leading: const Icon(Icons.outbox_outlined),
            title: l10n.reviewWaitingUnsent(waiting.unsent.length),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showSendReviews(context),
          ),
      ],
    );
  }
}

/// Asks which languages the reviewer reviews, among those the app teaches,
/// those reviewed now ticked, and keeps the answer.
Future<void> showReviewLanguages(BuildContext context) async {
  final state = AppScope.read(context);
  final chosen = <String>{for (final l in reviewLanguagesOf(state)) l.code};
  final result = await showDialog<Set<String>>(
    context: context,
    builder: (context) =>
        _LanguagesDialog(languages: state.languages, chosen: chosen),
  );
  if (result != null) state.settings.reviewLanguages = result;
}

class _LanguagesDialog extends StatefulWidget {
  const _LanguagesDialog({required this.languages, required this.chosen});

  final List<LanguageInfo> languages;
  final Set<String> chosen;

  @override
  State<_LanguagesDialog> createState() => _LanguagesDialogState();
}

class _LanguagesDialogState extends State<_LanguagesDialog> {
  late final Set<String> _chosen = Set<String>.of(widget.chosen);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.reviewSettingsLanguages),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(0, 16, 0, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
              child: Text(
                l10n.reviewLanguagesBody,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final language in widget.languages)
              CheckboxListTile(
                contentPadding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 24,
                ),
                value: _chosen.contains(language.code),
                title: Text(language.name),
                onChanged: (on) => setState(
                  () => on == true
                      ? _chosen.add(language.code)
                      : _chosen.remove(language.code),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(Set<String>.of(_chosen)),
          child: Text(l10n.reviewSave),
        ),
      ],
    );
  }
}
