import 'package:flutter/material.dart' hide Card;

import '../../core/models/card.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/ipa_line.dart';
import '../drill/teach_card.dart' show showPronunciation;

/// The small info dot that sits beside a card's IPA (owner, 2026-10-31: "The
/// IPA in the cards should always be a popup behind an infodot beside the IPA
/// notation. Casual learners don't care about it."). A tap opens the
/// pronunciation popup of [card]: each sound of its IPA, from the IPA course,
/// with its description, an example, a speaker and Practise
/// ([showPronunciation]). Nothing of that is drawn until the dot is tapped.
class IpaInfoDot extends StatelessWidget {
  const IpaInfoDot({super.key, required this.card});

  final Card card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: l10n.hintInfo,
      onPressed: () => showPronunciation(context, card),
      icon: const Icon(Icons.info_outline),
      iconSize: 20,
      // The icon stays small; the tap target is the 48 dp minimum.
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
    );
  }
}

/// [IpaLine] for [ipa] with the [IpaInfoDot] of [card] right beside it, the
/// two centred as a line.
class IpaWithInfo extends StatelessWidget {
  const IpaWithInfo(
    this.ipa, {
    super.key,
    required this.card,
    this.fontSize,
    this.textAlign = TextAlign.center,
  });

  final String ipa;
  final Card card;
  final double? fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Flexible(
        child: IpaLine(ipa, fontSize: fontSize, textAlign: textAlign),
      ),
      IpaInfoDot(card: card),
    ],
  );
}

/// A reading line that [swapped] to the IPA (#697, "IPA replaces
/// transliteration") with the [IpaInfoDot] of [card] beside it, as the IPA
/// has one everywhere else. Not swapped, [reading] is returned as it is.
class ReadingWithInfo extends StatelessWidget {
  const ReadingWithInfo({
    super.key,
    required this.reading,
    required this.card,
    required this.swapped,
  });

  final Widget reading;
  final Card card;
  final bool swapped;

  @override
  Widget build(BuildContext context) => swapped
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(child: reading),
            IpaInfoDot(card: card),
          ],
        )
      : reading;
}
