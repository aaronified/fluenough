import 'package:flutter/material.dart';

import '../../core/data/deck_parser.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// "This deck couldn't be read": the file, the line and the parser's own
/// message, verbatim (ADR-0006), then that nothing was added.
///
/// Laid out straight from a [DeckParseException]: its `source` is the file,
/// its `line` the line, its `message` the explanation, which already says
/// how to fix it. Without a line, it names the file alone.
class ImportErrorCard extends StatelessWidget {
  const ImportErrorCard({super.key, required this.error});

  final DeckParseException error;

  /// Where and what: "ja-kana.yaml, line 12: …", or "ja-kana.yaml: …".
  static String detailFor(AppLocalizations l10n, DeckParseException error) {
    final line = error.line;
    return line == null
        ? l10n.importErrorIn(error.source, error.message)
        : l10n.importErrorAt(error.source, line, error.message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final body = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onErrorContainer,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.group),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  size: 22,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.importErrorTitle,
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(detailFor(l10n, error), style: body),
            const SizedBox(height: 10),
            Text(
              l10n.importErrorNothingAdded,
              style: body.copyWith(
                color: scheme.onErrorContainer.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
