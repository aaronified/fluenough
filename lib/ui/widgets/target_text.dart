import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/deck.dart';
import '../theme.dart';

/// Deck content in the deck's language: a card's target, a lemma, a leech.
///
/// Every piece of target-language text goes through this, because it gets
/// three things right in one place:
///
/// - **Direction** from the deck ([LanguageInfo.rtl]), not from the
///   interface language: an Urdu card is right to left in an English app.
/// - **Locale** from the deck's language code, so a character shared between
///   scripts takes the right regional form.
/// - **Line height** of 1.9 for right-to-left scripts, whose Nastaliq forms
///   climb and descend far more than Latin, and 1.25 otherwise.
///
/// [TargetText.hero] sizes the text as the design does — 96, 64 or 48 by
/// length — times the learner's card text scale, which it follows live.
class TargetText extends StatelessWidget {
  const TargetText(
    this.text, {
    super.key,
    required this.language,
    required this.fontSize,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.textAlign = TextAlign.center,
  }) : _hero = false;

  /// The big text on a drill card, sized by its length and the card scale.
  const TargetText.hero(
    this.text, {
    super.key,
    required this.language,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.textAlign = TextAlign.center,
  }) : fontSize = null,
       _hero = true;

  final String text;
  final LanguageInfo language;

  /// Null only for [TargetText.hero], which works it out.
  final double? fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final TextAlign textAlign;
  final bool _hero;

  @override
  Widget build(BuildContext context) {
    if (!_hero) return _text(fontSize!);
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) =>
          _text(TargetSizes.forText(text, scale: settings.cardTextScale)),
    );
  }

  Widget _text(double size) => Text(
    text,
    textAlign: textAlign,
    textDirection: language.rtl ? TextDirection.rtl : TextDirection.ltr,
    locale: Locale(language.code),
    style: TextStyle(
      fontSize: size,
      fontWeight: fontWeight,
      color: color,
      height: language.rtl ? TargetSizes.rtlHeight : TargetSizes.ltrHeight,
    ),
  );
}

/// [text], an interface string that quotes deck content, with each of
/// [quotes] in it marked as [language]'s: drawn in its font and read by a
/// screen reader in its voice, while the rest stays the interface's (#26).
/// "Answer: el niño" is read in English up to the colon and in Spanish after.
TextSpan quotingTarget(
  String text,
  Iterable<String> quotes,
  LanguageInfo language,
) {
  // Longest first, so that at one place "el niño" wins over "niño".
  final wanted = <String>{
    for (final quote in quotes)
      if (quote.isNotEmpty) quote,
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  final locale = Locale(language.code);
  final spans = <TextSpan>[];
  var start = 0;
  while (start < text.length) {
    var at = -1;
    String? found;
    for (final quote in wanted) {
      final i = text.indexOf(quote, start);
      if (i >= 0 && (at < 0 || i < at)) {
        at = i;
        found = quote;
      }
    }
    if (found == null) break;
    if (at > start) spans.add(TextSpan(text: text.substring(start, at)));
    spans.add(TextSpan(text: found, locale: locale));
    start = at + found.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return TextSpan(children: spans);
}
