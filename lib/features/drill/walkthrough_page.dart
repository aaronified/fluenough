import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/teach_swipe.dart';
import 'taught_details.dart' show TaughtReading;
import 'teach_card.dart';

/// What a deck page's Relearn asks for (#693, #694): the cards of [deckId],
/// or with [tags] only those carrying one of them, as the page's tag chips
/// had filtered them when it was tapped.
class WalkthroughRequest {
  const WalkthroughRequest({
    required this.deckId,
    this.tags = const <String>{},
  });

  final String deckId;
  final Set<String> tags;
}

/// Relearn (#694, owner, 2026-10-23: "Relearn only appears when all cards in
/// the deck are taught. It runs through all the cards (if deck is filtered,
/// then the filtered cards only)"): the deck's cards one after another on the
/// teach card, the learner going on by swiping or with the chevrons, and
/// back the same way.
///
/// Every card is taught already, so nothing is asked and nothing is written:
/// no answer, no schedule, no log. It ends when the learner goes on from the
/// last card, or closes it.
class WalkthroughPage extends StatefulWidget {
  const WalkthroughPage({super.key, required this.request});

  final WalkthroughRequest request;

  @override
  State<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends State<WalkthroughPage> {
  int _index = 0;
  bool _playing = false;

  Future<void> _play(Card card, LanguageInfo language) async {
    final state = AppScope.read(context);
    setState(() => _playing = true);
    try {
      await state.speakCard(card, language);
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final entry = state.deckById(widget.request.deckId);
    final tags = widget.request.tags;
    final cards = <Card>[
      if (entry != null && entry.deck.kind != DeckKind.reading)
        for (final card in entry.cards)
          if (tags.isEmpty || card.tags.any(tags.contains)) card,
    ];
    if (entry == null || cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.style_outlined, title: l10n.deckNotFound),
      );
    }
    final index = _index.clamp(0, cards.length - 1);
    final card = cards[index];
    final language = entry.language;
    final expectsScript =
        state.settings.learnsAlphabet(language.code) &&
        state.scriptLearned(language.code);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DrillHeader(
              progress: (index + 1) / cards.length,
              position: index + 1,
              total: cards.length,
              onClose: () => Navigator.of(context).maybePop(),
              reportDetail: '${card.id} in ${entry.id}',
            ),
            Expanded(
              child: TeachSwipe(
                // One swipe's state for each card.
                key: ValueKey<String>(card.id),
                onNext: () {
                  if (index + 1 >= cards.length) {
                    Navigator.of(context).maybePop();
                  } else {
                    setState(() => _index = index + 1);
                  }
                },
                onBack: index == 0
                    ? null
                    : () => setState(() => _index = index - 1),
                child: TeachCard(
                  card: card,
                  language: language,
                  reading: expectsScript
                      ? TaughtReading.always
                      : TaughtReading.first,
                  audio: state.hasVoice(language)
                      ? Speaker(
                          onPlay: () => _play(card, language),
                          playing: _playing,
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
