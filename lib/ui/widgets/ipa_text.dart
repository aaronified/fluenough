import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';

/// How a word is said, in the IPA (ADR-0025): `/paːlu/`, muted, under the
/// word or with its answer. Show IPA in Settings switches it; see
/// [ipaToShow].
///
/// The IPA is always left to right and in Latin-based letters, whatever the
/// deck's language, so it is drawn in the interface's own sans-serif, not in
/// the deck's locale, whose font may lack the IPA Extensions block. Roboto,
/// Android's, has it, and Noto Sans is the fallback; no font is bundled for
/// it. Screen readers hear "In the IPA: paːlu".
class IpaText extends StatelessWidget {
  const IpaText(
    this.ipa, {
    super.key,
    this.fontSize = 16,
    this.color,
    this.textAlign = TextAlign.center,
  });

  /// As the deck gives it: broad, without the slashes.
  final String ipa;

  final double fontSize;

  /// The text's colour; `onSurfaceVariant` by default.
  final Color? color;

  final TextAlign textAlign;

  /// Fonts that cover the IPA, tried where the theme's font has no glyph.
  static const List<String> fontFallback = <String>['Roboto', 'Noto Sans'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: AppLocalizations.of(context)!.ipaSemantics(ipa),
      excludeSemantics: true,
      child: Text(
        '/$ipa/', // ui-literal-ok: the IPA's slashes are notation, not language
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
        style: theme.textTheme.bodyLarge!.copyWith(
          fontSize: fontSize,
          height: 1.3,
          color: color ?? theme.colorScheme.onSurfaceVariant,
          fontFamilyFallback: fontFallback,
        ),
      ),
    );
  }
}

/// [ipa], if it is to be shown: the deck gives one, it is not just
/// [target] again (a card in the IPA itself), and Show IPA is on. Null
/// otherwise, so that no line is left for it.
///
/// Reads the setting without listening to it: a screen that shows the IPA
/// listens to the settings, or is built again when they change.
String? ipaToShow(BuildContext context, String? ipa, {String? target}) {
  if (ipa == null || ipa.trim().isEmpty || ipa == target) return null;
  return AppScope.read(context).settings.showIpa ? ipa : null;
}
