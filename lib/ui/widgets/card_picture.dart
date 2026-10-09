import 'package:flutter/material.dart' hide Card;

import '../../core/models/card.dart';

/// The picture of what [card] means, where it has one (ADR-0034): a cue
/// beside its meaning. The meaning is always written next to it, so the
/// picture says nothing more to a screen reader.
class CardPicture extends StatelessWidget {
  const CardPicture(this.card, {super.key, this.size = 72});

  final Card card;
  final double size;

  @override
  Widget build(BuildContext context) {
    final picture = card.picture;
    if (picture == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Image.asset(
        picturePath(picture),
        key: const ValueKey<String>('picture'),
        width: size,
        height: size,
        // A picture missing from the bundle shows nothing rather than an
        // error: the meaning beside it still asks the question.
        errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
      ),
    );
  }
}
