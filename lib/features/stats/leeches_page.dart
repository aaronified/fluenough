import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/skill.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/target_text.dart';
import 'leeches.dart';
import 'stats_numbers.dart';

/// Cards missed again and again, with Reset and Set aside. Behind `Feature.leeches`.
///
/// Design screen `leeches`. Lists every pair at or over [kLeechThreshold]
/// lapses. Reset and Set aside are appended to [LeechActions], never taken
/// out of the review log; a card acted on stays listed, dimmed, so the
/// action can be undone.
class LeechesPage extends StatelessWidget {
  const LeechesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final actions = LeechActions.of(state.progress);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.leechesTitle)),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[state.progress, actions]),
          builder: (context, _) {
            final leeches = findLeeches(
              state.progress,
              cardOf: cardLookupOf(state),
            );
            if (leeches.isEmpty) {
              return EmptyState(
                icon: Icons.check_circle_outline,
                title: l10n.leechesEmpty,
              );
            }
            final theme = Theme.of(context);
            final incoming = state.features.isIncoming(Feature.leeches);
            return ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 4),
                  child: Text(
                    l10n.leechesIntro(kLeechThreshold),
                    style: theme.textTheme.bodyLarge!.copyWith(
                      fontSize: 15,
                      height: 22 / 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (incoming)
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(8, 4, 8, 0),
                      child: IncomingBadge(),
                    ),
                  ),
                for (final leech in leeches) ...<Widget>[
                  const SizedBox(height: 12),
                  LeechCard(
                    leech: leech,
                    status: actions.statusOf(leech.key),
                    onReset: () =>
                        actions.toggleReset(leech.key, now: state.now()),
                    onSetAside: () =>
                        actions.toggleSetAside(leech.key, now: state.now()),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One leech: its target, meaning, deck and skill, how often it was missed,
/// and Reset / Set aside. Dimmed once either is done, with the button that
/// was used becoming Undo or Bring back.
class LeechCard extends StatelessWidget {
  const LeechCard({
    super.key,
    required this.leech,
    required this.status,
    required this.onReset,
    required this.onSetAside,
  });

  final Leech leech;
  final LeechStatus status;
  final VoidCallback onReset;
  final VoidCallback onSetAside;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final AppState state = AppScope.of(context);
    final entry = state.deckById(leech.key.deckId)!;
    final deck = entry.deck.name;
    final skill = Skill.of(leech.key.mode).label(l10n);
    final meta = switch (status) {
      LeechStatus.active => l10n.leechesMeta(deck, skill),
      LeechStatus.reset => l10n.leechesMetaReset(deck, skill),
      LeechStatus.setAside => l10n.leechesMetaSetAside(deck, skill),
    };
    final incoming = state.features.isIncoming(Feature.leeches);

    Widget gate(String label, Widget button) => incoming
        ? IncomingFeature(
            feature: Feature.leeches,
            label: label,
            badge: IncomingBadgePlacement.none,
            child: button,
          )
        : button;

    final resetLabel = status == LeechStatus.reset
        ? l10n.commonUndo
        : l10n.leechesReset;
    final setAsideLabel = status == LeechStatus.setAside
        ? l10n.leechesBringBack
        : l10n.leechesSetAside;

    final lapses = Semantics(
      label: l10n.leechesLapsesSemantics(leech.lapses),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        alignment: Alignment.center,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          l10n.leechesLapses(leech.lapses),
          style: theme.textTheme.labelLarge!.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.onErrorContainer,
          ),
        ),
      ),
    );

    return AnimatedOpacity(
      opacity: status == LeechStatus.active ? 1 : 0.6,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsetsDirectional.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MergeSemantics(
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 64),
                      child: TargetText(
                        leech.card.target,
                        language: entry.language,
                        fontSize: 26,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          leech.card.native,
                          style: theme.textTheme.bodyLarge!.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall!.copyWith(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  lapses,
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                gate(
                  resetLabel,
                  OutlinedButton(
                    style: AppButtonStyles.compact(context),
                    onPressed: incoming ? null : onReset,
                    child: Text(resetLabel),
                  ),
                ),
                gate(
                  setAsideLabel,
                  FilledButton.tonal(
                    style: AppButtonStyles.compact(context),
                    onPressed: incoming ? null : onSetAside,
                    child: Text(setAsideLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
