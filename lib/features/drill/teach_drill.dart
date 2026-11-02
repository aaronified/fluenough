import 'package:flutter/material.dart';

import '../../app/skill.dart';
import '../../core/scheduling/ask.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/speaker.dart';
import 'drill_session.dart';
import 'going_on.dart';
import 'rule_card.dart';
import 'taught_details.dart' show TaughtReading;
import 'teach_card.dart';

/// A lesson teaching a rule (#417): the rule card, with the rule's name, its
/// explanation and its forms on words the learner knows, gone on from the
/// same way, with nothing recorded.
///
/// A lesson teaching a word (ADR-0024): the one-screen teach card (#691),
/// with the word played aloud as it shows where the phone has a voice and
/// sound is on.
///
/// Both are drawn in the shared shell (#509, phase 0): the header, a context
/// row whose pill is "New word · Recognition" or "Rule · Grammar" in the
/// skill's colour, one card, and no foot. The learner goes on by swiping or
/// tapping the chevron, and back to what was before; nothing is recorded.
///
/// Build one per card (key it by the card's position).
class TeachDrill extends StatelessWidget {
  const TeachDrill({super.key, required this.session, required this.onClose});

  final DrillSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = session.item.card;
    final rule = session.ask == Ask.teachRule;
    return DrillFrame(
      // The skill the card leads into gives the pill its colour (owner,
      // 2026-10-31, doubt 4): a word is Recognition, a rule Grammar.
      skill: rule ? Skill.grammar : Skill.recognition,
      pillLabel: rule
          ? l10n.ruleCardKind
          : card.pos == 'phrase'
          ? l10n.teachNewPhrase
          : l10n.teachNewWord,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      progress: session.progress,
      onClose: onClose,
      reportDetail: '${card.id} in ${session.deck.id}',
      fade: true,
      // No foot and no button: the chevrons show as the card is swiped,
      // as they always have on a teach card.
      going: goingOn(
        session,
        answered: true,
        onNext: session.learnt,
        pinned: false,
      ),
      card: <Widget>[
        if (rule)
          RuleCard(card: card, language: session.deck.language, inShell: true)
        else
          TeachCard(
            card: card,
            language: session.deck.language,
            inShell: true,
            // Reading first until the script is expected of the learner;
            // else under the word, whatever Latin-letter readings says.
            reading: session.expectsScript
                ? TaughtReading.always
                : TaughtReading.first,
            // Played as it shows, whatever Play words automatically says.
            audio: session.canPlay
                ? Speaker(
                    onPlay: session.play,
                    playing: session.playing,
                    size: 56,
                    playOnAppear: true,
                  )
                : null,
          ),
      ],
    );
  }
}
