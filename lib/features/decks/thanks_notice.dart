import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// On a unit whose decks list the reviewer's rater code, in place of the
/// notice that no speaker has checked it: thanks, and who checked it
/// (docs/plans/deck-browser.md, "No reply mail; thanks in the app").
class ThanksNotice extends StatelessWidget {
  const ThanksNotice({super.key, required this.code, required this.others});

  /// The reviewer's own rater code.
  final String code;

  /// How many other reviewers' codes the deck lists.
  final int others;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.favorite, size: 20, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.reviewThanksTitle,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.reviewThanksBy(others < 0 ? 0 : others, code),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
