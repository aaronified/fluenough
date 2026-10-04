import 'package:flutter/material.dart' hide Card;
import 'package:flutter/semantics.dart';

import '../../core/models/deck.dart';
import '../../core/scheduling/session_queue.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/target_text.dart';
import 'drill_session.dart';

/// Match pairs (ADR-0024): a few words in the language learned beside their
/// meanings, shuffled, matched by dragging a word onto its meaning, or by
/// tapping one and then the other, in either order. Each word is recorded
/// as recognition when it is matched: right first time, or after a slip.
///
/// Build one per card (key it by the card's position).
class MatchDrill extends StatefulWidget {
  const MatchDrill({super.key, required this.session, required this.onClose});

  final DrillSession session;
  final VoidCallback onClose;

  @override
  State<MatchDrill> createState() => _MatchDrillState();
}

/// Which half of a pair a tile shows.
enum _Side { word, meaning }

class _MatchDrillState extends State<MatchDrill> {
  /// The tile tapped first, waiting for the other half of its pair.
  (SessionItem, _Side)? _selected;

  /// The two tiles last matched wrongly, shown as such until the next try.
  (SessionItem, SessionItem)? _missed;

  DrillSession get _session => widget.session;

  void _match(SessionItem word, SessionItem meaning) {
    final right = _session.match(word, meaning);
    setState(() {
      _selected = null;
      _missed = right ? null : (word, meaning);
    });
    if (!right) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        AppLocalizations.of(context)!.drillMatchMissed,
        Directionality.of(context),
      );
    }
  }

  void _tap(SessionItem entry, _Side side) {
    final selected = _selected;
    if (selected == null || selected.$2 == side) {
      setState(() {
        _selected = selected?.$1 == entry ? null : (entry, side);
        _missed = null;
      });
      return;
    }
    side == _Side.meaning
        ? _match(selected.$1, entry)
        : _match(entry, selected.$1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = _session;
    final language = session.deck.language;
    final done = session.phase == DrillPhase.feedback;
    final slips = session.item.group.where(session.wasMissed).length;

    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      reportDetail: <String>[
        for (final entry in session.item.group) entry.card.id,
      ].join(', '),
      progress: session.progress,
      onClose: widget.onClose,
      card: <Widget>[
        Text(
          l10n.drillMatchPrompt,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (!done)
          Text(
            l10n.drillMatchHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Semantics(
                container: true,
                label: l10n.drillMatchWords,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final entry in session.matchTargets)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 8),
                        child: _word(entry, language),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                container: true,
                label: l10n.drillMatchMeanings,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final entry in session.matchMeanings)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 8),
                        child: _meaning(entry),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
      feedback: !done
          ? null
          : slips == 0
          ? FeedbackBanner(
              kind: FeedbackKind.correct,
              title: l10n.feedbackCorrect,
            )
          : FeedbackBanner(
              kind: FeedbackKind.nearMiss,
              title: l10n.drillMatchAgain(slips),
              detail: <String>[
                for (final entry in session.item.group)
                  if (session.wasMissed(entry))
                    '${entry.card.target} – ${entry.card.native}',
              ].join('\n'),
              quotes: <String>[
                for (final entry in session.item.group)
                  if (session.wasMissed(entry)) entry.card.target,
              ],
              language: language,
            ),
      actions: done
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

  /// A word, which can be dragged onto a meaning.
  Widget _word(SessionItem entry, LanguageInfo language) {
    final matched = _session.isMatched(entry);
    final reading = entry.card.reading;
    final showReading = reading != null && !_session.expectsScript;
    Widget face(Color color) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showReading)
          Text(
            reading,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium!
                .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        TargetText.card(
          entry.card.target,
          language: language,
          fontSize: showReading ? 14 : 20,
          color: color,
        ),
      ],
    );
    final tile = _Tile(
      state: _stateOf(entry, _Side.word),
      onTap: matched ? null : () => _tap(entry, _Side.word),
      face: face,
    );
    if (matched) return tile;
    return Draggable<SessionItem>(
      data: entry,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 150,
          child: _Tile(state: _TileState.selected, onTap: null, face: face),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: tile),
      child: tile,
    );
  }

  /// A meaning, onto which a word can be dropped.
  Widget _meaning(SessionItem entry) {
    final matched = _session.isMatched(entry);
    return DragTarget<SessionItem>(
      onWillAcceptWithDetails: (_) => !matched,
      onAcceptWithDetails: (details) => _match(details.data, entry),
      builder: (context, candidates, _) => _Tile(
        state: candidates.isNotEmpty
            ? _TileState.selected
            : _stateOf(entry, _Side.meaning),
        onTap: matched ? null : () => _tap(entry, _Side.meaning),
        face: (color) => Text(
          entry.card.native,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge!
              .copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  _TileState _stateOf(SessionItem entry, _Side side) {
    if (_session.isMatched(entry)) return _TileState.matched;
    final selected = _selected;
    if (selected != null && selected.$1 == entry && selected.$2 == side) {
      return _TileState.selected;
    }
    final missed = _missed;
    if (missed != null &&
        (side == _Side.word ? missed.$1 : missed.$2) == entry) {
      return _TileState.missed;
    }
    return _TileState.open;
  }
}

enum _TileState { open, selected, missed, matched }

/// One word or meaning: a tile that shows its state by colour and, for
/// screen readers, in words.
class _Tile extends StatelessWidget {
  const _Tile({required this.state, required this.onTap, required this.face});

  final _TileState state;
  final VoidCallback? onTap;
  final Widget Function(Color color) face;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, Color border) = switch (state) {
      _TileState.open => (
        scheme.surfaceContainerLow,
        scheme.onSurface,
        scheme.outline,
      ),
      _TileState.selected => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        scheme.secondary,
      ),
      _TileState.missed => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        scheme.error,
      ),
      _TileState.matched => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
    };
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        selected: state == _TileState.selected,
        value: switch (state) {
          _TileState.matched => l10n.drillMatchMatched,
          _TileState.selected => l10n.drillMatchSelected,
          _ => null,
        },
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.small),
            side: BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.primaryButton,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Center(child: face(fg)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
