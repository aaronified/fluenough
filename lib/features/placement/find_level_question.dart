import 'dart:async';

import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/grading/answer_grader.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../core/placement/assurance_model.dart';
import '../../core/placement/generated_question.dart';
import '../../core/speech/speech_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';
import '../drill/choice_tile.dart';
import '../drill/rearrange_drill.dart' show rearrangeBoard;
import '../drill/speaking_practice.dart' show unheardMessage;
import 'placement_questions.dart' show PlacementFrame;

/// One question of a Find my level run, drawn in the review's own frame
/// ([PlacementFrame]) from a [GeneratedQuestion]: the options as the
/// review's choice tiles, tiles as its rearrange board, a word said as its
/// speaking drill listens. It says only right or wrong through [onAnswer]
/// and shows no feedback (the run asks checks of its own after a miss, and a
/// learner who saw the answers could not be placed by them).
class FindLevelQuestionView extends StatefulWidget {
  const FindLevelQuestionView({
    super.key,
    required this.question,
    required this.number,
    required this.language,
    required this.native,
    required this.onAnswer,
    required this.onGiveUpMicrophone,
    required this.onListened,
    required this.onSkip,
    this.cardOf,
  });

  final GeneratedQuestion question;

  /// 1 for the first question of the run.
  final int number;

  /// The language learned, as its decks write it.
  final LanguageInfo language;

  /// The language the course is taught from, which the meanings are in.
  final LanguageInfo native;

  /// Whether the learner answered right.
  final ValueChanged<bool> onAnswer;

  /// "I can't speak now".
  final VoidCallback onGiveUpMicrophone;

  /// A listen ended: whether it heard anything. The run counts the listens
  /// that heard nothing across its questions (two in a row give the
  /// microphone up), which a question cannot, as it is drawn anew each time.
  final void Function({required bool heard}) onListened;

  /// The question's sound could not be played, and it is left out (never a
  /// miss).
  final VoidCallback onSkip;

  /// The card [PlacementAudio.cardId] names, so that its recording plays.
  final Card? Function(String id)? cardOf;

  @override
  State<FindLevelQuestionView> createState() => _FindLevelQuestionViewState();
}

class _FindLevelQuestionViewState extends State<FindLevelQuestionView> {
  final List<int> _placed = <int>[];
  bool _listening = false;
  SpeechFailure? _unheard;

  /// The voice failed to play the question: it cannot be answered, so it is
  /// skipped, not marked wrong.
  bool _audioFailed = false;

  GeneratedQuestion get _q => widget.question;

  @override
  void initState() {
    super.initState();
    // A heard question plays as it appears, where speech may start by
    // itself; the Play button plays it again.
    if (_q.audio != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_play()));
    }
  }

  Future<void> _play() async {
    if (!mounted) return;
    final audio = _q.audio;
    if (audio == null) return;
    final state = AppScope.read(context);
    final card = audio.cardId == null
        ? null
        : widget.cardOf?.call(audio.cardId!);
    final failed = await (card != null
        ? state.speakCard(card, widget.language)
        : state.speak(audio.text, widget.language));
    if (!mounted) return;
    if (failed != null || _audioFailed) {
      setState(() => _audioFailed = failed != null);
    }
  }

  // ---------------------------------------------------------------------------
  // What each question shows

  /// Whether the options are words of the language learned, not meanings in
  /// the learner's own language.
  bool get _optionsInTarget =>
      _q.request.kind == PlacementQuestionKind.pair ||
      _q.prompt == PlacementPromptKind.blankSentence ||
      _q.prompt == PlacementPromptKind.sentencePair;

  DrillMode get _mode {
    if (_q.mode == PlacementAnswerMode.say) return DrillMode.speaking;
    if (_q.mode == PlacementAnswerMode.tiles) return DrillMode.production;
    return _q.audio != null ? DrillMode.listening : DrillMode.recognition;
  }

  String _title(AppLocalizations l10n) {
    switch (_q.mode) {
      case PlacementAnswerMode.say:
        return l10n.findLevelSayWord(widget.language.name);
      case PlacementAnswerMode.sayEnglish:
        return _q.audio != null
            ? l10n.findLevelListenSayMeaning(widget.native.name)
            : l10n.findLevelSayMeaning(widget.native.name);
      case PlacementAnswerMode.tiles:
        if (_q.audio != null) return l10n.findLevelBuildFromAudio;
        return _q.request.kind == PlacementQuestionKind.tilesWord
            ? l10n.findLevelBuildWord
            : l10n.findLevelBuildFromMeaning;
      case PlacementAnswerMode.pick:
        return switch (_q.prompt) {
          PlacementPromptKind.blankSentence => l10n.findLevelPickBlank,
          PlacementPromptKind.sentencePair =>
            _q.audio != null
                ? l10n.findLevelWhichSentenceSounds
                : l10n.findLevelWhichSentence,
          PlacementPromptKind.heardWord when _optionsInTarget =>
            l10n.placementHearQuestion,
          PlacementPromptKind.heardWord ||
          PlacementPromptKind.writtenWord => l10n.findLevelWordMeaning,
          _ => l10n.placementQuestion,
        };
    }
  }

  Widget? _shown(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final text = _q.promptText;
    final column = <Widget>[];
    if (text != null && text.isNotEmpty) {
      // A meaning (to be said or built) is in the learner's language; a
      // sentence or word to read is in the language learned.
      column.add(
        _q.prompt == PlacementPromptKind.meaning
            ? Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              )
            : TargetText.hero(text, language: widget.language),
      );
    }
    if (_q.meaningHint case final hint? when hint.isNotEmpty) {
      column.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    if (_q.audio != null) {
      column.add(
        Padding(
          padding: EdgeInsets.only(top: column.isEmpty ? 0 : 12),
          child: OutlinedButton.icon(
            key: const ValueKey<String>('find-level-play'),
            onPressed: _play,
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(l10n.placementHearPlay),
          ),
        ),
      );
    }
    if (column.isEmpty) return null;
    return Column(mainAxisSize: MainAxisSize.min, children: column);
  }

  // ---------------------------------------------------------------------------
  // Answering

  Widget _dontKnow(AppLocalizations l10n) => TextButton(
    key: const ValueKey<String>('find-level-dont-know'),
    onPressed: () => widget.onAnswer(false),
    child: Text(l10n.placementDontKnow),
  );

  List<Widget> _pickChildren(AppLocalizations l10n) => <Widget>[
    Semantics(
      container: true,
      label: l10n.drillOptionsGroup,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (i, option) in _q.options.indexed) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            ChoiceTile(
              key: ValueKey<String>('find-level-option-$i'),
              right: false,
              chosen: false,
              answered: false,
              onTap: () => widget.onAnswer(_q.isRightPick(i)),
              label: (style) => _optionsInTarget
                  ? TargetText.card(
                      option,
                      language: widget.language,
                      fontSize: 22,
                    )
                  : Text(option, style: style),
            ),
          ],
        ],
      ),
    ),
  ];

  bool get _tilesRight {
    final given = <String>[for (final i in _placed) _q.tiles[i]]
        .join(_q.joiner);
    return _q.accepted.any((a) => a.trim() == given.trim());
  }

  List<Widget> _tilesChildren(BuildContext context) => rearrangeBoard(
    context,
    tiles: _q.tiles,
    placed: _placed,
    language: widget.language,
    direction: widget.language.rtl ? TextDirection.rtl : TextDirection.ltr,
    answered: false,
    onPlace: (i) => setState(() {
      if (!_placed.contains(i)) _placed.add(i);
    }),
    onUnplace: (i) => setState(() => _placed.remove(i)),
  );

  Future<void> _listen() async {
    final english = _q.mode == PlacementAnswerMode.sayEnglish;
    setState(() {
      _listening = true;
      _unheard = null;
    });
    final heard = await AppScope.read(context)
        .listenFor(english ? widget.native : widget.language);
    if (!mounted) return;
    if (heard.failed) {
      setState(() {
        _listening = false;
        _unheard = heard.failure ?? SpeechFailure.noMatch;
      });
      widget.onListened(heard: false);
      return;
    }
    setState(() => _listening = false);
    widget.onListened(heard: true);
    final accepted = _q.accepted;
    if (accepted.isEmpty) return widget.onAnswer(false);
    final grader = english
        ? const AnswerGrader(meaning: true)
        : const AnswerGrader(typoDistance: 0, longTypoDistance: 0);
    widget.onAnswer(
      <String>[for (final a in heard.alternatives) a.text].any(
        (h) => grader
            .grade(h, accepted.first, alternates: accepted.sublist(1))
            .outcome
            .isCorrect,
      ),
    );
  }

  List<Widget> _sayChildren(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return <Widget>[
      FilledButton.icon(
        key: const ValueKey<String>('find-level-speak'),
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
              unheardMessage(
                l10n,
                _unheard!,
                _q.mode == PlacementAnswerMode.sayEnglish
                    ? widget.native
                    : widget.language,
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ),
      TextButton.icon(
        key: const ValueKey<String>('find-level-cant-speak'),
        onPressed: _listening ? null : widget.onGiveUpMicrophone,
        icon: const Icon(Icons.mic_off_outlined),
        label: Text(l10n.drillCantSpeak, textAlign: TextAlign.center),
      ),
      _dontKnow(l10n),
    ];
  }

  /// The sound would not play: say so, offer it again (Play) and a way on
  /// that is not a miss. Nothing to answer is shown, as it could only be
  /// guessed.
  Widget _audioFailedFrame(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return PlacementFrame(
      number: widget.number,
      mode: _mode,
      title: Text(_title(l10n)),
      shown: _shown(context),
      actions: <Widget>[
        FilledButton(
          key: const ValueKey<String>('find-level-skip-audio'),
          onPressed: widget.onSkip,
          style: AppButtonStyles.tall(context),
          child: Text(l10n.findLevelSkipQuestion),
        ),
      ],
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.findLevelAudioFailed,
            key: const ValueKey<String>('find-level-audio-failed'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge!.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final saying =
        _q.mode == PlacementAnswerMode.say ||
        _q.mode == PlacementAnswerMode.sayEnglish;
    final tiles = _q.mode == PlacementAnswerMode.tiles;
    if (_audioFailed) return _audioFailedFrame(context, l10n);
    return PlacementFrame(
      number: widget.number,
      mode: _mode,
      title: Text(_title(l10n)),
      shown: _shown(context),
      actions: tiles
          ? <Widget>[
              FilledButton(
                key: const ValueKey<String>('find-level-check'),
                onPressed: _placed.length == _q.tiles.length
                    ? () => widget.onAnswer(_tilesRight)
                    : null,
                style: AppButtonStyles.tall(context),
                child: Text(l10n.placementCheck),
              ),
              _dontKnow(l10n),
            ]
          : saying
          ? const <Widget>[]
          : <Widget>[_dontKnow(l10n)],
      children: tiles
          ? _tilesChildren(context)
          : saying
          ? _sayChildren(context, l10n)
          : _pickChildren(l10n),
    );
  }
}
