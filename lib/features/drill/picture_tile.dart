import 'package:flutter/material.dart' hide Card;

import '../../core/models/card.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/card_picture.dart';
import '../../ui/widgets/hint.dart';

/// One picture of a picture choice (#91), half the width. It shows the
/// picture and nothing written until it is answered, so its label for a
/// screen reader and its hint are "Picture 1 of 4": the card's meaning would
/// give the answer away. Once answered, the label and the text under the
/// picture are its meaning, and the right one, and the one chosen if it was
/// wrong, are marked in words as well as by colour and icon, as
/// [ChoiceTile] marks its own.
class PictureTile extends StatelessWidget {
  const PictureTile({
    super.key,
    required this.card,
    required this.number,
    required this.total,
    required this.right,
    required this.chosen,
    required this.answered,
    required this.onTap,
  });

  /// The card whose picture it shows.
  final Card card;

  /// Its place among the pictures, from 1, and how many there are.
  final int number;
  final int total;
  final bool right;
  final bool chosen;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wrong = chosen && !right;
    final (Color bg, Color fg, IconData icon) = right
        ? (
            scheme.primaryContainer,
            scheme.onPrimaryContainer,
            Icons.check_circle_outline,
          )
        : wrong
        ? (scheme.errorContainer, scheme.onErrorContainer, Icons.highlight_off)
        : (
            scheme.surfaceContainerLow,
            scheme.onSurface,
            Icons.radio_button_unchecked,
          );
    final label = answered
        ? card.native
        : l10n.drillPictureOption(number, total);
    return Hint(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: !answered,
        selected: chosen,
        label: label,
        value: right
            ? l10n.readingChoiceRight
            : wrong
            ? l10n.readingChoiceChosen
            : null,
        excludeSemantics: true,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
            side: BorderSide(
              color: answered && !right && !wrong
                  ? scheme.outlineVariant
                  : scheme.outline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: answered ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.primaryButton * 2,
              ),
              child: Stack(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      12,
                      16,
                      12,
                      12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CardPicture(card, size: 72),
                        if (answered) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            card.native,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge!.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: ExcludeSemantics(
                      child: Icon(icon, color: fg, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
