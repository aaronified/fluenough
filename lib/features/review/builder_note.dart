import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// What the deck's builder could not settle about a card and asks the
/// reviewer (docs/review-queue/README.md, 2026-11-06): a labelled note on a
/// daily question and on a card's review sheet. A hint, not part of the
/// answer.
class BuilderNote extends StatelessWidget {
  const BuilderNote({super.key, required this.questions});

  final List<String> questions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: <Widget>[
              ExcludeSemantics(
                child: Icon(
                  Icons.help_outline,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: <Widget>[
                    Text(
                      l10n.reviewBuilderQuestion,
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                    for (final question in questions)
                      Text(
                        question,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
