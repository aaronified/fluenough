import 'package:flutter/material.dart';

import '../../app/deck_catalog.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/deck_tile.dart';

/// A deck file that could not be read, as a row in the deck list: the file,
/// the line, and the parser's message verbatim (ADR-0006: exception text is
/// not translated), with an Error badge.
///
/// Laid out like a `DeckTile`, with a warning where the glyph would be. Put
/// it inside a `GroupedList`.
class BrokenDeckTile extends StatelessWidget {
  const BrokenDeckTile({super.key, required this.broken, this.glyphSize = 56});

  final BrokenDeck broken;
  final double glyphSize;

  /// "Line 12: …" and the message, or the message alone when the parser could not
  /// say which line.
  static String detailFor(AppLocalizations l10n, BrokenDeck broken) {
    final error = broken.error;
    final line = error.line;
    return line == null
        ? error.message
        : l10n.decksBrokenAt(line, error.message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return MergeSemantics(
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
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(glyphSize * 0.32),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.decksBrokenTitle(broken.fileName),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailFor(l10n, broken),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const DeckBadge(kind: DeckBadgeKind.error),
          ],
        ),
      ),
    );
  }
}
