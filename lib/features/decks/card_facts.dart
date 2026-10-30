import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// The "Facts" section at the end of a card's sheet (#546; owner,
/// 2026-10-17: "A Facts section at the end of the card sheet"): each fact
/// that names the card, in each language the learner speaks that it is
/// written in, best known first. Built only when a fact names the card.
///
/// A fact is deck content, shown as written, with its own language for the
/// screen reader and the font.
class CardFacts extends StatelessWidget {
  const CardFacts({super.key, required this.facts});

  /// The facts naming the card ([AppState.factsNaming]); never empty.
  final List<CardFact> facts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(l10n.wordSheetFacts, style: theme.textTheme.sectionTitle),
        ),
        for (final fact in facts) ...<Widget>[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final (i, text) in fact.texts.indexed) ...<Widget>[
                  if (i > 0) const SizedBox(height: 8),
                  Text(
                    text.text,
                    locale: Locale(text.code),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
