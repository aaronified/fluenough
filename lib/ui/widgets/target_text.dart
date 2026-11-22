import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/decks/font_check.dart';
import '../../core/decks/script_fonts.dart';
import '../../core/models/aksharas.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../card_text_scale.dart';
import '../theme.dart';
import 'drill_frame.dart';
import 'sign_image.dart';

/// Deck content in the deck's language: a card's target, a lemma, a leech.
///
/// Every piece of target-language text goes through this, because it gets
/// three things right in one place:
///
/// - **Direction** from the deck ([LanguageInfo.rightToLeft]), not from the
///   interface language: an Urdu card is right to left in an English app,
///   and so is Hindustani in its Perso-Arabic script.
/// - **Locale** from the deck's language code, so a character shared between
///   scripts takes the right regional form.
/// - **Line height** of 1.9 for right-to-left scripts, whose Nastaliq forms
///   climb and descend far more than Latin, shared evenly above and below
///   so that the glyphs sit in the middle of their line (#762), and 1.25
///   otherwise.
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
    this.card,
    this.scripts,
    this.semanticLabel,
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
    this.scripts,
    this.semanticLabel,
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
    this.scripts,
    this.semanticLabel,
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
  ) : card = null,
      scripts = null,
      semanticLabel = null;

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

  /// The scripts to show [card] in where they are chosen but not saved yet,
  /// as placement's are (#650); null for those the learner learns.
  final Set<String>? scripts;

  /// What a screen reader says of a sign card's picture ([Card.isSign]):
  /// its meaning where that is on screen already, else "Sign".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    // A sign (ADR-0056) is its picture, big as a drill's target and in
    // proportion to the text elsewhere; its FSW text is never drawn, even
    // where no card is given.
    if (card != null && card.isSign) return _sign(context, card);
    if (isFswText(text)) return const SizedBox.shrink();
    if (card == null) return _build(context);
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[
        state.settings,
        state.deckDownloads?.fonts,
      ]),
      builder: (context, _) {
        var shown = state.targetShown(card, language, scripts: scripts);
        // Glyphs with no font on the phone are boxes: until the font is
        // downloaded the card shows its spelling in another script.
        if (_boxed(state, shown.language)) {
          for (final script in language.allScripts) {
            final other = card.targetIn(script, firstScript: language.script);
            if (other != null &&
                !privateUseScripts.contains(script) &&
                script != shown.language.script) {
              shown = (text: other, language: language.inScript(script));
              break;
            }
          }
        }
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
        final others = <({String text, LanguageInfo language})>[
          for (final other in state.otherSpellings(
            card,
            language,
            scripts: scripts,
          ))
            if (other.language.script != shown.language.script &&
                !_boxed(state, other.language))
              other,
        ];
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

  Widget _sign(BuildContext context, Card card) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
    child: SignImage(
      card,
      semanticLabel: semanticLabel,
      size: _sizing == _Sizing.hero
          ? signHeroSize(context)
          : ((fontSize ?? 28) * 3).clamp(56.0, 140.0).toDouble(),
    ),
  );

  Widget _build(BuildContext context) {
    // Not AppScope.of: a plain TargetText never needed the scope, and the
    // script fonts notify on their own.
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    final fonts = scope?.notifier?.deckDownloads?.fonts;
    // Braille is always drawn in its own shadow-dot font, which ships with
    // the app (#835): never the phone's.
    if (language.isBraille) return _sized(context, brailleFontFamily, null);
    if (fonts == null) return _sized(context, null, null);
    final state = scope?.notifier;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[fonts, state?.settings]),
      builder: (context, _) {
        final family = fonts.familyFor(
          fontScriptFor(language.code, language.script),
        );
        // Private-use glyphs without their font are boxes: a mark stands in
        // until it is downloaded.
        if (state != null && _boxed(state, language)) {
          return TargetText._raw(
            _missing,
            language.inScript('latin'),
            fontSize,
            fontWeight,
            color,
            textAlign,
            _sizing,
          )._build(context);
        }
        return _sized(context, family, fonts.fallbackFor(family));
      },
    );
  }

  /// What stands in for text whose script's font is not downloaded yet.
  static const String _missing = '\u2026';

  /// Whether [language]'s text would be drawn as boxes: it is in a
  /// private-use script, its font is not loaded, and the learner has not said
  /// the phone's own font draws it.
  static bool _boxed(AppState state, LanguageInfo language) {
    final script = fontScriptFor(language.code, language.script);
    if (!privateUseScripts.contains(script)) return false;
    if (state.deckDownloads?.fonts.familyFor(script) != null) return false;
    return state.settings.fontChoice(script) != FontChoice.phone;
  }

  /// The text at its size, in [family], the script's downloaded font, or
  /// the phone's own when it is null, with the other content fonts behind it
  /// in [fallback] (Latin letters in a Cyrillic or Devanagari card, say), so
  /// that no character of a card falls to the phone's font.
  Widget _sized(BuildContext context, String? family, List<String>? fallback) {
    if (_sizing == _Sizing.fixed) {
      return _text(context, fontSize!, family, fallback);
    }
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
          fallback,
        );
      },
    );
  }

  Widget _text(
    BuildContext context,
    double base,
    String? family,
    List<String>? fallback,
  ) {
    var size = base;
    var shown = text;
    if (_sizing != _Sizing.fixed && _isOneWord) {
      final room = MediaQuery.sizeOf(context).width - _cardMargins;
      final width = _width(context, size, family, fallback);
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
      textDirection: language.rightToLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
      locale: targetLocale(language),
      style: TextStyle(
        fontSize: size,
        fontWeight: _styleWeight(family, fontWeight),
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontVariations: _variations(family, fontWeight),
        color: color,
        height: language.rightToLeft
            ? TargetSizes.rtlHeight
            : TargetSizes.ltrHeight,
        leadingDistribution: language.rightToLeft
            ? TextLeadingDistribution.even
            : null,
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
  double _width(
    BuildContext context,
    double size,
    String? family,
    List<String>? fallback,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: _styleWeight(family, fontWeight),
          fontFamily: family,
          fontFamilyFallback: fallback,
          fontVariations: _variations(family, fontWeight),
        ),
        locale: targetLocale(language),
      ),
      textDirection: language.rightToLeft
          ? TextDirection.rtl
          : TextDirection.ltr,
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
///
/// Persian, Pashto, Sindhi and Kashmiri are set in Naskh, and keep their own
/// locale.
Locale targetLocale(LanguageInfo language) => switch (language.script) {
  'perso_arabic' || 'shahmukhi'
      when fontScriptFor(language.code, language.script) == 'perso_arabic' =>
    const Locale('ur'),
  _ => Locale(language.code),
};

/// The style of a quoted piece of [language]'s deck text inside an interface
/// string (owner, 2026-11-16: "I don't want to depend on system fonts for
/// content"): the script's downloaded font first, by its family name, which
/// needs no lookup of what is loaded, as a family that is not loaded is
/// skipped; then Roboto, the braille font and the content fonts, so that
/// the quote falls back as before and never to the phone's font. The text
/// around the quote has no such style and stays in the interface's Roboto.
TextStyle targetQuoteStyle(LanguageInfo language) => TextStyle(
  fontFamily: language.isBraille
      ? brailleFontFamily
      : scriptFontFamily(fontScriptFor(language.code, language.script)),
  fontFamilyFallback: <String>[
    interfaceFontFamily,
    brailleFontFamily,
    for (final script in contentFontScripts) scriptFontFamily(script),
  ],
);

/// Right-to-left isolate and pop directional isolate (Unicode bidi).
const String _rli = '\u2067';
const String _pdi = '\u2069';

/// [text], an interface string that quotes deck content, with each of
/// [quotes] in it marked as [language]'s: drawn in its font and read by a
/// screen reader in its voice, while the rest stays the interface's (#26).
/// "Answer: el niño" is read in English up to the colon and in Spanish after.
/// A quote is drawn in its script's downloaded font ([targetQuoteStyle]).
///
/// A quote in a right-to-left language is wrapped in a bidi isolate (#619),
/// so that the interface's words around it never reorder it, nor it them:
/// a trailing full stop stays at the end of the sentence, not beside the
/// quote's last letter. Left-to-right quotes in the left-to-right interface
/// need none.
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
  final style = targetQuoteStyle(language);
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
    spans.add(
      TextSpan(
        text: language.rtl ? '$_rli$found$_pdi' : found,
        locale: locale,
        style: style,
      ),
    );
    start = at + found.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return TextSpan(children: spans);
}
