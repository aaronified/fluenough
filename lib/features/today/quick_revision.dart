import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/session.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// Quick revision on Today (ADR-0029): 5, 10, 15 or 20 words the learner
/// has been taught, picked at random, due or not. A miss is recorded; a
/// right answer is not.
class QuickRevision extends StatelessWidget {
  const QuickRevision({super.key, required this.known});

  /// The sizes offered, in words.
  static const List<int> sizes = <int>[5, 10, 15, 20];

  /// How many words there are to revise. With none, the buttons are off and
  /// a line says why.
  final int known;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Semantics(
            header: true,
            child: Text(
              l10n.todayRevisionTitle,
              style: theme.textTheme.sectionTitle,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text(
            known == 0 ? l10n.todayRevisionNone : l10n.todayRevisionBody,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            for (final (i, size) in sizes.indexed) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  style: AppButtonStyles.tall(context),
                  onPressed: known == 0
                      ? null
                      : () => AppNavigator.startDrill(
                          context,
                          DrillRequest.revision(size),
                        ),
                  child: Semantics(
                    label: l10n.todayRevisionCards(size),
                    excludeSemantics: true,
                    child: Text('$size'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
