import 'package:flutter/material.dart';

import '../../core/scheduling/placed_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// The words of a [PlacedReview] choice (#761, the approved mockup
/// `placement-review-choice.html`, wording B).
extension PlacedReviewText on PlacedReview {
  String title(AppLocalizations l10n) => switch (this) {
    PlacedReview.setInStone => l10n.placedReviewSetInStone,
    PlacedReview.spotCheck => l10n.placedReviewSpotCheck,
    PlacedReview.keepReviewing => l10n.placedReviewKeep,
  };

  String body(AppLocalizations l10n) => switch (this) {
    PlacedReview.setInStone => l10n.placedReviewSetInStoneBody,
    PlacedReview.spotCheck => l10n.placedReviewSpotCheckBody,
    PlacedReview.keepReviewing => l10n.placedReviewKeepBody,
  };

  IconData get icon => switch (this) {
    PlacedReview.setInStone => Icons.check_circle_outline,
    PlacedReview.spotCheck => Icons.manage_search,
    PlacedReview.keepReviewing => Icons.refresh,
  };
}

/// The three choices of how placed words are reviewed, one card each with a
/// radio mark, the picked one in the secondary container with a thicker
/// outline, so that it is never colour alone. Picking one calls [onChanged].
/// [tagged] gets the "Default" tag.
class PlacedReviewOptions extends StatelessWidget {
  const PlacedReviewOptions({
    super.key,
    required this.value,
    required this.onChanged,
    this.tagged,
  });

  final PlacedReview value;
  final ValueChanged<PlacedReview> onChanged;
  final PlacedReview? tagged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final choice in PlacedReview.values) ...<Widget>[
          Builder(
            builder: (context) {
              final picked = choice == value;
              final onColour = picked
                  ? scheme.onSecondaryContainer
                  : scheme.onSurface;
              return Semantics(
                inMutuallyExclusiveGroup: true,
                checked: picked,
                selected: picked,
                button: true,
                child: Material(
                  color: picked
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.field),
                    side: BorderSide(
                      color: picked ? scheme.primary : scheme.outlineVariant,
                      width: picked ? 2 : 1,
                    ),
                  ),
                  // hint-ok: shows text
                  child: InkWell(
                    key: ValueKey<String>('placed-review-${choice.name}'),
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.field),
                    ),
                    onTap: () => onChanged(choice),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        14,
                        12,
                        14,
                        12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            picked
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: picked
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text.rich(
                                  TextSpan(
                                    children: <InlineSpan>[
                                      TextSpan(text: choice.title(l10n)),
                                      if (choice == tagged)
                                        TextSpan(
                                          text: '  ${l10n.placedReviewDefault}',
                                          style: theme.textTheme.labelSmall,
                                        ),
                                    ],
                                  ),
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    color: onColour,
                                  ),
                                ),
                                Text(
                                  choice.body(l10n),
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: picked
                                        ? scheme.onSecondaryContainer
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(choice.icon, color: onColour),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSizes.gutter / 2),
        ],
      ],
    );
  }
}

/// The sheet that changes how [language]'s course reviews its placed words
/// (#761). Tapping a choice applies it at once, through [onChanged], and
/// closes the sheet.
Future<void> showPlacedReviewSheet(
  BuildContext context, {
  required String language,
  required PlacedReview current,
  required ValueChanged<PlacedReview> onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSizes.gutter,
        0,
        AppSizes.gutter,
        AppSizes.gutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.placedReviewSheetTitle(language),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          PlacedReviewOptions(
            value: current,
            onChanged: (choice) {
              onChanged(choice);
              Navigator.of(context).pop();
            },
          ),
          Text(
            l10n.placedReviewSheetNote,
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  },
);
