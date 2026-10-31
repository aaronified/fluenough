import 'package:flutter/material.dart';

import 'ipa_line.dart';

import '../../core/models/deck.dart';
import 'target_text.dart';

/// A word for a language learned without its alphabet: its [reading] first,
/// as large as the word would be, then the word in its script, smaller.
/// Both always show, whatever Latin-letter readings says.
class ReadingFirst extends StatelessWidget {
  const ReadingFirst({
    super.key,
    required this.reading,
    required this.target,
    required this.language,
    required this.fontSize,
    this.color,
    this.alignment = CrossAxisAlignment.center,
    this.ipaFont = false,
  });

  final String reading;
  final String target;
  final LanguageInfo language;

  /// The reading's size; the script is shown at two thirds of it.
  final double fontSize;

  /// The reading's colour; the script is muted.
  final Color? color;

  /// Where the two lines sit across each other: centred as a card's face,
  /// at the start where the word is left-aligned (the teach card).
  final CrossAxisAlignment alignment;

  /// The reading is the IPA (#697): its fonts are tried behind the theme's.
  final bool ipaFont;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          reading,
          textAlign: alignment == CrossAxisAlignment.start
              ? TextAlign.start
              : TextAlign.center,
          style: theme.textTheme.headlineMedium!
              .copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: color,
              )
              .forIpa(ipaFont),
        ),
        TargetText.card(
          target,
          language: language,
          fontSize: fontSize * 2 / 3,
          color: theme.colorScheme.onSurfaceVariant,
          textAlign: alignment == CrossAxisAlignment.start
              ? TextAlign.start
              : TextAlign.center,
        ),
      ],
    );
  }
}
