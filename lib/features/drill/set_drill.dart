import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/card_sets.dart';
import '../../core/models/card.dart';
import '../../core/models/card_set.dart';
import '../../core/models/deck.dart';
import '../../core/scheduling/lesson_sets.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';

/// A set card in a lesson (DECK-FORMAT.md, Set cards; #515; the approved
/// mockup `docs/mockups/set-cards.html`): a closed group's members together,
/// before the lesson drills the new ones. On the drill's own card, labelled
/// "The set" (or "The set · 2 of 3" for a part of a set too big for one
/// card), with a Full list button beside it where the set has one; the
/// set's explanation; each member a row, its word over its reading, its
/// meaning and its mark, New or Known, the whole row playing the word; and
/// on the set's last part, a line saying what comes next and naming the
/// members it skips. Continue goes on; nothing is recorded.
///
/// Build one per card (key it by the card's position).
class SetDrill extends StatelessWidget {
  const SetDrill({super.key, required this.session, required this.onClose});

  final DrillSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final part = session.item.setPart!;
    final language = session.deck.language;
    final label = Text(
      part.isSplit
          ? l10n.setPartTitle(part.index + 1, part.count)
          : l10n.setTitle,
      style: theme.textTheme.labelLarge!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );

    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      reportDetail: '${part.set.set.id} in ${part.set.set.deckId}',
      progress: session.progress,
      onClose: onClose,
      card: <Widget>[
        if (part.set.hasFullList)
          Row(
            children: <Widget>[
              Expanded(child: label),
              const SizedBox(width: 8),
              FullListButton(
                sets: <ResolvedSet>[part.set],
                language: language,
                isKnown: part.isKnown,
                isNew: part.newIds.contains,
                onPlay: session.playCard,
                canPlay: session.canPlay,
              ),
            ],
          )
        else
          Center(child: label),
        Text(
          part.set.set.explanation,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (i, member) in part.members.indexed) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              SetMemberRow(
                card: member,
                language: language,
                mark: part.isKnown(member) ? SetMark.known : SetMark.fresh,
                onPlay: session.canPlay ? () => session.playCard(member) : null,
              ),
            ],
          ],
        ),
        if (part.isLast)
          Text(
            nextLine(l10n, part),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
      actions: <Widget>[
        FilledButton(
          onPressed: session.learnt,
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
      ],
    );
  }
}

/// The line under a set's last part (the mockup's decision 5): what the
/// lesson does next, the next set or the new members' questions, and which
/// members it skips because the learner knows them, always named with
/// their readings, for a split set and for verb forms too (owner,
/// 2026-10-16, #515: "Name them always").
String nextLine(AppLocalizations l10n, SetPart part) {
  final next = part.next;
  if (next != null) return l10n.setNextSet(next.set.name);
  final fresh = part.lessonNew;
  if (fresh.isEmpty) return '';
  final words = joinWords(l10n, <String>[for (final c in fresh) shownWord(c)]);
  final forms = fresh.every((card) => card.rule != null);
  final line = forms
      ? l10n.setNextForms(fresh.length, words)
      : l10n.setNextWords(fresh.length, words);
  final known = <Card>[
    for (final member in part.set.members)
      if (part.isKnown(member)) member,
  ];
  if (known.isEmpty) return line;
  final names = joinWords(l10n, <String>[for (final c in known) shownWord(c)]);
  return '$line ${l10n.setKnownWords(names)}';
}

/// [card]'s word as interface prose quotes it: with its reading in
/// brackets, as `आप (āp)`, where it has one.
String shownWord(Card card) =>
    card.reading == null ? card.target : '${card.target} (${card.reading})';

/// [words] as one list, "A, B and C", its joins the interface language's.
String joinWords(AppLocalizations l10n, List<String> words) {
  if (words.isEmpty) return '';
  if (words.length == 1) return words.single;
  var head = words.first;
  for (final word in words.sublist(1, words.length - 1)) {
    head = l10n.setListMore(head, word);
  }
  return l10n.setListPair(head, words.last);
}

/// How a set's member is marked: taught before, taught in this lesson, or,
/// in a Full list of every verb of the course, not learnt yet (owner,
/// 2026-10-16, #515: "with unlearnt ones as well, but marked as such").
enum SetMark { known, fresh, notLearnt }

/// One member of a set: its word over its reading, its meaning and its
/// mark, New on a chip, Known with a check, or Not learnt yet in an
/// outline, a known or unlearnt word in the muted colour; the whole row
/// plays the word, with a speaker at its end. The mark is a word, never
/// colour alone.
class SetMemberRow extends StatelessWidget {
  const SetMemberRow({
    super.key,
    required this.card,
    required this.language,
    required this.mark,
    this.onPlay,
  });

  final Card card;
  final LanguageInfo language;
  final SetMark mark;

  /// Plays the word; null where the phone has no voice for it.
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final play = onPlay;
    final known = mark != SetMark.fresh;
    final chip = switch (mark) {
      SetMark.known => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle, size: 18, color: muted),
          const SizedBox(width: 4),
          Text(
            l10n.setKnown,
            style: theme.textTheme.labelLarge!.copyWith(color: muted),
          ),
        ],
      ),
      SetMark.notLearnt => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          child: Text(
            l10n.setNotLearnt,
            style: theme.textTheme.labelLarge!.copyWith(color: muted),
          ),
        ),
      ),
      SetMark.fresh => DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          child: Text(
            l10n.setNew,
            style: theme.textTheme.labelLarge!.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    };
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: <Widget>[
                      TargetText.card(
                        card.target,
                        language: language,
                        fontSize: 24,
                        textAlign: TextAlign.start,
                        color: known ? muted : scheme.onSurface,
                      ),
                      if (card.reading case final reading?)
                        Text(
                          reading,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        card.native,
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: known ? muted : scheme.onSurface,
                        ),
                      ),
                      chip,
                    ],
                  ),
                ],
              ),
            ),
            if (play != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Icon(Icons.volume_up_outlined, color: muted),
              ),
          ],
        ),
      ),
    );
    final word = shownWord(card);
    return Semantics(
      button: play != null,
      excludeSemantics: true,
      onTap: play == null ? null : () => SpeakerActions.tap(context, play),
      label: switch (mark) {
        SetMark.known => l10n.setRowKnown(word, card.native),
        SetMark.fresh => l10n.setRowNew(word, card.native),
        SetMark.notLearnt => l10n.setRowNotLearnt(word, card.native),
      },
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.field),
        clipBehavior: Clip.antiAlias,
        child: play == null
            ? row
            : InkWell(
                onTap: () => SpeakerActions.tap(context, play),
                child: row,
              ),
      ),
    );
  }
}

/// The Full list button (owner, 2026-10-16: "Split sets only", and for a
/// set of one person across the verbs, "a full list will show all verbs
/// in the course"): a tonal button with a list icon that opens the whole
/// of [sets] in a bottom sheet. On the set's card, in its header row; on a
/// question about one of its members, once it is answered.
class FullListButton extends StatelessWidget {
  const FullListButton({
    super.key,
    required this.sets,
    required this.language,
    required this.isKnown,
    this.isNew,
    required this.onPlay,
    required this.canPlay,
  });

  final List<ResolvedSet> sets;
  final LanguageInfo language;
  final bool Function(Card card) isKnown;

  /// Whether a member not [isKnown] is taught in this lesson, and so New;
  /// null where none is. In a set of one slot across the words, one that
  /// is neither is marked not learnt.
  final bool Function(Card card)? isNew;
  final Future<void> Function(Card card) onPlay;
  final bool canPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final first = sets.first;
    return FilledButton.tonalIcon(
      onPressed: () => showSetList(
        context,
        sets: sets,
        language: language,
        isKnown: isKnown,
        isNew: isNew,
        onPlay: canPlay ? onPlay : null,
      ),
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(48, 48)),
      ),
      icon: const Icon(Icons.format_list_bulleted),
      label: Text(
        l10n.setFullList,
        semanticsLabel: l10n.setFullListLabel(first.all.length, first.set.name),
      ),
    );
  }
}

/// Opens the Full list: a modal bottom sheet with [sets] whole, in the
/// deck's order, each member marked as on the card and playing its word.
/// A set of one slot across the words lists every cell of the course
/// instead, the learnt ones on top, then this lesson's new ones, then the
/// rest marked not learnt (owner, 2026-10-16, #515: "learnt ones sorted to
/// be on top"). One set is titled by its name, with how many members and
/// how many new (or learnt); a form in two sets lists both, one after the
/// other ("Show both"). It closes with its close button, a swipe down or
/// Back, and the lesson goes on where it was.
Future<void> showSetList(
  BuildContext context, {
  required List<ResolvedSet> sets,
  required LanguageInfo language,
  required bool Function(Card card) isKnown,
  bool Function(Card card)? isNew,
  Future<void> Function(Card card)? onPlay,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => _SetListSheet(
    sets: sets,
    language: language,
    isKnown: isKnown,
    isNew: isNew,
    onPlay: onPlay,
  ),
);

class _SetListSheet extends StatelessWidget {
  const _SetListSheet({
    required this.sets,
    required this.language,
    required this.isKnown,
    this.isNew,
    this.onPlay,
  });

  final List<ResolvedSet> sets;
  final LanguageInfo language;
  final bool Function(Card card) isKnown;
  final bool Function(Card card)? isNew;
  final Future<void> Function(Card card)? onPlay;

  SetMark markOf(ResolvedSet set, Card card) {
    if (isKnown(card)) return SetMark.known;
    if (!set.set.acrossRows || (isNew?.call(card) ?? false)) {
      return SetMark.fresh;
    }
    return SetMark.notLearnt;
  }

  /// [set]'s Full list in order: a set of one slot across the words with
  /// its learnt cells first, then the new ones, then the unlearnt, each
  /// group in the table's order; any other set as it is.
  List<(Card, SetMark)> rowsOf(ResolvedSet set) {
    final rows = <(Card, SetMark)>[
      for (final card in set.all) (card, markOf(set, card)),
    ];
    if (!set.set.acrossRows) return rows;
    return <(Card, SetMark)>[
      for (final mark in SetMark.values)
        for (final row in rows)
          if (row.$2 == mark) row,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final one = sets.length == 1;
    final first = sets.first;
    final count = first.all.length;
    final fresh = first.all.where((m) => !isKnown(m)).length;
    final forms = first.set.rule != null;
    final play = onPlay;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 8, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        one ? first.set.name : l10n.setSheetSets(sets.length),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        one
                            ? first.set.acrossRows
                                  ? l10n.setSheetLearnt(count, count - fresh)
                                  : forms
                                  ? l10n.setSheetForms(count, fresh)
                                  : l10n.setSheetWords(count, fresh)
                            : joinWords(l10n, <String>[
                                for (final s in sets) s.set.name,
                              ]),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.commonClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              // Clear of the navigation bar the sheet is drawn under.
              padding: EdgeInsetsDirectional.fromSTEB(
                16,
                0,
                16,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: <Widget>[
                for (final set in sets) ...<Widget>[
                  if (!one)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        8,
                        16,
                        8,
                        8,
                      ),
                      child: Text(
                        set.set.name,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  for (final (i, (member, mark)) in rowsOf(
                    set,
                  ).indexed) ...<Widget>[
                    if (i > 0) const SizedBox(height: 8),
                    SetMemberRow(
                      card: member,
                      language: language,
                      mark: mark,
                      onPlay: play == null ? null : () => play(member),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Full list button on a question about [session]'s card, once it is
/// [answered], when the card is a member of a set split over more than one
/// card, or in the Full list of a set of one slot across the words (owner,
/// 2026-10-16): in a lesson, in practice and in review. Never
/// before the answer, which the list would give away; for a form in two
/// such sets, the sheet lists both. None otherwise: spread it at the end of
/// a drill's card.
List<Widget> answeredSetList(
  BuildContext context,
  DrillSession session, {
  required bool answered,
}) {
  if (!answered || session.item.setPart != null) return const <Widget>[];
  final state = AppScope.of(context);
  final sets = state.fullListSetsOf(session.item.card);
  if (sets.isEmpty) return const <Widget>[];
  return <Widget>[
    Center(
      child: FullListButton(
        key: const ValueKey<String>('full-list'),
        sets: sets,
        language: session.deck.language,
        isKnown: (card) => state.taughtId(card.id),
        onPlay: session.playCard,
        canPlay: session.canPlay,
      ),
    ),
  ];
}
