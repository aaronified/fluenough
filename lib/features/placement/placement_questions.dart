import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/placement.dart';
import '../../app/skill.dart';
import '../../core/grading/romanised.dart';
import '../../core/models/card.dart' show tilesOf;
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../core/speech/speech_engine.dart';
import '../../core/tts/speech_gesture.dart';
import '../../l10n/app_localizations.dart';
import '../drill/choice_tile.dart';
import '../drill/rearrange_drill.dart' show rearrangeBoard;
import '../drill/speaking_practice.dart' show unheardMessage;
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/target_text.dart';

/// The parts of a placement question's screen (#481): which question it is,
/// what it shows, what it asks, and the way to answer. Each kind of
/// [PlacementAsk] has its own, answering only right or wrong.
///
/// They sit in the review's own screen, [DrillFrame] (owner, 2026-11-02:
/// placement runs in "the current daily review/revision shell"): the same top
/// bar and progress wave, question card, answer area, feedback and buttons.
///
/// What the page tells every question's frame: how to stop, how far along the
/// walk is, and what to say in a report, which the questions themselves do
/// not know.
class PlacementShell extends InheritedWidget {
  const PlacementShell({
    super.key,
    required this.onClose,
    required this.deckName,
    required this.progress,
    required this.reportDetail,
    this.onSkip,
    required super.child,
  });

  /// The close button: stops placement, keeping what it has found so far.
  final VoidCallback onClose;

  /// What the line above the card names: the deck asked from, or the script
  /// checked.
  final String deckName;

  /// How far along the wave shows, 0–1. Placement has no total, so this only
  /// grows with the questions asked.
  final double progress;
  final String reportDetail;

  /// "Start at the beginning" under the first question of onboarding's
  /// offer: places nothing and goes on. Null where it is not offered.
  final VoidCallback? onSkip;

  static PlacementShell? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlacementShell>();

  @override
  bool updateShouldNotify(PlacementShell old) =>
      onClose != old.onClose ||
      deckName != old.deckName ||
      progress != old.progress ||
      reportDetail != old.reportDetail ||
      onSkip != old.onSkip;
}

/// "Question 3" in the review's header, the [shown] word on the card under
/// [title], the question, and [children], the ways to answer, below it;
/// [feedback] and [actions] at the foot once there are any.
class PlacementFrame extends StatelessWidget {
  const PlacementFrame({
    super.key,
    required this.number,
    required this.title,
    this.shown,
    required this.children,
    this.feedback,
    this.actions = const <Widget>[],
    this.mode = DrillMode.recognition,
    this.going,
  });

  /// How the question goes on once answered: by swipe and the chevron, with
  /// no Continue button (#509). Null for a question that goes on at once.
  final DrillGoing? going;

  /// The question's number, from 1.
  final int number;
  final Widget title;
  final Widget? shown;
  final List<Widget> children;

  /// A `FeedbackBanner`, once the answer is in.
  final Widget? feedback;

  /// The buttons at the foot: "I don't know", or "Check".
  final List<Widget> actions;

  /// The skill the question's pill names: recognising a word, or producing
  /// one.
  final DrillMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final shell = PlacementShell.maybeOf(context);
    return DrillFrame(
      skill: Skill.of(mode),
      deckName: shell?.deckName ?? '',
      position: number,
      total: 0,
      positionLabel: l10n.placementQuestionNumber(number),
      progress: shell?.progress ?? 0,
      going: going,
      reportDetail: shell?.reportDetail,
      onClose: shell?.onClose ?? () => Navigator.of(context).maybePop(),
      card: <Widget>[
        DefaultTextStyle.merge(
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          child: title,
        ),
        ?shown,
      ],
      belowCard: children,
      feedback: feedback,
      actions: <Widget>[
        ...actions,
        // Before an answer only: after one, the swipe is the way on.
        if (shell?.onSkip case final skip? when feedback == null)
          TextButton(
            key: const ValueKey<String>('placement-skip'),
            onPressed: skip,
            child: Text(l10n.placementStartAtBeginning),
          ),
      ],
    );
  }
}

/// "I don't know": the answer is wrong.
class _DontKnow extends StatelessWidget {
  const _DontKnow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    child: Text(AppLocalizations.of(context)!.placementDontKnow),
  );
}

/// A [PlacementQuestion]: its options, one tile each, as the review's choice
/// question draws them. With [feedback], the answer is marked and said, and a
/// swipe or the chevron goes on, as in a review; without, an answer goes on
/// at once, as the script check's questions do.
class PlacementChoice extends StatefulWidget {
  const PlacementChoice({
    super.key,
    required this.question,
    required this.number,
    required this.title,
    required this.shown,
    required this.onAnswer,
    this.feedback = true,
  });

  final PlacementQuestion question;
  final int number;
  final Widget title;
  final Widget shown;
  final ValueChanged<bool> onAnswer;
  final bool feedback;

  @override
  State<PlacementChoice> createState() => _PlacementChoiceState();
}

class _PlacementChoiceState extends State<PlacementChoice> {
  /// What was chosen: an option, or the empty string for "I don't know";
  /// null while unanswered.
  String? _picked;

  void _answer(String picked) {
    final right = widget.question.isRight(picked);
    if (!widget.feedback) return widget.onAnswer(right);
    setState(() => _picked = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final q = widget.question;
    final picked = _picked;
    final answered = picked != null;
    final right = answered && q.isRight(picked);
    return PlacementFrame(
      number: widget.number,
      title: widget.title,
      shown: widget.shown,
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
              detail: l10n.feedbackAnswer(q.answer),
            ),
      going: widget.feedback
          ? DrillGoing(
              onNext: () => widget.onAnswer(right),
              nextOn: answered,
              pinned: true,
            )
          : null,
      actions: answered
          ? const <Widget>[]
          : <Widget>[_DontKnow(onTap: () => _answer(''))],
      children: <Widget>[
        Semantics(
          container: true,
          label: l10n.drillOptionsGroup,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Answered, the right option and, when the learner chose
              // wrong, the one they chose; the others are not shown.
              for (final (place, option) in <String>[
                for (final option in q.options)
                  if (!answered || q.isRight(option) || picked == option)
                    option,
              ].indexed) ...<Widget>[
                if (place > 0) const SizedBox(height: 10),
                ChoiceTile(
                  right: answered && q.isRight(option),
                  chosen: picked == option,
                  answered: answered,
                  onTap: () => _answer(option),
                  label: (style) => Text(option, style: style),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A [TileQuestion]: the sentence's meaning, and its words to put in order,
/// as the review's rearrange question asks it. Check once every word is
/// placed; the feedback says the sentence, and a swipe or the chevron goes
/// on.
class PlacementTiles extends StatefulWidget {
  const PlacementTiles({
    super.key,
    required this.question,
    required this.number,
    required this.spelling,
    required this.language,
    required this.latin,
    required this.onAnswer,
  });

  final TileQuestion question;
  final int number;

  /// The spelling of the card's target the words are put in order in, in
  /// the script the learner reads ([latin] false).
  final String spelling;

  /// The words' language in that script.
  final LanguageInfo language;

  /// Whether the words come in Latin letters, from the card's reading, as
  /// the review's do while typed answers would.
  final bool latin;
  final ValueChanged<bool> onAnswer;

  @override
  State<PlacementTiles> createState() => _PlacementTilesState();
}

class _PlacementTilesState extends State<PlacementTiles> {
  final List<int> _placed = <int>[];

  /// Whether the words were checked: null while they are being placed.
  bool? _right;

  late final List<String> _tiles = widget.latin
      ? widget.question.readingTiles ??
            widget.question.tilesOfSpelling(widget.spelling)
      : widget.question.tilesOfSpelling(widget.spelling);

  bool get _inLatin => widget.latin && widget.question.readingTiles != null;

  void _check() {
    if (_placed.length != _tiles.length) return;
    final given = <String>[for (final i in _placed) _tiles[i]];
    setState(() => _right = widget.question.isRight(given, latin: _inLatin));
  }

  void _giveUp() => setState(() => _right = false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final card = widget.question.card;
    final answered = _right != null;
    final direction = !_inLatin && widget.language.rtl
        ? TextDirection.rtl
        : TextDirection.ltr;
    final reading = card.reading;
    return PlacementFrame(
      number: widget.number,
      mode: DrillMode.production,
      title: Text(l10n.drillRearrangePrompt),
      shown: Text(
        card.native,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineMedium!.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      feedback: switch (_right) {
        null => null,
        true => FeedbackBanner(
          kind: FeedbackKind.correct,
          title: l10n.feedbackCorrect,
        ),
        false => FeedbackBanner(
          kind: FeedbackKind.wrong,
          title: l10n.feedbackWrong,
          detail: l10n.feedbackAnswer(
            _inLatin && reading != null ? reading : widget.spelling,
          ),
          quotes: <String>[if (!_inLatin) widget.spelling],
          language: _inLatin ? null : widget.language,
        ),
      },
      going: DrillGoing(
        onNext: () => widget.onAnswer(_right!),
        nextOn: answered,
        pinned: true,
      ),
      actions: answered
          ? const <Widget>[]
          : <Widget>[
              FilledButton(
                key: const ValueKey<String>('placement-tiles-check'),
                onPressed: _placed.length == _tiles.length ? _check : null,
                style: AppButtonStyles.tall(context),
                child: Text(l10n.drillCheck),
              ),
              _DontKnow(onTap: _giveUp),
            ],
      children: rearrangeBoard(
        context,
        tiles: _tiles,
        placed: _placed,
        language: _inLatin ? null : widget.language,
        direction: direction,
        answered: answered,
        onPlace: (i) => setState(() {
          if (!_placed.contains(i)) _placed.add(i);
        }),
        onUnplace: (i) => setState(() => _placed.remove(i)),
        // Answered, the right order and, when it was wrong, the learner's
        // own, marked wrong (owner, 2026-10-31, doubt 13).
        rightOrder: answered
            ? (_inLatin
                  ? tilesOf(card.reading!)
                  : card.tilesOfSpelling(widget.spelling))
            : null,
        correct: _right,
      ),
    );
  }
}

/// A [MatchQuestion]: letters down one column and what they are down the
/// other. A letter tapped, then an answer, are paired, and numbered alike;
/// tapped again, a paired one is let go. Check once every letter is paired.
class PlacementMatch extends StatefulWidget {
  const PlacementMatch({
    super.key,
    required this.question,
    required this.number,
    required this.language,
    required this.onAnswer,
  });

  final MatchQuestion question;
  final int number;

  /// The letters' language, in their script.
  final LanguageInfo language;
  final ValueChanged<bool> onAnswer;

  @override
  State<PlacementMatch> createState() => _PlacementMatchState();
}

class _PlacementMatchState extends State<PlacementMatch> {
  int? _left;
  final Map<int, int> _pairs = <int, int>{};

  @override
  void didUpdateWidget(PlacementMatch old) {
    super.didUpdateWidget(old);
    if (!identical(old.question, widget.question)) {
      _left = null;
      _pairs.clear();
    }
  }

  void _tapLeft(int i) => setState(() {
    if (_pairs.remove(i) != null) return;
    _left = _left == i ? null : i;
  });

  void _tapRight(int j) => setState(() {
    final left = _left;
    _pairs.removeWhere((_, v) => v == j);
    if (left == null) return;
    _pairs[left] = j;
    _left = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final q = widget.question;
    // A pair's number: the order its letter comes in.
    String? numberOf(int left) =>
        _pairs.containsKey(left) ? '${left + 1}' : null;
    String? numberOfRight(int right) {
      for (final MapEntry(:key, :value) in _pairs.entries) {
        if (value == right) return '${key + 1}';
      }
      return null;
    }

    Widget cell({
      required Key key,
      required Widget child,
      required String? pair,
      required bool selected,
      required VoidCallback onTap,
    }) => OutlinedButton(
      key: key,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? scheme.primaryContainer
            : pair != null
            ? scheme.secondaryContainer
            : null,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        // Symmetric, with room at both ends for the number badge, so the
        // label sits in the middle.
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 28,
          vertical: 12,
        ),
      ),
      onPressed: onTap,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          Center(child: child),
          if (pair != null)
            PositionedDirectional(
              start: -22,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(
                  pair, // ui-literal-ok: a pair's number, not language
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ),
        ],
      ),
    );

    return PlacementFrame(
      number: widget.number,
      title: Text(l10n.placementMatchQuestion),
      children: <Widget>[
        for (final (i, card) in q.cards.indexed)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: cell(
                      key: ValueKey<String>('match-left-$i'),
                      pair: numberOf(i),
                      selected: _left == i,
                      onTap: () => _tapLeft(i),
                      child: TargetText(
                        card.target,
                        language: widget.language,
                        fontSize: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: cell(
                      key: ValueKey<String>('match-right-$i'),
                      pair: numberOfRight(i),
                      selected: false,
                      onTap: () => _tapRight(i),
                      child: Text(q.answers[i], textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _pairs.length == q.cards.length
              ? () => widget.onAnswer(
                  q.isRight(<int, String>{
                    for (final MapEntry(:key, :value) in _pairs.entries)
                      key: q.answers[value],
                  }),
                )
              : null,
          child: Text(l10n.placementCheck),
        ),
        _DontKnow(onTap: () => widget.onAnswer(false)),
      ],
    );
  }
}

/// A [TypeQuestion]: the answer typed, and checked as reviews check it.
class PlacementType extends StatefulWidget {
  const PlacementType({
    super.key,
    required this.question,
    required this.number,
    required this.title,
    this.shown,
    required this.hint,
    required this.romanised,
    this.direction,
    required this.onAnswer,
  });

  final TypeQuestion question;
  final int number;
  final Widget title;
  final Widget? shown;
  final String hint;
  final RomanisedSpelling romanised;

  /// The field's direction, for a word typed in a right-to-left script.
  final TextDirection? direction;
  final ValueChanged<bool> onAnswer;

  @override
  State<PlacementType> createState() => _PlacementTypeState();
}

class _PlacementTypeState extends State<PlacementType> {
  final TextEditingController _typed = TextEditingController();

  @override
  void didUpdateWidget(PlacementType old) {
    super.didUpdateWidget(old);
    if (!identical(old.question, widget.question)) _typed.clear();
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _check() {
    final typed = _typed.text.trim();
    if (typed.isEmpty) return;
    widget.onAnswer(widget.question.isRight(typed, widget.romanised));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlacementFrame(
      number: widget.number,
      mode: DrillMode.production,
      title: widget.title,
      shown: widget.shown,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('placement-answer'),
          controller: _typed,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: widget.direction,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: AppRadii.fieldBorder,
          ),
          onSubmitted: (_) => _check(),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: AppButtonStyles.tall(context),
          onPressed: _typed.text.trim().isEmpty ? null : _check,
          child: Text(l10n.placementCheck),
        ),
        _DontKnow(onTap: () => widget.onAnswer(false)),
      ],
    );
  }
}

/// A [HearQuestion]: the word said once it shows, again on Play again, and
/// the words in its script to choose it from.
class PlacementHear extends StatefulWidget {
  const PlacementHear({
    super.key,
    required this.question,
    required this.number,
    required this.onAnswer,
  });

  final HearQuestion question;
  final int number;
  final ValueChanged<bool> onAnswer;

  @override
  State<PlacementHear> createState() => _PlacementHearState();
}

class _PlacementHearState extends State<PlacementHear> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play(byTap: false));
  }

  @override
  void didUpdateWidget(PlacementHear old) {
    super.didUpdateWidget(old);
    if (!identical(old.question, widget.question)) _play(byTap: false);
  }

  /// Plays the word. Played as the question appears ([byTap] false) it waits,
  /// on iOS Safari, for a first tap that unlocks speech.
  void _play({bool byTap = true}) {
    if (!mounted) return;
    if (byTap) {
      SpeechGesture.app.tapped();
    } else if (!SpeechGesture.app.allowsAutomatic) {
      return;
    }
    final q = widget.question;
    unawaited(AppScope.read(context).speak(q.answer, q.language));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final q = widget.question;
    return PlacementFrame(
      number: widget.number,
      mode: DrillMode.listening,
      title: Text(l10n.placementHearQuestion),
      shown: OutlinedButton.icon(
        onPressed: _play,
        icon: const Icon(Icons.volume_up_outlined),
        label: Text(l10n.placementHearPlay),
      ),
      children: <Widget>[
        for (final option in q.options) ...<Widget>[
          OutlinedButton(
            key: ValueKey<String>('hear-option-$option'),
            onPressed: () => widget.onAnswer(q.isRight(option)),
            child: TargetText(option, language: q.language, fontSize: 24),
          ),
          const SizedBox(height: 8),
        ],
        _DontKnow(onTap: () => widget.onAnswer(false)),
      ],
    );
  }
}

/// A [SayQuestion]: the word, and Speak, which listens for it and grades
/// what the recogniser heard as the speaking drill does.
class PlacementSay extends StatefulWidget {
  const PlacementSay({
    super.key,
    required this.question,
    required this.number,
    required this.onAnswer,
    this.onCantSpeak,
  });

  final SayQuestion question;
  final int number;
  final ValueChanged<bool> onAnswer;

  /// "I can't speak now": skips the question, neither right nor wrong. Null
  /// where it cannot be skipped.
  final VoidCallback? onCantSpeak;

  @override
  State<PlacementSay> createState() => _PlacementSayState();
}

class _PlacementSayState extends State<PlacementSay> {
  bool _listening = false;

  /// Why the last listen gave nothing to grade, or null. A miss is never a
  /// wrong answer, as in the speaking drill: the learner can speak again, or
  /// say they do not know.
  SpeechFailure? _unheard;

  Future<void> _listen() async {
    setState(() {
      _listening = true;
      _unheard = null;
    });
    final heard = await AppScope.read(context)
        .listenFor(widget.question.language);
    if (!mounted) return;
    if (heard.failed) {
      setState(() {
        _listening = false;
        _unheard = heard.failure ?? SpeechFailure.noMatch;
      });
      return;
    }
    setState(() => _listening = false);
    widget.onAnswer(
      widget.question.isRight(<String>[
        for (final a in heard.alternatives) a.text,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final q = widget.question;
    return PlacementFrame(
      number: widget.number,
      mode: DrillMode.speaking,
      title: Text(l10n.placementSayQuestion),
      shown: TargetText.hero(q.shown, language: q.language),
      children: <Widget>[
        FilledButton.icon(
          style: AppButtonStyles.tall(context),
          onPressed: _listening ? null : _listen,
          icon: const Icon(Icons.mic_none),
          label: Text(
            _listening ? l10n.placementSayListening : l10n.placementSayStart,
          ),
        ),
        if (_unheard != null && !_listening)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                unheardMessage(l10n, _unheard!, q.language),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge!
                    .copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        if (widget.onCantSpeak case final skip?)
          TextButton.icon(
            key: const ValueKey<String>('placement-cant-speak'),
            onPressed: _listening ? null : skip,
            icon: const Icon(Icons.mic_off_outlined),
            label: Text(l10n.drillCantSpeak, textAlign: TextAlign.center),
          ),
        _DontKnow(onTap: () => widget.onAnswer(false)),
      ],
    );
  }
}
