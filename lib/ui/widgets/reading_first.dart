import 'package:flutter/material.dart';

import '../../core/models/deck.dart';
import 'target_text.dart';

/// A word for a language learned without its alphabet: its [reading] first,
/// as large as the word would be, then the word in its script, smaller.
/// Both always show, whatever Show romanisation says.
class ReadingFirst extends StatelessWidget {
  const ReadingFirst({
    super.key,
    required this.reading,
    required this.target,
    required this.language,
    required this.fontSize,
    this.color,
  });

  final String reading;
  final String target;
  final LanguageInfo language;

  /// The reading's size; the script is shown at two thirds of it.
  final double fontSize;

  /// The reading's colour; the script is muted.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          reading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium!.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        TargetText.card(
          target,
          language: language,
          fontSize: fontSize * 2 / 3,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
