import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/placement.dart';
import '../../core/grading/romanised.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';

/// The parts of a placement question's screen (#481): which question it is,
/// what it shows, what it asks, and the way to answer. Each kind of
/// [PlacementAsk] has its own, answering only right or wrong.

/// "Question 3", the [shown] word in its box, and [title], the question,
/// above [children], the ways to answer.
class PlacementFrame extends StatelessWidget {
  const PlacementFrame({
    super.key,
    required this.number,
    required this.title,
    this.shown,
    required this.children,
  });

  /// The question's number, from 1.
  final int number;
  final Widget title;
  final Widget? shown;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
      children: <Widget>[
        Text(
          l10n.placementQuestionNumber(number),
          style: theme.textTheme.labelLarge!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (shown case final shown?) ...<Widget>[
          Container(
            constraints: const BoxConstraints(minHeight: 160),
            alignment: Alignment.center,
            padding: const EdgeInsetsDirectional.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: shown,
          ),
          const SizedBox(height: 16),
        ],
        DefaultTextStyle.merge(
          style: theme.textTheme.titleMedium,
          child: title,
        ),
        const SizedBox(height: 12),
        ...children,
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

/// A [PlacementQuestion]: its options, one button each, [option] drawing
/// each where they are words in a script.
class PlacementChoice extends StatelessWidget {
  const PlacementChoice({
    super.key,
    required this.question,
    required this.number,
    required this.title,
    required this.shown,
    required this.onAnswer,
  });

  final PlacementQuestion question;
  final int number;
  final Widget title;
  final Widget shown;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) => PlacementFrame(
    number: number,
    title: title,
    shown: shown,
    children: <Widget>[
      for (final option in question.options) ...<Widget>[
        OutlinedButton(
          onPressed: () => onAnswer(question.isRight(option)),
          child: Text(option, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
      ],
      _DontKnow(onTap: () => onAnswer(false)),
    ],
  );
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
    }) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: OutlinedButton(
        key: key,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? scheme.primaryContainer
              : pair != null
              ? scheme.secondaryContainer
              : null,
          minimumSize: const Size.fromHeight(56),
        ),
        onPressed: onTap,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: pair == null
                  ? null
                  : Text(
                      pair, // ui-literal-ok: a pair's number, not language
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
            ),
            Expanded(child: Center(child: child)),
          ],
        ),
      ),
    );

    return PlacementFrame(
      number: widget.number,
      title: Text(l10n.placementMatchQuestion),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  for (final (i, card) in q.cards.indexed)
                    cell(
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
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: <Widget>[
                  for (final (j, answer) in q.answers.indexed)
                    cell(
                      key: ValueKey<String>('match-right-$j'),
                      pair: numberOfRight(j),
                      selected: false,
                      onTap: () => _tapRight(j),
                      child: Text(answer, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),
          ],
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
            border: const OutlineInputBorder(),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(PlacementHear old) {
    super.didUpdateWidget(old);
    if (!identical(old.question, widget.question)) _play();
  }

  void _play() {
    if (!mounted) return;
    final q = widget.question;
    unawaited(AppScope.read(context).speak(q.answer, q.language));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final q = widget.question;
    return PlacementFrame(
      number: widget.number,
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
  });

  final SayQuestion question;
  final int number;
  final ValueChanged<bool> onAnswer;

  @override
  State<PlacementSay> createState() => _PlacementSayState();
}

class _PlacementSayState extends State<PlacementSay> {
  bool _listening = false;

  Future<void> _listen() async {
    setState(() => _listening = true);
    final heard = await AppScope.read(context)
        .listenFor(widget.question.language);
    if (!mounted) return;
    setState(() => _listening = false);
    widget.onAnswer(
      !heard.failed &&
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
        _DontKnow(onTap: () => widget.onAnswer(false)),
      ],
    );
  }
}
