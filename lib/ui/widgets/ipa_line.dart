import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/app_localizations.dart';

/// How a word is said, in the IPA (ADR-0025): `/paːlu/`, muted, under the
/// word or its answer, as the word sheet shows it. Show IPA in Settings
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

/// [ipa], if it is to be shown: the deck gives one, it is not just [target]
/// again (a card written in the IPA itself), and Show IPA is on. Null
/// otherwise, so that no line is left for it.
///
/// Reads the setting without listening to it: a screen that shows the IPA
/// listens to the settings, or is built again when they change.
String? ipaToShow(BuildContext context, String? ipa, {String? target}) {
  if (ipa == null || ipa.trim().isEmpty || ipa == target) return null;
  return AppScope.read(context).settings.showIpa ? ipa : null;
}
