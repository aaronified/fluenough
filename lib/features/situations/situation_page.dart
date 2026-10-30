import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/situations.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/bottom_actions.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';

/// Which sheet a situation page or its inspect view shows (#724): a
/// situation of [language]'s sheets, and for the inspect view the card it
/// opens on, as a position in the sheet's cards.
class SituationRequest {
  const SituationRequest({
    required this.language,
    required this.situationId,
    this.index = 0,
  });

  final String language;
  final String situationId;
  final int index;
}

/// A situation's sheet: its phrases, then its words, each with its script,
/// reading, meaning and a speaker, a dot on those the learner has not met
/// yet, and "Practise this sheet" at the foot (#724; mockup
/// `docs/mockups/situations.html`, screen 2). Every card is the deck's own,
/// so what is learnt here is learnt in its deck.
class SituationPage extends StatelessWidget {
  const SituationPage({super.key, required this.request});

  final SituationRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final sheet = state
        .situationsOf(request.language)
        ?.byId(request.situationId);
    if (sheet == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final language = request.language;
    final phrases = state.sheetCards(language, sheet.phrases);
    final words = state.sheetCards(language, sheet.words);
    final all = <SheetCard>[...phrases, ...words];
    final fresh = all.any((c) => c.isNew);
    final ids = <String>{for (final c in all) c.card.id};
    // Nothing to teach or revise right now leaves the button off, with the
    // reason beneath it.
    final canPractise =
        all.isNotEmpty &&
        state
            .sheetSession(
              DrillRequest.sheet(ids, language: language, revise: !fresh),
            )
            .isNotEmpty;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          sheet.titleFor(state.settings.spokenLanguages),
          style: theme.textTheme.titleMedium,
        ),
        actions: <Widget>[
          if (all.isNotEmpty)
            IconButton(
              tooltip: l10n.situationInspect,
              icon: const Icon(Icons.manage_search_outlined),
              onPressed: () => _inspect(context, 0),
            ),
        ],
      ),
      body: all.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.situationEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                16,
                8,
                16,
                24,
              ).clearingSystemBar(context),
              children: <Widget>[
                if (phrases.isNotEmpty)
                  _Section(
                    title: l10n.situationPhrases,
                    cards: phrases,
                    first: 0,
                    onOpen: (i) => _inspect(context, i),
                  ),
                if (words.isNotEmpty)
                  _Section(
                    title: l10n.situationWords,
                    cards: words,
                    first: phrases.length,
                    onOpen: (i) => _inspect(context, i),
                  ),
              ],
            ),
      bottomNavigationBar: all.isEmpty
          ? null
          : BottomActions(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton(
                    style: AppButtonStyles.tall(context),
                    onPressed: canPractise
                        ? () => AppNavigator.startDrill(
                            context,
                            DrillRequest.sheet(
                              ids,
                              language: language,
                              revise: !fresh,
                            ),
                          )
                        : null,
                    child: Text(
                      fresh ? l10n.situationPractise : l10n.situationRevise,
                    ),
                  ),
                  if (!canPractise) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      l10n.situationNothingToPractise,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  void _inspect(BuildContext context, int index) =>
      Navigator.of(context).pushNamed(
        AppRoutes.situationInspect,
        arguments: SituationRequest(
          language: request.language,
          situationId: request.situationId,
          index: index,
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.cards,
    required this.first,
    required this.onOpen,
  });

  final String title;
  final List<SheetCard> cards;

  /// The position of the first of [cards] among the sheet's cards.
  final int first;
  final void Function(int index) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 16, 8, 10),
          child: Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
        ),
        GroupedList(
          outerRadius: AppRadii.card,
          gap: 4,
          children: <Widget>[
            for (final (i, item) in cards.indexed)
              _SheetRow(item: item, onTap: () => onOpen(first + i)),
          ],
        ),
      ],
    );
  }
}

/// One card on a sheet: a dot if new, script, reading and meaning, a
/// speaker where the phone has a voice, and an info mark; a tap inspects it.
class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.item, required this.onTap});

  final SheetCard item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final card = item.card;
    final language = item.deck.language;
    final reading = card.reading;
    final dot = item.isNew
        ? Tooltip(
            message: l10n.situationNotLearnt,
            excludeFromSemantics: true,
            child: Semantics(
              label: l10n.situationNotLearnt,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          )
        : const SizedBox(width: 10, height: 10);
    return Semantics(
      hint: l10n.situationCardDetails,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
            child: Row(
              children: <Widget>[
                dot,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TargetText(
                        card.target,
                        language: language,
                        fontSize: 20,
                        textAlign: TextAlign.start,
                        card: card,
                      ),
                      if (reading != null)
                        Text(
                          reading,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        card.native,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.hasVoice(language))
                  SpeakerIcon(
                    onPlay: () => state.speakCard(card, language),
                    label: l10n.drillPlay,
                  ),
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 8,
                    ),
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
