import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/review/flagged_queue.dart';
import '../../core/review/review_pairs.dart';
import '../../core/review/review_session.dart';
import '../../core/review/second_speaker.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../decks/path_model.dart' show unitOfDeck, unitTitle;
import 'flagged_page.dart';
import 'review_card_view.dart';
import 'review_source.dart';
import 'second_speaker_views.dart';

/// Which of the review screens' ways of walking through cards this is.
enum ReviewMode {
  /// The queue: a session of [kSessionCards], then the pool.
  queue,

  /// Only the flagged and contested cards.
  flagged,

  /// One unit, from the deck view.
  unit,

  /// One card, from the deck view.
  card,
}

/// Where the reviewer is in the flow.
enum _Stage { cards, digest, end }

/// Opens the review of a course's queue: resumes the run in progress, or
/// starts a session (ADR-0058, decision 10).
Future<void> showReviewQueue(BuildContext context, ReviewPair pair) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/review-session'),
        builder: (_) => ReviewFlowPage.queue(pair: pair),
      ),
    );

/// Opens only the flagged and contested cards, from [start] if given.
Future<void> showReviewFlagged(BuildContext context, {QueueCardRef? start}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/review-flagged-only'),
        builder: (_) => ReviewFlowPage.flagged(start: start),
      ),
    );

/// Opens unit [unit] of [pair]'s course, every card with all its details.
Future<void> showReviewUnit(BuildContext context, ReviewPair pair, int unit) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/review-unit'),
        builder: (_) => ReviewFlowPage.unit(pair: pair, unit: unit),
      ),
    );

/// Opens one card of [pair]'s course with all its details.
Future<void> showReviewCard(
  BuildContext context,
  ReviewPair pair,
  QueueCardRef ref,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/review-card'),
    builder: (_) => ReviewFlowPage.card(pair: pair, ref: ref),
  ),
);

/// The review screens (ADR-0058; docs/mockups/reviewer-ux.html, frames 1c to
/// 1f, 3a to 3d and 4c): the header is the unit's name and one compact line,
/// "Card 7 of 20" with its progress bar; below it the card
/// ([ReviewCardView]); and after the last card of a session the end screen
/// ([_EndView]). The same screen walks the queue, the flagged-only mode, a
/// unit and one card.
///
/// Answers are kept as they are given, and the queue's run is kept as it
/// changes, so that closing at any point loses nothing and the session
/// resumes.
class ReviewFlowPage extends StatefulWidget {
  const ReviewFlowPage.queue({super.key, required ReviewPair this.pair})
    : mode = ReviewMode.queue,
      unit = null,
      ref = null;

  const ReviewFlowPage.flagged({super.key, QueueCardRef? start})
    : mode = ReviewMode.flagged,
      pair = null,
      unit = null,
      ref = start;

  const ReviewFlowPage.unit({
    super.key,
    required ReviewPair this.pair,
    required int this.unit,
  }) : mode = ReviewMode.unit,
       ref = null;

  const ReviewFlowPage.card({
    super.key,
    required ReviewPair this.pair,
    required QueueCardRef this.ref,
  }) : mode = ReviewMode.card,
       unit = null;

  final ReviewMode mode;
  final ReviewPair? pair;
  final int? unit;

  /// The card to open: for [ReviewMode.card], the card; for
  /// [ReviewMode.flagged], the card to start at.
  final QueueCardRef? ref;

  static const Key closeKey = ValueKey<String>('review-close');
  static const Key backKey = ValueKey<String>('review-back');
  static const Key lineKey = ValueKey<String>('review-line');
  static const Key continueKey = ValueKey<String>('review-continue');
  static const Key endCloseKey = ValueKey<String>('review-end-close');
  static const Key endKey = ValueKey<String>('review-end');

  @override
  State<ReviewFlowPage> createState() => _ReviewFlowPageState();
}

class _ReviewFlowPageState extends State<ReviewFlowPage> {
  bool _ready = false;
  bool _starting = true;
  late AppState _state;

  /// The course, for the queue, unit and card modes.
  ReviewSource? _source;

  /// The queue's group.
  ReviewRun? _run;

  /// The cards walked, for the queue, unit and card modes.
  List<QueueCardRef> _cards = const <QueueCardRef>[];

  /// The steps walked, for the flagged-only mode.
  List<SecondSpeakerStep> _steps = const <SecondSpeakerStep>[];
  final Map<String, FlaggedSourceDeck> _flaggedDecks =
      <String, FlaggedSourceDeck>{};

  int _index = 0;
  _Stage _stage = _Stage.cards;
  bool _digestShown = false;
  String _title = '';

  /// Whether the session ended with a pool still to go through.
  bool _canContinue = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _state = AppScope.read(context);
    try {
      _begin();
    } on Object catch (e) {
      _state.log.warning('Review screen not started: ${e.runtimeType}');
      _cards = const <QueueCardRef>[];
      _steps = const <SecondSpeakerStep>[];
    }
    _starting = false;
  }

  String? get _ownCode => _state.reviewing.code?.toString();

  void _begin() {
    final reviewing = _state.reviewing;
    switch (widget.mode) {
      case ReviewMode.queue:
        final source = reviewSourceOf(_state, widget.pair!);
        _source = source;
        var run = reviewing.runOf(source.pair.key);
        if (run == null ||
            run.course != source.pair.key ||
            run.cards.every((c) => source.find(c) == null)) {
          run = ReviewQueueBuilder.startSession(
            source,
            reviews: reviewing.reviews,
            ownCode: _ownCode,
          );
        }
        if (run != null) _setRun(run, resume: true);
      case ReviewMode.unit:
        final unitSource = reviewSourceOf(_state, widget.pair!);
        _source = unitSource;
        _cards = unitSource.cardsOf(widget.unit!);
        _title = unitSource.unit(widget.unit!)?.title ?? '';
        final open = ReviewQueueBuilder.firstOpen(
          unitSource,
          _cards,
          reviewing.reviews,
        );
        _index = open >= _cards.length ? 0 : open;
      case ReviewMode.card:
        final cardSource = reviewSourceOf(_state, widget.pair!);
        _source = cardSource;
        final unit = cardSource.unitOf(widget.ref!);
        _cards = <QueueCardRef>[widget.ref!];
        _title = unit?.title ?? '';
      case ReviewMode.flagged:
        for (final deck in flaggedSourcesOf(_state)) {
          _flaggedDecks[deck.deckId] = deck;
        }
        final queue = flaggedQueueOf(_state);
        final steps = <SecondSpeakerStep>[];
        for (final flagged in queue.cards) {
          final deck = _flaggedDecks[flagged.deckId];
          final card = deck?.cards
              .where((c) => c.id == flagged.cardId)
              .firstOrNull;
          if (deck == null || card == null) continue;
          steps.addAll(stepsOfFlagged(flagged, card, deck, _ownCode));
        }
        _steps = steps;
        final start = widget.ref;
        if (start != null) {
          final at = steps.indexWhere((s) => s.ref == start);
          if (at > 0) _index = at;
        }
        if (steps.isNotEmpty) _title = _titleOfDeck(steps[_index].ref.deckId);
    }
  }

  /// Takes [run] as the queue's group, keeps it, and stands at the first
  /// card not finished when [resume], else the first.
  void _setRun(ReviewRun run, {bool resume = false}) {
    _run = run;
    _cards = run.cards;
    _title = run.title;
    _stage = _Stage.cards;
    _digestShown = false;
    _state.reviewing.keepRun(run.course, run);
    final open = resume
        ? ReviewQueueBuilder.firstOpen(
            _source!,
            _cards,
            _state.reviewing.reviews,
          )
        : 0;
    _index = open;
    if (open >= _cards.length) _groupDone();
  }

  String _titleOfDeck(String deckId) {
    final unit = unitOfDeck(_state, deckId);
    if (unit != null) return unitTitle(_state, unit.decks);
    return _state.deckById(deckId)?.deck.name ?? '';
  }

  int get _length =>
      widget.mode == ReviewMode.flagged ? _steps.length : _cards.length;

  /// The cards of the flagged-only mode, each once, in the order met.
  List<QueueCardRef> get _stepCards => <QueueCardRef>[
    for (final s in _steps)
      if (!_steps.takeWhile((o) => o != s).any((o) => o.ref == s.ref)) s.ref,
  ];

  /// Redraws, except while the screen is being started.
  void _rebuild() {
    if (mounted && !_starting) setState(() {});
  }

  void _close() => Navigator.of(context).pop();

  void _back() {
    if (_stage != _Stage.cards) {
      setState(() => _stage = _Stage.cards);
      return;
    }
    if (_index > 0) {
      setState(() {
        _index--;
        _retitle();
      });
    } else {
      _close();
    }
  }

  void _retitle() {
    if (widget.mode == ReviewMode.flagged && _steps.isNotEmpty) {
      _title = _titleOfDeck(_steps[_index].ref.deckId);
    }
  }

  void _next() {
    if (_index + 1 < _length) {
      setState(() {
        _index++;
        _retitle();
      });
      return;
    }
    _groupDone();
  }

  /// The last card of the group is done.
  void _groupDone() {
    final source = _source;
    if (widget.mode == ReviewMode.queue && source != null && _run != null) {
      final digest = digestOf(source, _run!.unit);
      if (digest.isNotEmpty && !_digestShown) {
        _digestShown = true;
        _stage = _Stage.digest;
        _rebuild();
        return;
      }
      _afterDigest();
      return;
    }
    if (widget.mode == ReviewMode.card) {
      _close();
      return;
    }
    _stage = _Stage.end;
    _canContinue = false;
    _rebuild();
  }

  void _afterDigest() {
    final source = _source!;
    final run = _run!;
    final reviewing = _state.reviewing;
    if (run.phase == ReviewPhase.session) {
      // The session is over: nothing to resume, whatever the reviewer picks.
      _canContinue =
          ReviewQueueBuilder.continuePool(
            source,
            run,
            reviews: reviewing.reviews,
            ownCode: _ownCode,
          ) !=
          null;
      reviewing.keepRun(run.course, null);
      _stage = _Stage.end;
      _rebuild();
      return;
    }
    final next = ReviewQueueBuilder.nextGroup(
      source,
      run,
      reviews: reviewing.reviews,
      ownCode: _ownCode,
    );
    if (next == null) {
      reviewing.keepRun(run.course, null);
      _canContinue = false;
      _stage = _Stage.end;
      _rebuild();
      return;
    }
    _setRun(next, resume: true);
    _rebuild();
  }

  void _continuePool() {
    final run = _run;
    final source = _source;
    if (run == null || source == null) return;
    final next = ReviewQueueBuilder.continuePool(
      source,
      run,
      reviews: _state.reviewing.reviews,
      ownCode: _ownCode,
    );
    if (next == null) {
      _close();
      return;
    }
    _setRun(next, resume: true);
    _rebuild();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final empty = _length == 0 && _stage == _Stage.cards;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: ReviewFlowPage.backKey,
          tooltip: l10n.commonBack,
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            key: ReviewFlowPage.closeKey,
            tooltip: l10n.hintClose,
            onPressed: _close,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: empty
          ? EmptyState(icon: Icons.style_outlined, title: l10n.reviewQueueEmpty)
          : _body(context),
    );
  }

  Widget _body(BuildContext context) {
    switch (_stage) {
      case _Stage.end:
        return _EndView(
          count: widget.mode == ReviewMode.flagged
              ? _stepCards.length
              : _cards.length,
          canContinue: _canContinue && widget.mode == ReviewMode.queue,
          onContinue: _continuePool,
          onClose: _close,
        );
      case _Stage.digest:
        final run = _run!;
        return ReviewDigestView(
          items: digestOf(_source!, run.unit),
          source: _source!,
          onDone: _afterDigest,
        );
      case _Stage.cards:
        return Column(
          children: <Widget>[
            _line(context),
            Expanded(child: _content(context)),
          ],
        );
    }
  }

  /// The compact line under the header: "Card 7 of 20" and its bar; in the
  /// deck view, the card's place in its unit alone.
  Widget _line(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final deckView =
        widget.mode == ReviewMode.unit || widget.mode == ReviewMode.card;
    final String text;
    double? value;
    if (deckView) {
      text = l10n.reviewCardNumber(_positionInUnit(_cards[_index]));
    } else if (widget.mode == ReviewMode.flagged) {
      final cards = _stepCards;
      final at = cards.indexOf(_steps[_index].ref) + 1;
      text = l10n.reviewCardOf(at, cards.length);
      value = at / cards.length;
    } else {
      text = l10n.reviewCardOf(_index + 1, _cards.length);
      value = (_index + 1) / _cards.length;
    }
    return Padding(
      key: ReviewFlowPage.lineKey,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      child: Row(
        spacing: 10,
        children: <Widget>[
          Text(
            text,
            style: theme.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (value != null)
            Expanded(
              child: ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(AppRadii.mark),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The card's place in its unit, from 1.
  int _positionInUnit(QueueCardRef ref) {
    final unit = _source?.unitOf(ref);
    if (unit == null) return _index + 1;
    return _source!.cardsOf(unit.number).indexOf(ref) + 1;
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.mode == ReviewMode.flagged) {
      final step = _steps[_index];
      final deck = _state.deckById(step.ref.deckId);
      final card = deck?.cards
          .where((c) => c.id == step.ref.cardId)
          .firstOrNull;
      if (deck == null || card == null) {
        return EmptyState(
          icon: Icons.style_outlined,
          title: l10n.reviewQueueEmpty,
        );
      }
      return SecondSpeakerStepView(
        key: ValueKey<String>('step-$_index'),
        step: step,
        deck: deck,
        card: card,
        onDone: _next,
      );
    }
    final ref = _cards[_index];
    final found = _source?.find(ref);
    final deck = _state.deckById(ref.deckId);
    if (found == null || deck == null) {
      // A card the course no longer has: on to the next.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _next();
      });
      return const SizedBox.shrink();
    }
    final source = _source!;
    final unit = source.unitOf(ref);
    final inUnit = unit == null
        ? const <QueueCardRef>[]
        : source.cardsOf(unit.number);
    final place = unit == null
        ? ''
        : l10n.reviewUnitPlace(
            unit.number,
            inUnit.indexOf(ref) + 1,
            inUnit.length,
          );
    final others = found.deck.others[found.card.id];
    final needs =
        others != null &&
        others.values.any(
          (checks) => checks.isNotEmpty && needsAnotherSpeaker(checks),
        );
    return ReviewCardView(
      key: ValueKey<String>('card-${ref.deckId}-${ref.cardId}'),
      deck: deck,
      card: found.card,
      placeText: place,
      needsAnother: needs,
      onDone: _next,
    );
  }
}

/// The end of a session (frame 1f): a check mark and how many cards, and two
/// buttons, "Continue with all cards" and "Close". Without a pool, "Close"
/// alone.
class _EndView extends StatelessWidget {
  const _EndView({
    required this.count,
    required this.canContinue,
    required this.onContinue,
    required this.onClose,
  });

  final int count;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      key: ReviewFlowPage.endKey,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 24),
      children: <Widget>[
        Semantics(
          container: true,
          label: l10n.reviewEndCount(count),
          excludeSemantics: true,
          child: Column(
            children: <Widget>[
              Icon(Icons.check, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text('$count', style: theme.textTheme.headlineMedium),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (canContinue)
          FilledButton(
            key: ReviewFlowPage.continueKey,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
            onPressed: onContinue,
            child: Text(l10n.reviewEndContinue),
          ),
        const SizedBox(height: 8),
        TextButton(
          key: ReviewFlowPage.endCloseKey,
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(
              const Size.fromHeight(AppSizes.primaryButton),
            ),
          ),
          onPressed: onClose,
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
