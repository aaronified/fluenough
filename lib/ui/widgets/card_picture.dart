import 'dart:io';

import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';

/// The picture of what [card] means, where it has one (ADR-0034): a cue
/// beside its meaning. Its own image, a photo or an OpenMoji drawing shipped
/// with the deck, shows where it is on the phone (#523); otherwise its Noto
/// Emoji picture. The meaning is always written next to it, so the picture
/// says nothing more to a screen reader.
class CardPicture extends StatelessWidget {
  const CardPicture(this.card, {super.key, this.size = 72});

  final Card card;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The scope is looked up without subscribing to it, and may be absent
    // where a card is shown on its own, as in the gallery.
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    final file = scope?.notifier?.mediaFile(card.image);
    final picture = card.picture;
    final emoji = picture == null
        ? SizedBox.square(dimension: size)
        : Image.asset(
            picturePath(picture),
            key: const ValueKey<String>('picture'),
            width: size,
            height: size,
            // A picture missing from the bundle shows nothing rather than
            // an error: the meaning beside it still asks the question.
            errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
          );
    if (file == null && picture == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: file == null
          ? emoji
          : ClipRRect(
              borderRadius: BorderRadius.circular(size / 8),
              child: Image.file(
                File(file),
                key: const ValueKey<String>('image'),
                width: size,
                height: size,
                fit: BoxFit.contain,
                // An image that cannot be read falls back to the emoji.
                errorBuilder: (_, _, _) => emoji,
              ),
            ),
    );
  }
}
