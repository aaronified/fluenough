import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/aksharas.dart';
import '../../core/models/deck.dart';
import '../card_text_scale.dart';
import '../theme.dart';
import 'drill_frame.dart';

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
/// - **Font** of the script, once the course's font is downloaded and loaded
///   (ADR-0042): phones often draw Indic and Nastaliq text wrongly or lack
///   the script. Until then, or without one, the phone's own font.
///
/// Text in a drill follows the learner's card text size, live:
/// [TargetText.hero] sizes it as the design does — 96, 64 or 48 by length —
/// and [TargetText.card] from a size it is given, both times the scale.
/// Elsewhere, as in lists and menus, a plain [TargetText] keeps its size.
///
/// On a drill card, a long word in a script that needs a reading breaks
/// across lines only between its aksharas, never inside one (owner,
/// 2026-10-16, #515: "Break between syllables"): [breakableWord] gives the
/// line breaker those places and no others. A screen reader reads the word
/// as written. A long word in a joined script, such as Urdu, is never
/// broken: it shrinks until it fits the line ("Shrink Urdu instead").
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
    // Not AppScope.of: a plain TargetText never needed the scope, and the
    // script fonts notify on their own.
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    final fonts = scope?.notifier?.deckDownloads?.fonts;
    if (fonts == null) return _sized(context, null);
    return ListenableBuilder(
      listenable: fonts,
      builder: (context, _) =>
          _sized(context, fonts.familyFor(language.script)),
    );
  }

  /// The text at its size, in [family], the script's downloaded font, or
  /// the phone's own when it is null.
  Widget _sized(BuildContext context, String? family) {
    if (_sizing == _Sizing.fixed) return _text(context, fontSize!, family);
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final scale = cardTextScaleOf(context, settings);
        return _text(
          context,
          _sizing == _Sizing.hero
              ? TargetSizes.forText(text, scale: scale)
              : fontSize! * scale,
          family,
        );
      },
    );
  }

  Widget _text(BuildContext context, double base, String? family) {
    var size = base;
    var shown = text;
    if (_sizing != _Sizing.fixed && _isOneWord) {
      final room = MediaQuery.sizeOf(context).width - _cardMargins;
      final width = _width(context, size, family);
      if (width > room) {
        if (hasAksharas(text)) {
          shown = breakableWord(text);
        } else if (isJoinedScript(text)) {
          // Shrunk to fit, a hair under, so that rounding never wraps it.
          size = size * room / width * 0.98;
        }
      }
    }
    return Text(
      shown,
      semanticsLabel: shown == text ? null : text,
      textAlign: textAlign,
      textDirection: language.rtl ? TextDirection.rtl : TextDirection.ltr,
      locale: Locale(language.code),
      style: TextStyle(
        fontSize: size,
        fontWeight: _styleWeight(family, fontWeight),
        fontFamily: family,
        fontVariations: _variations(family, fontWeight),
        color: color,
        height: language.rtl ? TargetSizes.rtlHeight : TargetSizes.ltrHeight,
      ),
    );
  }

  /// What a variable font needs to draw [weight]: the downloaded fonts are
  /// one file each, registered without a weight, so the weight is set on
  /// its axis. Fonts with no such axis ignore it.
  static List<FontVariation>? _variations(String? family, FontWeight weight) {
    if (family == null) return null;
    return <FontVariation>[FontVariation.weight(weight.value.toDouble())];
  }

  /// The weight to ask the text style for: with a downloaded font, which is
  /// one face registered at its default weight, the normal weight, so that
  /// the engine adds no synthetic bold on top of [_variations]' own.
  static FontWeight _styleWeight(String? family, FontWeight weight) =>
      family == null ? weight : FontWeight.normal;

  /// Whether [text] is one word: a longer text breaks between its words.
  bool get _isOneWord => !text.contains(RegExp(r'\s'));

  /// How wide [text] is on one line at [size], scaled as the screen scales
  /// text.
  double _width(BuildContext context, double size, String? family) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: _styleWeight(family, fontWeight),
          fontFamily: family,
          fontVariations: _variations(family, fontWeight),
        ),
        locale: Locale(language.code),
      ),
      textDirection: language.rtl ? TextDirection.rtl : TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// The drill page's margins and the card's padding, both sides
  /// ([DrillFrame]).
  static const double _cardMargins = 2 * (16 + 20);
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
