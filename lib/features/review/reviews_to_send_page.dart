import 'package:flutter/material.dart' hide Card;

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/reviewing.dart';
import '../../app/routes.dart';
import '../../core/models/card.dart';
import '../../core/review/deck_review.dart';
import '../../core/review/facets.dart';
import '../../core/review/question_log.dart';
import '../../core/review/review_question.dart';
import '../../core/review/sent_mail.dart';
import '../../core/review/sent_state.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/bottom_actions.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/path_parts.dart' show joinParts;
import 'daily_questions_page.dart' show reasonLabel;
import 'facet_labels.dart';
import 'review_sheets.dart' show partName, suggestionPartName;
import 'review_waiting.dart';
import 'suggestion_lines.dart' show yoursOf;

/// The mail's body, for people only: the files are the record. [decks] are
/// what the mail carries (their unsent cards), [answers] how many daily
/// question answers go with them.
String reviewMailBody(
  AppLocalizations l10n,
  AppState state,
  List<DeckReview> decks, {
  int answers = 0,
}) {
  String name(DeckReview deck) =>
      state.reviewDeckById(deck.deckId)?.deck.name ?? deck.deckId;
  final lines = <String>[
    for (final deck in decks)
      deck.unsentSignOff
          ? l10n.reviewMailDeckSigned(
              name(deck),
              deck.deckId,
              deck.unsentCards.length,
            )
          : l10n.reviewMailDeck(
              name(deck),
              deck.deckId,
              deck.unsentCards.length,
            ),
    // The daily questions' answers go in the same mail (#519).
    if (answers > 0) l10n.reviewMailAnswers(answers),
  ];
  return l10n.reviewMailBody(
    AppInfo.version,
    '${state.reviewing.code}',
    lines.join('\n'),
  );
}

/// The decks of [mail] whose changes the deck data shows: a suggestion of
/// the mail sits in the deck as a proposal other reviewers see, or has been
/// decided ([changesAcknowledged]). [sent] is [sentSuggestionsOf]; only the
/// reviews made by the time of the mail count for it, so a mail is judged
/// by what it carried and never by a later one's.
Set<String> acknowledgedDecks(SentMail mail, List<SentSuggestion> sent) =>
    <String>{
      for (final id in mail.decks.keys)
        if (changesAcknowledged(<SentState>[
          for (final s in sent)
            if (s.review.deckId == id && _madeBy(s, mail)) s.state,
        ]))
          id,
    };

bool _madeBy(SentSuggestion s, SentMail mail) {
  final at = s.review.cards[s.cardId]?.at;
  return at != null && !at.isAfter(mail.at);
}

/// "Reviews to send" (owner, 2026-11-22):
/// the one home for sending reviews. Every deck with reviews not sent is a
/// tickable group that opens to every item it will send, with the daily
/// questions' answers as one group per language and one Send button for what
/// is ticked. Below, Sent lists the mails the phone opened the mail app for,
/// by date, each with Send again while the deck data does not show its
/// changes ([acknowledgedDecks]). The phone cannot tell whether a mail went:
/// it only knows the mail app opened.
class ReviewsToSendPage extends StatefulWidget {
  const ReviewsToSendPage({super.key});

  @override
  State<ReviewsToSendPage> createState() => _ReviewsToSendPageState();
}

class _ReviewsToSendPageState extends State<ReviewsToSendPage> {
  /// The decks left unticked, by id. Every deck starts ticked.
  final Set<String> _unticked = <String>{};

  /// The languages whose answers are left unticked.
  final Set<String> _untickedAnswers = <String>{};

  /// The cards dropped from this mail, by deck id: they stay on the phone.
  final Map<String, Set<String>> _held = <String, Set<String>>{};

  /// The groups whose open state was flipped from its start: a lone group
  /// starts open, any other shut.
  final Set<String> _flipped = <String>{};
  bool _sending = false;

  bool _isOpen(String key, bool single) => _flipped.contains(key) != single;

  void _flip(String key) => setState(() {
    if (!_flipped.remove(key)) _flipped.add(key);
  });

  Future<void> _send(
    List<DeckReview> decks,
    List<LoggedAnswer> answers,
    List<DeckReview> carried,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    setState(() => _sending = true);
    final outcome = await state.reviewing.send(
      decks,
      answers: answers,
      held: _held,
      body: reviewMailBody(l10n, state, carried, answers: answers.length),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    showAppSnackBar(context, switch (outcome) {
      ReviewSendOutcome.inMailApp => l10n.reviewSendOpened,
      ReviewSendOutcome.nothingToSend => l10n.reviewSendNothing,
      ReviewSendOutcome.noMailApp => l10n.reviewSendNoApp,
      ReviewSendOutcome.failed => l10n.reviewSendFailed,
    });
  }

  Future<void> _card(DeckReview review, String cardId, DeckEntry? entry) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (entry != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.reviewToSendChange),
                onTap: () => Navigator.of(context).pop(true),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.reviewToSendDrop),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice) {
      await AppNavigator.openReview(context, review.deckId);
      return;
    }
    setState(() {
      _held.putIfAbsent(review.deckId, () => <String>{}).add(cardId);
    });
    showAppSnackBar(context, l10n.reviewToSendDropped);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final reviewing = state.reviewing;
        final decks = <DeckReview>[
          for (final deck in reviewing.unsent)
            if (deck.without(_held[deck.deckId] ?? const <String>{}).hasUnsent)
              deck,
        ];
        final byLanguage = <String, List<LoggedAnswer>>{};
        for (final a in reviewing.unsentAnswers) {
          byLanguage.putIfAbsent(a.language, () => <LoggedAnswer>[]).add(a);
        }
        final mails = reviewing.sentMails;
        final chosenDecks = <DeckReview>[
          for (final deck in decks)
            if (!_unticked.contains(deck.deckId)) deck,
        ];
        final chosenAnswers = <LoggedAnswer>[
          for (final entry in byLanguage.entries)
            if (!_untickedAnswers.contains(entry.key)) ...entry.value,
        ];
        final waiting = decks.isNotEmpty || byLanguage.isNotEmpty;
        final single = decks.length + byLanguage.length == 1;
        final names = languageNamesOf(state);
        final carried = <DeckReview>[
          for (final deck in chosenDecks)
            deck.without(_held[deck.deckId] ?? const <String>{}),
        ];
        final label = _sendLabel(
          l10n,
          chosenDecks.length,
          chosenAnswers.length,
        );
        final canSend =
            !_sending && (chosenDecks.isNotEmpty || chosenAnswers.isNotEmpty);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.reviewSettingsToSend)),
          body: !waiting && mails.isEmpty
              ? EmptyState(
                  icon: Icons.mail_outline,
                  title: l10n.reviewToSendNothing,
                )
              : ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    16,
                    4,
                    16,
                    24,
                  ).clearingSystemBar(context),
                  children: <Widget>[
                    for (final deck in decks)
                      _DeckGroup(
                        key: ValueKey<String>('deck-${deck.deckId}'),
                        review: deck,
                        held: _held[deck.deckId] ?? const <String>{},
                        ticked: !_unticked.contains(deck.deckId),
                        open: _isOpen('d:${deck.deckId}', single),
                        enabled: !_sending,
                        onTick: (on) => setState(
                          () => on
                              ? _unticked.remove(deck.deckId)
                              : _unticked.add(deck.deckId),
                        ),
                        onToggle: () => _flip('d:${deck.deckId}'),
                        onCard: (cardId, entry) => _card(deck, cardId, entry),
                      ),
                    for (final entry in byLanguage.entries)
                      _AnswerGroup(
                        key: ValueKey<String>('answers-${entry.key}'),
                        language: names[entry.key] ?? entry.key,
                        code: entry.key,
                        answers: entry.value,
                        ticked: !_untickedAnswers.contains(entry.key),
                        open: _isOpen('a:${entry.key}', single),
                        enabled: !_sending,
                        onTick: (on) => setState(
                          () => on
                              ? _untickedAnswers.remove(entry.key)
                              : _untickedAnswers.add(entry.key),
                        ),
                        onToggle: () => _flip('a:${entry.key}'),
                      ),
                    if (mails.isNotEmpty) _SentSection(mails: mails),
                  ],
                ),
          bottomNavigationBar: waiting
              ? BottomActions(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppSizes.primaryButton,
                      ),
                    ),
                    onPressed: canSend
                        ? () => _send(chosenDecks, chosenAnswers, carried)
                        : null,
                    icon: const Icon(Icons.send_outlined, size: 20),
                    label: Text(label, textAlign: TextAlign.center),
                  ),
                )
              : null,
        );
      },
    );
  }

  /// "Send 2 decks and 2 answers", counting only what is ticked.
  static String _sendLabel(AppLocalizations l10n, int decks, int answers) {
    if (decks > 0 && answers > 0) return l10n.reviewToSendBoth(decks, answers);
    if (answers > 0) return l10n.reviewQuestionsSend(answers);
    return l10n.reviewSendButton(decks);
  }
}

/// A group of a [ReviewsToSendPage]: a tick, a title and a line, and a fold
/// that opens to [children], the items it sends.
class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.subtitle,
    required this.ticked,
    required this.open,
    required this.enabled,
    required this.onTick,
    required this.onToggle,
    required this.children,
    this.signedOff = false,
  });

  final String title;
  final String subtitle;
  final bool ticked;
  final bool open;
  final bool enabled;
  final ValueChanged<bool> onTick;
  final VoidCallback onToggle;
  final List<Widget> children;
  final bool signedOff;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(width: 4),
                Semantics(
                  label: title,
                  child: Checkbox(
                    value: ticked,
                    onChanged: enabled ? (on) => onTick(on == true) : null,
                  ),
                ),
                Expanded(
                  child: Semantics(
                    expanded: open,
                    child: InkWell(
                      onTap: onToggle,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: <Widget>[
                                Text(title, style: theme.textTheme.titleMedium),
                                if (signedOff)
                                  Semantics(
                                    label: l10n.reviewUnsentSignedOff,
                                    child: Icon(
                                      Icons.verified_outlined,
                                      size: 18,
                                      color: scheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: open ? l10n.hintCollapse : l10n.hintExpand,
                  onPressed: onToggle,
                  icon: Icon(open ? Icons.expand_less : Icons.expand_more),
                ),
              ],
            ),
            if (open)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: children,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One deck's unsent reviews: its cards, each with every item sent.
class _DeckGroup extends StatelessWidget {
  const _DeckGroup({
    super.key,
    required this.review,
    required this.held,
    required this.ticked,
    required this.open,
    required this.enabled,
    required this.onTick,
    required this.onToggle,
    required this.onCard,
  });

  final DeckReview review;

  /// The cards dropped from this mail.
  final Set<String> held;
  final bool ticked;
  final bool open;
  final bool enabled;
  final ValueChanged<bool> onTick;
  final VoidCallback onToggle;
  final void Function(String cardId, DeckEntry? entry) onCard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final entry = state.reviewDeckById(review.deckId);
    final shown = review.without(held);
    final order = <String, int>{
      if (entry != null)
        for (final (i, c) in entry.cards.indexed) c.id: i,
    };
    final cards = <({String id, Card? card, CardReview review})>[
      for (final MapEntry(:key, :value) in shown.unsentCards.entries)
        (
          id: key,
          card: entry?.cards.where((c) => c.id == key).firstOrNull,
          review: value,
        ),
    ];
    int rank(String id) => order[id] ?? 1 << 30;
    cards.sort((a, b) => rank(a.id).compareTo(rank(b.id)));
    final names = languageNamesOf(state);
    return _Group(
      title: entry?.deck.name ?? review.deckId,
      subtitle: joinParts(l10n, <String>[
        entry?.language.name ?? names[review.language] ?? review.language,
        l10n.reviewSendDeckCount(cards.length),
      ]),
      signedOff: shown.unsentSignOff,
      ticked: ticked,
      open: open,
      enabled: enabled,
      onTick: onTick,
      onToggle: onToggle,
      children: <Widget>[
        for (final c in cards)
          _CardItem(
            key: ValueKey<String>('card-${review.deckId}-${c.id}'),
            entry: entry,
            card: c.card,
            cardId: c.id,
            review: c.review,
            enabled: enabled,
            onTap: () => onCard(c.id, entry),
          ),
      ],
    );
  }
}

/// A card of a deck group: its word, then each item the mail carries for it.
/// Tapping it offers Change or Drop from this mail.
class _CardItem extends StatelessWidget {
  const _CardItem({
    super.key,
    required this.entry,
    required this.card,
    required this.cardId,
    required this.review,
    required this.enabled,
    required this.onTap,
  });

  final DeckEntry? entry;
  final Card? card;
  final String cardId;
  final CardReview review;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = this.card;
    final entry = this.entry;
    final rows = _itemsOf(l10n, entry, card, review);
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (card != null && entry != null)
                          TargetText(
                            card.target,
                            language: entry.language,
                            fontSize: 20,
                            textAlign: TextAlign.start,
                          )
                        else
                          Text(cardId, style: theme.textTheme.titleMedium),
                        if (card != null)
                          Text(
                            joinParts(l10n, <String>[
                              ?card.reading,
                              card.native,
                            ]),
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          for (final row in rows) row,
        ],
      ),
    );
  }

  /// Every item the mail carries for the card, one row each.
  static List<Widget> _itemsOf(
    AppLocalizations l10n,
    DeckEntry? entry,
    Card? card,
    CardReview review,
  ) {
    final rows = <Widget>[];
    if (review.right) {
      rows.add(
        _ItemRow(
          icon: Icons.check,
          kind: _ItemKind.right,
          label: l10n.reviewStateRight,
          lines: const <(String?, String)>[],
        ),
      );
    }
    for (final facet in Facet.values) {
      final answer = review.facets[facet];
      if (answer == null) continue;
      final name = facetTitle(l10n, facet);
      if (answer.isRight) {
        rows.add(
          _ItemRow(
            icon: Icons.check,
            kind: _ItemKind.right,
            label: name,
            lines: <(String?, String)>[(null, l10n.reviewLooksRight)],
          ),
        );
      } else {
        rows.add(
          _ItemRow(
            icon: Icons.flag_outlined,
            kind: _ItemKind.flagged,
            label: name,
            lines: <(String?, String)>[
              (
                null,
                <String>[
                  for (final tag in answer.tags) pointerTagLabel(l10n, tag),
                ].join(' · '),
              ),
              if (answer.hasReplacement) (null, answer.replacement!),
            ],
          ),
        );
      }
    }
    for (final s in review.suggestions) {
      rows.add(
        _ItemRow(
          icon: Icons.edit_outlined,
          kind: _ItemKind.flagged,
          label: card == null
              ? partName(l10n, s.part)
              : suggestionPartName(l10n, card, s.part, word: s.word),
          lines: <(String?, String)>[
            if (!s.part.isAddOnly && !s.flag)
              (
                l10n.reviewYoursNow,
                s.now.isEmpty ? l10n.reviewSuggestNothing : s.now,
              ),
            (l10n.reviewYoursYours, yoursOf(l10n, s)),
            if (s.why.isNotEmpty) (l10n.reviewYoursWhy, s.why),
          ],
        ),
      );
    }
    final rating = review.rating;
    if (rating != null) {
      rows.add(
        _ItemRow(
          icon: Icons.star_outline,
          kind: _ItemKind.note,
          label: facetTitle(l10n, Facet.offenceRating),
          lines: <(String?, String)>[(null, l10n.reviewRated(rating.score))],
        ),
      );
    }
    for (final answer in review.answers.values) {
      rows.add(
        _ItemRow(
          icon: Icons.person_outline,
          kind: _ItemKind.note,
          label: l10n.reviewToSendProposal,
          lines: <(String?, String)>[
            (
              null,
              l10n.reviewToSendProposalValue(
                switch (answer.verdict) {
                  ProposalVerdict.accept => l10n.reviewSentAccepted,
                  ProposalVerdict.edit => l10n.reviewToSendEdited,
                  ProposalVerdict.reject => l10n.reviewSentRejected,
                },
                answer.text,
              ),
            ),
          ],
        ),
      );
    }
    final alike = review.alike;
    if (alike != null) {
      final partner = entry?.cards
          .where((c) => c.id == alike.partner)
          .firstOrNull;
      rows.add(
        _ItemRow(
          icon: Icons.sell_outlined,
          kind: _ItemKind.note,
          label: l10n.reviewToSendAlike,
          lines: <(String?, String)>[
            (
              null,
              alike.real
                  ? l10n.reviewAlikeConfirmed
                  : l10n.reviewAlikeRejected,
            ),
            if (partner != null) (null, partner.target),
            if (alike.care.isNotEmpty) (l10n.reviewAlikeCare, alike.care),
          ],
        ),
      );
    }
    return rows;
  }
}

enum _ItemKind { right, flagged, note }

/// An item of a card: an icon for its kind (ticked, flagged or noted, never
/// by colour alone), its label and lines, each optionally labelled.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.icon,
    required this.kind,
    required this.label,
    required this.lines,
  });

  final IconData icon;
  final _ItemKind kind;
  final String label;
  final List<(String?, String)> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = switch (kind) {
      _ItemKind.right => scheme.primary,
      _ItemKind.flagged => scheme.tertiary,
      _ItemKind.note => scheme.onSurfaceVariant,
    };
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Icon(icon, size: 20, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                for (final (name, text) in lines)
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        if (name != null)
                          TextSpan(
                            text: '$name  ',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        TextSpan(text: text),
                      ],
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One language's daily-question answers: a tick of their own, and the
/// answers, each with its Answer, Reason and Why.
class _AnswerGroup extends StatelessWidget {
  const _AnswerGroup({
    super.key,
    required this.language,
    required this.code,
    required this.answers,
    required this.ticked,
    required this.open,
    required this.enabled,
    required this.onTick,
    required this.onToggle,
  });

  final String language;
  final String code;
  final List<LoggedAnswer> answers;
  final bool ticked;
  final bool open;
  final bool enabled;
  final ValueChanged<bool> onTick;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    DeckEntry? deckOf(String cardId) {
      for (final d in state.decks) {
        final here = d.language.code == code;
        if (here && d.cards.any((c) => c.id == cardId)) return d;
      }
      return null;
    }

    return _Group(
      title: l10n.reviewQuestionsTitle,
      subtitle: joinParts(l10n, <String>[
        language,
        l10n.reviewToSendAnswers(answers.length),
      ]),
      ticked: ticked,
      open: open,
      enabled: enabled,
      onTick: onTick,
      onToggle: onToggle,
      children: <Widget>[
        for (final a in answers)
          Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _answerWord(theme, deckOf(a.card), a),
                  _line(
                    theme,
                    l10n.reviewToSendAnswer,
                    switch (a.answer) {
                      QuestionAnswer.yes => l10n.reviewQuestionYes,
                      QuestionAnswer.no => l10n.reviewQuestionNo,
                      QuestionAnswer.flag => l10n.hintFlag,
                    },
                  ),
                  if (a.reason != null)
                    _line(
                      theme,
                      l10n.reviewToSendReason,
                      reasonLabel(l10n, a.reason!),
                    ),
                  if (a.why.isNotEmpty)
                    _line(theme, l10n.reviewYoursWhy, a.why),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _answerWord(ThemeData theme, DeckEntry? entry, LoggedAnswer a) {
    final card = entry?.cards.where((c) => c.id == a.card).firstOrNull;
    if (entry == null || card == null) {
      return Text(a.card, style: theme.textTheme.titleMedium);
    }
    return TargetText(
      card.target,
      language: entry.language,
      fontSize: 20,
      textAlign: TextAlign.start,
    );
  }

  Widget _line(ThemeData theme, String label, String text) => Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(
          text: '$label  ',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        TextSpan(text: text),
      ],
    ),
    style: theme.textTheme.bodyMedium,
  );
}

/// The mails sent, newest first, each by date with its decks and answers,
/// and Send again while a deck of it is not acknowledged.
class _SentSection extends StatelessWidget {
  const _SentSection({required this.mails});

  final List<SentMail> mails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final sent = sentSuggestionsOf(state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 6),
          child: Semantics(
            header: true,
            child: Text(
              l10n.reviewToSendSent,
              style: theme.textTheme.labelLarge!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        for (final mail in mails)
          _MailRow(
            key: ValueKey<String>('mail-${mail.at.toUtc().toIso8601String()}'),
            mail: mail,
            acknowledged: acknowledgedDecks(mail, sent),
          ),
      ],
    );
  }
}

class _MailRow extends StatelessWidget {
  const _MailRow({super.key, required this.mail, required this.acknowledged});

  final SentMail mail;
  final Set<String> acknowledged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(mail.at.toLocal());
    final what = <String>[
      for (final id in mail.decks.keys)
        state.reviewDeckById(id)?.deck.name ?? id,
      if (mail.answers.isNotEmpty)
        l10n.reviewToSendAnswers(mail.answers.length),
    ].join(', ');
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 2),
                child: Semantics(
                  label: l10n.reviewToSendMailOpened,
                  child: Icon(
                    Icons.mail_outline,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(date, style: theme.textTheme.titleMedium),
                    if (what.isNotEmpty)
                      Text(
                        what,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (mail.canSendAgain(acknowledged))
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                          ),
                        ),
                        onPressed: () {
                          state.reviewing.sendMailAgain(
                            mail,
                            mail.unacknowledged(acknowledged),
                          );
                          showAppSnackBar(context, l10n.reviewToSendAgainDone);
                        },
                        icon: const Icon(Icons.replay_outlined, size: 20),
                        label: Text(l10n.reviewToSendAgain),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
