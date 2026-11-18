import 'dart:io';

import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../theme.dart';

/// A sign card's sign (ADR-0056): the picture drawn from its Formal
/// SignWriting, shown where the target's text would be. A sign is
/// two-dimensional, so no font draws it, and its FSW text is never shown.
///
/// The picture is a WebP on a light background, so it sits on a white card
/// with rounded corners and a thin edge, which reads in the dark theme too.
/// Its label for a screen reader is the card's meaning, `native`, unless
/// [semanticLabel] says another (a choice of signs says only "Sign 1 of 4",
/// as [PictureTile] does for pictures). Without the file on the phone, or
/// when it cannot be read, a hand mark stands in: never the text.
class SignImage extends StatelessWidget {
  const SignImage(this.card, {super.key, this.size = 160, this.semanticLabel});

  final Card card;

  /// The side of the square it is drawn in.
  final double size;

  /// What a screen reader says; the card's meaning by default.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // The scope is looked up without subscribing to it, and may be absent
    // where a card is shown on its own, as in the gallery.
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    final file = scope?.notifier?.mediaFile(card.image);
    final scheme = Theme.of(context).colorScheme;
    final mark = Icon(
      Icons.sign_language_outlined,
      size: size / 3,
      color: scheme.outline,
    );
    return Semantics(
      image: true,
      label: semanticLabel ?? card.native,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey<String>('sign-image'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Light in both themes: the picture's own background is light.
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.field),
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: file == null
            ? mark
            : Image.file(
                File(file),
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => mark,
              ),
      ),
    );
  }
}

/// The side a sign is drawn at as a drill's big target: about 45% of the
/// screen's width, 162 on a 360 wide phone, and no more than 240 nor less
/// than 140. It does not follow the text scale: it is a picture.
double signHeroSize(BuildContext context) =>
    (MediaQuery.sizeOf(context).width * 0.45).clamp(140.0, 240.0).toDouble();
