import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/incoming.dart';

/// The Situations card on Today, under the buttons (#724; owner, 2026-10-23:
/// "Yes, below the buttons"): it opens the cheatsheets of key phrases for
/// everyday moments, hailing a cab or buying groceries.
///
/// The sheets are not built yet, so the card is shown disabled, marked
/// "Feature incoming" (ADR-0008). Mockup `docs/mockups/today-chain.html`,
/// screen 1.
class SituationsCard extends StatelessWidget {
  const SituationsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IncomingFeature(
      feature: Feature.situations,
      label: l10n.todaySituationsTitle,
      badge: IncomingBadgePlacement.below,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.group),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.group),
          onTap: () => showIncomingSnackBar(context),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_taxi_outlined,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.todaySituationsTitle,
                        style: theme.textTheme.sectionTitle,
                      ),
                      Text(
                        l10n.todaySituationsBody,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
