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
/// Text in a drill follows the learner's card text size, live:
/// [TargetText.hero] sizes it as the design does — 96, 64 or 48 by length —
/// and [TargetText.card] from a size it is given, both times the scale.
/// Elsewhere, as in lists and menus, a plain [TargetText] keeps its size.
class TargetText extends StatelessWidget {
  const TargetText(
    this.text, {
    super.key,
    required this.language,
    required double this.fontSize,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.textAlign = TextAlign.center,
  }) : _sizing = _Sizing.fixed;

  /// The big text on a drill card, sized by its length and the card scale.
  const TargetText.hero(
    this.text, {
    super.key,
    required this.language,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.textAlign = TextAlign.center,
  }) : fontSize = null,
       _sizing = _Sizing.hero;

  /// Other text on a drill card, at [fontSize] times the card scale.
  const TargetText.card(
    this.text, {
    super.key,
    required this.language,
    required double this.fontSize,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.textAlign = TextAlign.center,
  }) : _sizing = _Sizing.card;

  final String text;
  final LanguageInfo language;

  /// Null only for [TargetText.hero], which works it out. For
  /// [TargetText.card], the size at a scale of 1.
  final double? fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final TextAlign textAlign;
  final _Sizing _sizing;

  @override
  Widget build(BuildContext context) {
    if (_sizing == _Sizing.fixed) return _text(fontSize!);
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _text(
        _sizing == _Sizing.hero
            ? TargetSizes.forText(text, scale: settings.cardTextScale)
            : fontSize! * settings.cardTextScale,
      ),
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

enum _Sizing { fixed, hero, card }

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
