import 'package:flutter/material.dart';

import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/teach_swipe.dart';
import 'drill_session.dart';
import 'taught_details.dart' show TaughtReading;
import 'teach_card.dart';

/// A lesson teaching a word (ADR-0024): the one-screen teach card (#691),
/// with the word played aloud as it shows where the phone has a voice and
/// sound is on. The learner goes on to the word's first question by swiping
/// the card or tapping the chevron; there is no Continue button, and nothing
/// is recorded. A lesson teaches each word once, so there is no way back.
///
/// Build one per card (key it by the card's position).
class TeachDrill extends StatelessWidget {
  const TeachDrill({super.key, required this.session, required this.onClose});

  final DrillSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final card = session.item.card;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DrillHeader(
              progress: session.progress,
              position: session.position,
              total: session.total,
              onClose: onClose,
              reportDetail: '${card.id} in ${session.deck.id}',
            ),
            Expanded(
              child: TeachSwipe(
                onNext: session.learnt,
                child: TeachCard(
                  card: card,
                  language: session.deck.language,
                  // Reading first until the script is expected of the
                  // learner; else under the word, whatever Latin-letter
                  // readings says.
                  reading: session.expectsScript
                      ? TaughtReading.always
                      : TaughtReading.first,
                  // Played as it shows, whatever Play words automatically
                  // says.
                  audio: session.canPlay
                      ? Speaker(
                          onPlay: session.play,
                          playing: session.playing,
                          size: 48,
                          playOnAppear: true,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
