import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../l10n/app_localizations.dart';

/// The theme whose deck the practice row follows (#54).
const String numberPracticeTheme = 'numbers-big';

/// Whether [entry] is a number deck with number practice after it: its
/// theme is [numberPracticeTheme] and its language has number rules.
bool hasNumberPractice(AppState state, DeckEntry entry) =>
    entry.deck.theme == numberPracticeTheme &&
    state.numberRulesFor(entry.language) != null;

/// Number practice, as a row under the big-numbers deck on the Decks tab:
/// generated four-digit numbers, drilled and not recorded (ADR-0011).
///
/// Laid out like a `DeckTile`, with an icon where the glyph would be. Put it
/// inside a `GroupedList`.
class NumberPracticeTile extends StatelessWidget {
  const NumberPracticeTile({
    super.key,
    required this.deck,
    this.glyphSize = 56,
  });

  /// The number deck the practice follows, which gives it its language.
  final DeckEntry deck;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return MergeSemantics(
      child: InkWell(
        onTap: () =>
            AppNavigator.startDrill(context, DrillRequest.numbers(deck.id)),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: glyphSize,
                height: glyphSize,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(glyphSize * 0.32),
                ),
                child: Icon(
                  Icons.onetwothree,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.numbersPracticeTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.numbersPracticeMeta,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
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
