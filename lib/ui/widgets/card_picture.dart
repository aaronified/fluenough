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
    final drawn = file == null
        ? emoji
        : ClipRRect(
            // Follows the picture's size on purpose.
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
          );
    // A question word's picture asks: a "?" badge on its corner. Its own
    // image is a photo of the thing, so only the emoji wears it.
    if (!card.pictureAsk || picture == null || file != null) {
      return ExcludeSemantics(child: drawn);
    }
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          drawn,
          PositionedDirectional(
            end: -size / 12,
            bottom: -size / 12,
            child: _AskBadge(size: size),
          ),
        ],
      ),
    );
  }
}

/// The small "?" on a question word's picture, in the theme's colours. Its
/// size follows the picture, never the text scale, so it is as readable at
/// 1.4x as at 1x.
class _AskBadge extends StatelessWidget {
  const _AskBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final diameter = size < 48 ? size * 0.5 : size / 3;
    return Container(
      key: const ValueKey<String>('picture-ask'),
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface, width: 1.5),
      ),
      child: Text(
        '?', // ui-literal-ok: a symbol on a picture, not prose; no words to translate
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: colors.onPrimary,
          fontSize: diameter * 0.7,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
