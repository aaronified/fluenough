import 'package:flutter/material.dart';

import '../../app/deck_catalog.dart';
import '../../app/links.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';

/// On a deck no native speaker has checked, tagged `unreviewed`: says so and
/// asks speakers to report mistakes (#39). The Telugu decks carry it.
///
/// The button opens the project's issues, or copies their address when
/// nothing can, as the keyboard hint does.
class UnreviewedNotice extends StatelessWidget {
  const UnreviewedNotice({super.key, required this.entry});

  final DeckEntry entry;

  /// The tag that marks a deck no native speaker has checked.
  static const String tag = 'unreviewed';

  /// Whether [entry] shows the notice.
  static bool appliesTo(DeckEntry entry) => entry.deck.tags.contains(tag);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.deckUnreviewed(entry.language.name),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () => openLink(
                    context,
                    AppLinks.issues,
                    copied: l10n.deckUnreviewedCopied,
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(l10n.deckUnreviewedReport),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
