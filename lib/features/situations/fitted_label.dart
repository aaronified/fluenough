import 'package:flutter/material.dart';

/// The label size every situation tile starts from, in sp (the app's text
/// scaler then makes it 1.4x at most), and the least it shrinks to: at most
/// 2 sp smaller (owner, #1145).
const double fittedLabelBaseSize = 13;
const double fittedLabelMinSize = 11;

/// The tightest letter-spacing, in em, before the font shrinks.
const double fittedLabelTightest = -0.02;

/// How many lines a label wraps to before it is cut with an ellipsis.
const int fittedLabelMaxLines = 3;

/// Space kept free at each side of a label, in dp.
const double fittedLabelSidePadding = 4;

/// The least height of a situation tile at the base text size, in dp. It
/// grows with the text scale, as the mockup's 86 px x 1.4.
const double situationTileMinHeight = 86;

/// The size and letter-spacing a label settles on.
typedef LabelFit = ({double fontSize, double letterSpacing});

final RegExp _unbreakable = RegExp(
  r'[\u3040-\u30FF\u3400-\u9FFF\uFF00-\uFFEF]',
);

/// The fit order of a situation tile's label (owner, #1145), each step only
/// when the label does not yet fit [maxWidth], and never breaking a word:
/// 1. wrap at word boundaries, up to [fittedLabelMaxLines] lines;
/// 2. tighten the letter-spacing, down to [fittedLabelTightest] em;
/// 3. shrink the font by at most 2 sp, in half-sp steps.
/// Measured with the learner's text scaler, so the answer is what is drawn.
/// A label that fits at no step gets the smallest, tightest look.
///
/// A "word" is a run between spaces; a run of Chinese or Japanese letters,
/// which has no spaces, may break between letters and is never measured as
/// one word.
LabelFit fitLabel({
  required String text,
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required double maxWidth,
}) {
  final words = <String>[
    for (final w in text.split(RegExp(r'\s+')))
      if (w.isNotEmpty && !_unbreakable.hasMatch(w)) w,
  ];

  bool fits(double size, double em) {
    final s = style.copyWith(fontSize: size, letterSpacing: em * size);
    final painter = TextPainter(
      text: TextSpan(text: text, style: s),
      textDirection: textDirection,
      textScaler: textScaler,
      textAlign: TextAlign.center,
      maxLines: fittedLabelMaxLines,
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    if (exceeded) return false;
    for (final word in words) {
      final one = TextPainter(
        text: TextSpan(text: word, style: s),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      final wide = one.width > maxWidth + 0.01;
      one.dispose();
      if (wide) return false;
    }
    return true;
  }

  if (fits(fittedLabelBaseSize, 0)) {
    return (fontSize: fittedLabelBaseSize, letterSpacing: 0);
  }
  var size = fittedLabelBaseSize;
  while (true) {
    if (fits(size, fittedLabelTightest)) {
      return (fontSize: size, letterSpacing: fittedLabelTightest * size);
    }
    if (size <= fittedLabelMinSize) {
      return (
        fontSize: fittedLabelMinSize,
        letterSpacing: fittedLabelTightest * fittedLabelMinSize,
      );
    }
    size = size - 0.5 < fittedLabelMinSize ? fittedLabelMinSize : size - 0.5;
  }
}

/// The name on a situation tile, on Today and in the picker: the one widget
/// that applies [fitLabel], so the two cannot drift. [width] is the width of
/// the tile; the label keeps [fittedLabelSidePadding] free at each side. The
/// caller centres it in the space below the icon.
class FittedLabel extends StatelessWidget {
  const FittedLabel({
    super.key,
    required this.text,
    required this.width,
    required this.color,
    this.fontWeight = FontWeight.w700,
  });

  final String text;
  final double width;
  final Color color;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontWeight: fontWeight,
      color: color,
      height: 1.2,
    );
    final fit = fitLabel(
      text: text,
      style: base,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxWidth: width - 2 * fittedLabelSidePadding,
    );
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: fittedLabelSidePadding),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: fittedLabelMaxLines,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(
            fontSize: fit.fontSize,
            letterSpacing: fit.letterSpacing,
          ),
        ),
      ),
    );
  }
}
