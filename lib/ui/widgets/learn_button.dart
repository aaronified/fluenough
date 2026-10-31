import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// The Learn / Relearn control of a deck page and a unit page (#694): a
/// filled button, full width of its slot, with an icon as tall as the label
/// and the subtext under it together (owner, 2026-10-31), centred beside the
/// two lines when there is a subtext (the unit page has one; the deck page has
/// none, so the icon matches the label alone). Learn has the plus icon, Relearn the replay icon, both the
/// same size, which follows the text scale so that at 1.4x it neither
/// overflows nor squeezes the label. Off when [onPressed] is null.
///
/// The button's semantics are the label and the subtext together, read as
/// one ("Learn, 6 new, 4 due"); the icon adds none.
class LearnButton extends StatelessWidget {
  const LearnButton({
    super.key,
    required this.relearn,
    required this.onPressed,
    this.subtext,
  });

  /// Relearn, with its icon, once every card is taught; otherwise Learn.
  final bool relearn;
  final VoidCallback? onPressed;

  /// The line under the label, such as "6 new · 4 due".
  final String? subtext;

  /// The key of the icon, for tests.
  static const Key iconKey = ValueKey<String>('learn-button-icon');

  /// The key of the label and subtext together, for tests.
  static const Key textKey = ValueKey<String>('learn-button-text');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = relearn ? l10n.deckRelearn : l10n.deckLearn;
    final line = subtext;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          // Tighter than the default 24, so the label keeps its room beside
          // the tall icon in the narrower slot of a deck page at 1.4x.
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: onPressed,
        child: Builder(
          builder: (context) {
            final base = DefaultTextStyle.of(context).style;
            final labelStyle = base.copyWith(
              fontWeight: FontWeight.w600,
              height: base.height ?? 20 / 14,
            );
            final subStyle = base.copyWith(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w400,
            );
            final scaler = MediaQuery.textScalerOf(context);
            double lineHeight(TextStyle style) =>
                scaler.scale(style.fontSize ?? 14) * (style.height ?? 1.2);
            // The label and the subtext line, at the text size drawn; the
            // label alone where there is no subtext.
            final iconSize =
                lineHeight(labelStyle) +
                (line == null ? 0 : lineHeight(subStyle));
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  relearn ? Icons.replay_rounded : Icons.add_rounded,
                  key: iconKey,
                  size: iconSize,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    key: textKey,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: labelStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (line != null)
                        Text(
                          line,
                          style: subStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
