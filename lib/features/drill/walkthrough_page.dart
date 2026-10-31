import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart' show DeckEntry;
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/teach_swipe.dart';
import 'taught_details.dart' show TaughtReading;
import 'teach_card.dart';

/// What a Learn or Relearn asks for (#694): the cards of [deckIds], one deck
/// of a deck page or every deck of a unit page, in that order, or with [tags]
/// only those carrying one of them, as the deck page's tag chips had filtered
/// them when it was tapped. Every card, whatever is taught (owner,
/// 2026-10-31: "Should not really care about what has been learnt").
class WalkthroughRequest {
  const WalkthroughRequest({
    required this.deckIds,
    this.tags = const <String>{},
  });

  final List<String> deckIds;
  final Set<String> tags;
}

/// The card-by-card walkthrough (#694, ADR-0024, owner, 2026-10-31: "A:
/// Walkthrough replaces + Learn"): the cards of a deck, or of every deck of a
/// unit, one after another on the teach card, the learner going on by
/// swiping or with the chevrons, and back the same way. It is what Learn and
/// Relearn both open: the same walk from the first card, the label only
/// saying whether every card is taught.
///
/// Nothing is asked. The first view of a card not taught yet appends one
/// review-log row, graded 0 so that FSRS schedules it at the lowest window
/// ([AppState.viewCard]), a sentence still waiting included; a card seen
/// again, or already taught, writes nothing. The deck's name shows on each
/// card, so it changes where the walk crosses into the next deck. It ends
/// when the learner goes on from the last card, or closes it, the cards seen
/// so far kept as taught.
class WalkthroughPage extends StatefulWidget {
  const WalkthroughPage({super.key, required this.request});

  final WalkthroughRequest request;

  @override
  State<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends State<WalkthroughPage> {
  int _index = 0;
  bool _playing = false;

  /// The cards walked with the deck each is of, fixed when the walk starts.
  List<({Card card, DeckEntry entry})>? _cards;

  /// Records the first view of [card] (once the frame is built, since it
  /// notifies the screens that read progress).
  void _view(Card card) => AppScope.read(context).viewCard(card);

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
    final first = _cards == null;
    final cards = _cards ??= state.walkCards(<DeckEntry>[
      for (final id in widget.request.deckIds) ?state.deckById(id),
    ], tags: widget.request.tags);
    if (cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.style_outlined, title: l10n.deckNotFound),
      );
    }
    final index = _index.clamp(0, cards.length - 1);
    final card = cards[index].card;
    final entry = cards[index].entry;
    if (first) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _view(card);
      });
    }
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
                    _view(cards[index + 1].card);
                    setState(() => _index = index + 1);
                  }
                },
                onBack: index == 0
                    ? null
                    : () => setState(() => _index = index - 1),
                child: TeachCard(
                  card: card,
                  language: language,
                  deckName: entry.deck.name,
                  reading: expectsScript
                      ? TaughtReading.always
                      : TaughtReading.first,
                  audio: state.hasVoice(language)
                      ? Speaker(
                          onPlay: () => _play(card, language),
                          playing: _playing,
                          size: 56,
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
