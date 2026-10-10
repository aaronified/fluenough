import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../decks/deck_content.dart' show formatCount;

/// Opens "How reviewing works" (docs/plans/deck-browser.md): by itself once,
/// the first time reviewing is turned on, and from Settings at any time,
/// with reviewing on or off.
Future<void> showHowReviewingWorks(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const HowReviewingWorks(),
    );

/// Reviewing in five steps, in the order it happens, then what offensive
/// words ask of a rater. The steps scroll under the title; Got it stays in
/// place, as the app's other long sheets do.
class HowReviewingWorks extends StatelessWidget {
  const HowReviewingWorks({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final steps = <(String, String)>[
      (l10n.reviewHowCodeTitle, l10n.reviewHowCodeBody),
      (l10n.reviewHowCheckTitle, l10n.reviewHowCheckBody),
      (l10n.reviewHowProposalsTitle, l10n.reviewHowProposalsBody),
      (l10n.reviewHowSendTitle, l10n.reviewHowSendBody),
      (l10n.reviewHowSameTitle, l10n.reviewHowSameBody),
      (l10n.reviewHowPublicTitle, l10n.reviewHowPublicBody),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 12),
            child: Semantics(
              header: true,
              child: Text(
                l10n.reviewSettingsHow,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final (i, (title, body)) in steps.indexed) ...<Widget>[
                    MergeSemantics(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Semantics(
                            label: l10n.reviewHowStep(i + 1),
                            excludeSemantics: true,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: scheme.secondaryContainer,
                              foregroundColor: scheme.onSecondaryContainer,
                              child: Text(
                                formatCount(context, i + 1),
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(title, style: theme.textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text(body, style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsetsDirectional.all(14),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: MergeSemantics(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: scheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.reviewHowAdult,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.reviewHowOff,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.reviewHowGotIt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
