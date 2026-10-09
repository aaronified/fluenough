import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/speaker.dart';

/// The top line of a card's sheet, as the designs draw it: [text], such as
/// "te-0384 · noun · Learning 58%", then a speaker that says the word, and
/// the bug icon that reports the card as [report].
///
/// The speaker shows only where the phone has a voice for [language], as on
/// the drill cards; with sound off in Settings it is greyed out and a tap
/// says so ([SpeakerActions]).
class CardTopLine extends StatelessWidget {
  const CardTopLine({
    super.key,
    required this.text,
    required this.card,
    required this.language,
    required this.report,
  });

  final String text;
  final Card card;
  final LanguageInfo language;

  /// What the bug icon's report names: the card's id, or more.
  final String report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (state.hasVoice(language))
          SpeakerIcon(
            onPlay: () => state.speak(card.target, language),
            label: l10n.drillPlay,
          ),
        ReportButton(detail: report),
      ],
    );
  }
}
