import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';

/// How a word is said, in the IPA (ADR-0025): `/paːlu/`, muted, under the
/// word or its answer, as the word sheet shows it. IPA pronunciations in Settings
/// switches it; see [ipaToShow].
///
/// The IPA is always left to right, whatever the deck's language, and is
/// drawn in the interface's own font, not the deck's, with Roboto and Noto
/// Sans behind it for the IPA Extensions block. Screen readers hear "In the
/// IPA: paːlu".
class IpaLine extends StatelessWidget {
  const IpaLine(
    this.ipa, {
    super.key,
    this.fontSize,
    this.textAlign = TextAlign.center,
  });

  /// As the deck gives it: broad, without the slashes.
  final String ipa;

  /// Null for the theme's `bodyMedium`.
  final double? fontSize;

  final TextAlign textAlign;

  /// Fonts that cover the IPA, tried where the theme's font has no glyph.
  static const List<String> fontFallback = <String>['Roboto', 'Noto Sans'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Semantics(
      label: l10n.ipaSemantics(ipa),
      excludeSemantics: true,
      child: Text(
        l10n.wordSheetIpa(ipa),
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
        style: theme.textTheme.bodyMedium!.copyWith(
          fontSize: fontSize,
          color: theme.colorScheme.onSurfaceVariant,
          fontFamilyFallback: fontFallback,
        ),
      ),
    );
  }
}

/// The two lines a word shows, [reading] (the transliteration) and [ipa]
/// (#697). Normally the reading as it is, if [showReading], and the IPA line
/// [ipaToShow] decides. With IPA on and "IPA replaces transliteration" on, a
/// word with an IPA shows it in the reading's place, as `/paːlu/`, and the
/// small IPA line goes: the transliteration is not shown. A word with no IPA
/// keeps its reading as before. `swapped` says the reading is the IPA, to be drawn with [IpaSwapStyle.forIpa]. Latin-script words (no reading) get their
/// IPA in the reading's place too.
({String? reading, String? ipa, bool swapped}) readingLines(
  BuildContext context, {
  String? reading,
  String? ipa,
  String? target,
  bool showReading = true,
}) {
  final shown = ipaToShow(context, ipa, target: target);
  if (shown != null && AppScope.read(context).settings.ipaReplacesReading) {
    return (
      reading: AppLocalizations.of(context)!.wordSheetIpa(shown),
      ipa: null,
      swapped: true,
    );
  }
  return (reading: showReading ? reading : null, ipa: shown, swapped: false);
}

/// Text styles for a line [readingLines] may have swapped the IPA into: the
/// IPA's fonts are tried behind the theme's where the glyph is missing, as
/// [IpaLine] does.
extension IpaSwapStyle on TextStyle {
  TextStyle forIpa(bool swapped) =>
      swapped ? copyWith(fontFamilyFallback: IpaLine.fontFallback) : this;
}

/// A reading line. When [swapped] says [readingLines] put the IPA in the
/// reading's place, it is drawn as [IpaLine] draws the IPA: left to right,
/// in the IPA's fonts, and a screen reader hears "In the IPA: paːlu", not the
/// slashes. Otherwise it is a plain [Text] in [style].
class ReadingText extends StatelessWidget {
  const ReadingText(
    this.text, {
    super.key,
    required this.swapped,
    this.style,
    this.textAlign,
  });

  final String text;
  final bool swapped;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    if (!swapped) return Text(text, style: style, textAlign: textAlign);
    final l10n = AppLocalizations.of(context)!;
    // `/paːlu/` is how wordSheetIpa writes it; the label has no slashes. A
    // prompt with the IPA among other words keeps the rest as it is.
    final plain = text.replaceFirstMapped(RegExp(r'/([^/]+)/'), (m) => m[1]!);
    return Semantics(
      label: l10n.ipaSemantics(plain),
      excludeSemantics: true,
      child: Text(
        text,
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
        style: (style ?? const TextStyle()).forIpa(true),
      ),
    );
  }
}

/// [ipa], if it is to be shown: the deck gives one, it is not just [target]
/// again (a card written in the IPA itself), and IPA pronunciations is on. Null
/// otherwise, so that no line is left for it.
///
/// Reads the setting without listening to it: a screen that shows the IPA
/// listens to the settings, or is built again when they change.
String? ipaToShow(BuildContext context, String? ipa, {String? target}) {
  if (ipa == null || ipa.trim().isEmpty || ipa == target) return null;
  return AppScope.read(context).settings.showIpa ? ipa : null;
}

/// A reading and its IPA, one under the other, as [readingLines] decides
/// (#697): for the places that list the two beside a word, start aligned.
class ReadingIpaLines extends StatelessWidget {
  const ReadingIpaLines({
    super.key,
    required this.style,
    this.reading,
    this.ipa,
    this.target,
    this.showReading = true,
  });

  final String? reading;
  final String? ipa;
  final String? target;
  final bool showReading;

  /// The reading's style; the IPA's fonts are added when it shows the IPA.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lines = readingLines(
      context,
      reading: reading,
      ipa: ipa,
      target: target,
      showReading: showReading,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (lines.reading case final text?)
          ReadingText(text, swapped: lines.swapped, style: style),
        if (lines.ipa case final shown?)
          IpaLine(shown, textAlign: TextAlign.start),
      ],
    );
  }
}
