import 'package:flutter/material.dart';

import '../../app/links.dart';
import '../../core/review/move_targets.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';

/// Opens "Move this card" (#477, docs/mockups/reviewer-mode.html, section
/// 3): the units of the course's B1 plan [targets], and nothing else, as a
/// list to choose from. It starts with the rule that a new theme or unit
/// needs a pull request on GitHub, with a link to how. A planned unit is
/// shown, greyed, and cannot be chosen: it has no deck to move the card
/// into. Resolves to the unit chosen, or null when the sheet is closed.
Future<MoveTarget?> showMoveSheet(
  BuildContext context, {
  required List<MoveTarget> targets,
  required String languageName,
  String? chosen,
}) => showModalBottomSheet<MoveTarget>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      MoveSheet(targets: targets, languageName: languageName, chosen: chosen),
);

/// The body of [showMoveSheet].
class MoveSheet extends StatelessWidget {
  const MoveSheet({
    super.key,
    required this.targets,
    required this.languageName,
    this.chosen,
  });

  final List<MoveTarget> targets;
  final String languageName;

  /// The deck already chosen, shown selected.
  final String? chosen;

  /// The row of the unit of the deck [deckId].
  static Key rowKey(String deckId) => ValueKey<String>('move-$deckId');

  /// How to contribute.
  static const Key contributeKey = ValueKey<String>('move-contribute');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.commonClose,
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.reviewMoveTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Text(
                            l10n.reviewMoveRule(languageName),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      key: contributeKey,
                      onPressed: () => openLink(
                        context,
                        AppLinks.contribute,
                        copied: l10n.reviewMoveContributeCopied,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(l10n.reviewMoveContribute),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Flexible(
            child: RadioGroup<String>(
              groupValue: chosen,
              onChanged: (id) {
                final pick = targets
                    .where((t) => t.deckId == id && !t.planned)
                    .firstOrNull;
                if (pick != null) Navigator.of(context).pop(pick);
              },
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final t in targets)
                    RadioListTile<String>(
                      key: rowKey(t.deckId),
                      value: t.deckId,
                      enabled: !t.planned,
                      title: Text(l10n.reviewPlaceUnit(t.unit, t.name)),
                      subtitle: t.planned ? Text(l10n.reviewMovePlanned) : null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
