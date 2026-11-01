import 'package:flutter/material.dart' hide Card;

import '../../app/settings.dart';
import '../../core/scheduling/ask.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/ipa_line.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';
import 'picture_tile.dart';
import 'set_drill.dart';
import 'taught_details.dart';
import '../decks/ipa_info_dot.dart';

/// Picture choice (#91, owner 2026-10-30: "A form of Recognition"): the word,
/// shown ([Ask.choosePicture]) or played ([Ask.hearPicture]), and its picture
/// to choose among four of the same deck's, two by two. It records Recognition
/// as soon as one is picked, as the meaning choice does, so it has no schedule
/// of its own. The pictures carry no words until it is answered, so a screen
/// reader hears "Picture 1 of 4" and not the answer ([PictureTile]); then each
/// shows its meaning, and the word's details show as they do after any choice.
/// Build one per card (key it by the card's position).
class PictureChoiceDrill extends StatelessWidget {
  const PictureChoiceDrill({
    super.key,
    required this.session,
    required this.onClose,
  });

  final DrillSession session;
  final VoidCallback onClose;

  bool get _hears => session.ask == Ask.hearPicture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = session.item.card;
    final picked = session.picked;
    final answered = picked != null;
    final right = picked != null && session.isRight(picked);
    final options = session.options;

    Widget tile(int place) => Expanded(
      child: place < options.length
          ? PictureTile(
              card: options[place],
              number: place + 1,
              total: options.length,
              right: answered && session.isRight(options[place]),
              chosen: picked?.id == options[place].id,
              answered: answered,
              onTap: () => session.pick(options[place]),
            )
          : const SizedBox.shrink(),
    );

    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      reportDetail: '${card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: onClose,
      needsSound: _hears && !answered,
      card: <Widget>[
        ...(_hears
            ? _heardCard(context, answered)
            : _wordCard(context, answered)),
        ...answeredSetList(context, session, answered: answered),
      ],
      belowCard: <Widget>[
        Semantics(
          container: true,
          label: l10n.drillOptionsGroup,
          child: Column(
            children: <Widget>[
              for (var row = 0; row < options.length; row += 2) ...<Widget>[
                if (row > 0) const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      tile(row),
                      const SizedBox(width: 12),
                      tile(row + 1),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      feedback: !answered
          ? null
          : right
          ? FeedbackBanner(
              kind: FeedbackKind.correct,
              title: l10n.feedbackCorrect,
            )
          : FeedbackBanner(
              kind: FeedbackKind.wrong,
              title: l10n.feedbackWrong,
              detail: l10n.feedbackAnswer(card.native),
            ),
      actions: answered
          ? <Widget>[
              FilledButton(
                onPressed: session.next,
                style: AppButtonStyles.tall(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(child: Text(l10n.commonContinue)),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward, size: 22),
                  ],
                ),
              ),
            ]
          : const <Widget>[],
    );
  }

  /// The word, as recognition shows it, with its speaker from the start; once
  /// answered, what its lesson showed under it.
  List<Widget> _wordCard(BuildContext context, bool answered) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = session.item.card;
    final language = session.deck.language;
    final lines = readingLines(
      context,
      reading: card.reading,
      ipa: card.ipa,
      target: card.target,
    );
    final reading = lines.reading;
    return <Widget>[
      Text(
        l10n.drillChoosePicture,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      if (reading != null && session.readsFirst)
        ReadingFirst(
          reading: reading,
          target: card.target,
          language: language,
          fontSize: 48,
          ipaFont: lines.swapped,
          readingWrapper: (r) =>
              ReadingWithInfo(reading: r, card: card, swapped: lines.swapped),
        )
      else ...<Widget>[
        TargetText.hero(card.target, language: language, card: card),
        if (reading != null)
          ReadingWithInfo(
            swapped: lines.swapped,
            card: card,
            reading: Text(
              reading,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!
                  .copyWith(fontSize: 18, color: scheme.onSurfaceVariant)
                  .forIpa(lines.swapped),
            ),
          ),
      ],
      // How it is said: the word is shown, so this gives nothing away.
      if (lines.ipa case final ipa?) IpaWithInfo(ipa, card: card, fontSize: 16),
      if (session.canPlay)
        Speaker(
          key: const ValueKey<String>('speaker'),
          onPlay: session.play,
          playing: session.playing,
        ),
      if (answered)
        TaughtDetails(
          card: card,
          language: language,
          reading: TaughtReading.inReview(session),
          word: false,
        ),
    ];
  }

  /// The play button and Slower; once answered, the word and its details.
  List<Widget> _heardCard(BuildContext context, bool answered) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slower = session.slower;
    return <Widget>[
      Speaker(onPlay: session.play, playing: session.playing, size: 136),
      Text(
        l10n.drillChooseHeardPicture,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      FilterChip(
        label: Text(l10n.drillSlower(SettingsNotifier.slowerFactor)),
        selected: slower,
        onSelected: (_) => session.toggleSlower(),
        showCheckmark: false,
        shape: const StadiumBorder(),
        side: slower
            ? BorderSide(color: scheme.secondaryContainer)
            : BorderSide(color: scheme.outline),
        labelStyle: theme.textTheme.labelLarge!.copyWith(
          fontWeight: FontWeight.w600,
          color: slower ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
        ),
      ),
      if (answered)
        TaughtDetails(
          card: session.item.card,
          language: session.deck.language,
          reading: TaughtReading.inReview(session),
          wordSize: 28,
          wordColor: scheme.primary,
        ),
    ];
  }
}
