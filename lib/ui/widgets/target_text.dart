import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/aksharas.dart';
import '../../core/models/card.dart';
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
    this.card,
  }) : _sizing = _Sizing.fixed;

  /// The big text on a drill card, sized by its length and the card scale.
  const TargetText.hero(
    this.text, {
    super.key,
    required this.language,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.textAlign = TextAlign.center,
    this.card,
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
    this.card,
  }) : _sizing = _Sizing.card;

  /// [text] as it is, in [language]: a spelling of a card, shown beneath.
  const TargetText._raw(
    this.text,
    this.language,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this._sizing,
  ) : card = null;

  final String text;
  final LanguageInfo language;

  /// Null only for [TargetText.hero], which works it out. For
  /// [TargetText.card], the size at a scale of 1.
  final double? fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final TextAlign textAlign;
  final _Sizing _sizing;

  /// The card [text] is the target of, where it should be shown in the
  /// script the learner learns (#623): the card's spelling in it, drawn in
  /// its direction, and with both scripts learned the other beneath,
  /// smaller. Null shows [text] as given.
  final Card? card;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    if (card == null) return _build(context);
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final shown = state.targetShown(card, language);
        final main = shown.text == text
            ? _build(context)
            : TargetText._raw(
                shown.text,
                shown.language,
                fontSize,
                fontWeight,
                color,
                textAlign,
                _sizing,
              )._build(context);
        final others = state.otherSpellings(card, language);
        if (others.isEmpty) return main;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            main,
            for (final other in others)
              TargetText._raw(
                other.text,
                other.language,
                _sizing == _Sizing.hero ? 28 : (fontSize ?? 28) * 0.6,
                fontWeight,
                color,
                textAlign,
                _sizing == _Sizing.hero ? _Sizing.card : _sizing,
              )._build(context),
          ],
        );
      },
    );
  }

  Widget _build(BuildContext context) {
    if (_sizing == _Sizing.fixed) return _text(context, fontSize!);
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
        );
      },
    );
  }

  Widget _text(BuildContext context, double base) {
    var size = base;
    var shown = text;
    if (_sizing != _Sizing.fixed && _isOneWord) {
      final room = MediaQuery.sizeOf(context).width - _cardMargins;
      final width = _width(context, size);
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
      locale: targetLocale(language),
      style: TextStyle(
        fontSize: size,
        fontWeight: fontWeight,
        color: color,
        height: language.rtl ? TargetSizes.rtlHeight : TargetSizes.ltrHeight,
      ),
    );
  }

  /// Whether [text] is one word: a longer text breaks between its words.
  bool get _isOneWord => !text.contains(RegExp(r'\s'));

  /// How wide [text] is on one line at [size], scaled as the screen scales
  /// text.
  double _width(BuildContext context, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, fontWeight: fontWeight),
        locale: targetLocale(language),
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

/// The locale [language]'s text is drawn and read in: its own code, except
/// that text in the Perso-Arabic script of Urdu (Hindustani's second script,
/// and Punjabi's Shahmukhi) is marked Urdu, so that the phone draws it in its
/// Nastaliq font rather than the plain Naskh it uses for Arabic.
Locale targetLocale(LanguageInfo language) => switch (language.script) {
  'perso_arabic' || 'shahmukhi' => const Locale('ur'),
  _ => Locale(language.code),
};

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
  final locale = targetLocale(language);
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
