import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/reviewing.dart';
import '../../core/review/deck_review.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';

/// Opens the send sheet: every deck with reviews not sent yet, all ticked,
/// sent together in one mail (docs/plans/deck-browser.md). Says so, and
/// says nothing is waiting when nothing is.
Future<void> showSendReviews(BuildContext context) {
  final state = AppScope.read(context);
  if (state.reviewing.unsent.isEmpty) {
    showAppSnackBar(context, AppLocalizations.of(context)!.reviewSendNothing);
    return Future<void>.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const SendReviewsSheet(),
  );
}

/// The deck's name and language, or its id and language code once the deck
/// is gone from the phone.
(String, String) _named(AppState state, DeckReview deck) {
  final entry = state.deckById(deck.deckId);
  return entry == null
      ? (deck.deckId, deck.language)
      : (entry.deck.name, entry.language.name);
}

/// The mail's body, for people only: the files are the record.
String reviewMailBody(
  AppLocalizations l10n,
  AppState state,
  List<DeckReview> decks,
) {
  final lines = <String>[
    for (final deck in decks)
      deck.unsentSignOff
          ? l10n.reviewMailDeckSigned(
              _named(state, deck).$1,
              deck.deckId,
              deck.unsentCards.length,
            )
          : l10n.reviewMailDeck(
              _named(state, deck).$1,
              deck.deckId,
              deck.unsentCards.length,
            ),
  ];
  return l10n.reviewMailBody(
    AppInfo.version,
    '${state.reviewing.code}',
    lines.join('\n'),
  );
}

/// Every deck with unsent reviews, each with a tick, how many card reviews
/// it sends and whether it is signed off; one button sends the ticked ones
/// in one mail, a file for each.
class SendReviewsSheet extends StatefulWidget {
  const SendReviewsSheet({super.key});

  @override
  State<SendReviewsSheet> createState() => _SendReviewsSheetState();
}

class _SendReviewsSheetState extends State<SendReviewsSheet> {
  /// The decks left unticked, by id. Every deck starts ticked.
  final Set<String> _unticked = <String>{};
  bool _sending = false;

  Future<void> _send(List<DeckReview> chosen) async {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    setState(() => _sending = true);
    final outcome = await state.reviewing.send(
      chosen,
      body: reviewMailBody(l10n, state, chosen),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    final message = switch (outcome) {
      ReviewSendOutcome.inMailApp => l10n.reviewSendOpened,
      ReviewSendOutcome.nothingToSend => l10n.reviewSendNothing,
      ReviewSendOutcome.noMailApp => l10n.reviewSendNoApp,
      ReviewSendOutcome.failed => l10n.reviewSendFailed,
    };
    if (outcome == ReviewSendOutcome.inMailApp) Navigator.of(context).pop();
    showAppSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final unsent = state.reviewing.unsent;
        final chosen = <DeckReview>[
          for (final deck in unsent)
            if (!_unticked.contains(deck.deckId)) deck,
        ];
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.reviewSendTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 8,
                        children: <Widget>[
                          Text(
                            l10n.reviewSendBody,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            l10n.reviewSendSame,
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final deck in unsent)
                      CheckboxListTile(
                        value: !_unticked.contains(deck.deckId),
                        onChanged: _sending
                            ? null
                            : (on) => setState(
                                () => on == true
                                    ? _unticked.remove(deck.deckId)
                                    : _unticked.add(deck.deckId),
                              ),
                        title: Text(
                          l10n.reviewSendDeck(
                            _named(state, deck).$1,
                            _named(state, deck).$2,
                          ),
                        ),
                        subtitle: Text(
                          deck.unsentSignOff
                              ? l10n.reviewSendDeckSigned(
                                  deck.unsentCards.length,
                                )
                              : l10n.reviewSendDeckCount(
                                  deck.unsentCards.length,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppSizes.primaryButton,
                      ),
                    ),
                    onPressed: chosen.isEmpty || _sending
                        ? null
                        : () => _send(chosen),
                    icon: const Icon(Icons.send_outlined, size: 20),
                    label: Text(l10n.reviewSendButton(chosen.length)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
