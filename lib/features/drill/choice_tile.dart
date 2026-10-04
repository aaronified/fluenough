import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// One choice of a multiple-choice question, the whole width. Once
/// answered, the right one is marked, and the one chosen if it was wrong,
/// each in words for screen readers as well as by colour and icon.
///
/// [label] builds what the choice shows in the style it is given, which
/// carries the colour of its state.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.right,
    required this.chosen,
    required this.answered,
    required this.onTap,
  });

  final Widget Function(TextStyle style) label;
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
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: !answered,
        selected: chosen,
        value: right
            ? l10n.readingChoiceRight
            : wrong
            ? l10n.readingChoiceChosen
            : null,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
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
                minHeight: AppSizes.primaryButton,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(icon, color: fg),
                    const SizedBox(width: 12),
                    Expanded(
                      child: label(
                        theme.textTheme.bodyLarge!.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
