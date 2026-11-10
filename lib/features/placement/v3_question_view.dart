import 'dart:async';

import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../core/placement/item_registry.dart'
    show baseFormat, isSpokenEnglish;
import '../../core/placement/v3_session.dart';
import '../../core/speech/speech_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/target_text.dart';
import '../drill/choice_tile.dart';
import '../drill/rearrange_drill.dart' show rearrangeBoard;
import '../drill/speaking_practice.dart' show unheardMessage;
import 'online_speech_ask.dart';
import 'placement_questions.dart' show PlacementFrame;

/// One question of a V3 Find my level run (wiki/Plan-Placement-V3.md, step 7),
/// drawn in the review's own frame ([PlacementFrame]) from a [V3Question]:
/// picks as the review's choice tiles, tiles as its rearrange board, a word
/// typed in a field, yes/no as two buttons, a word said as the speaking drill
/// listens. It reports the learner's answer to the run and shows no feedback:
/// a learner who saw the answers could not be placed by them.
class V3QuestionView extends StatefulWidget {
  const V3QuestionView({
    super.key,
    required this.question,
    required this.number,
    required this.language,
    required this.native,
    required this.run,
    required this.onChanged,
    required this.onListened,
    this.cardOf,
  });

  final V3Question question;
  final int number;
  final LanguageInfo language;
  final LanguageInfo native;

  /// The run the answers go to.
  final V3Run run;

  /// Told after an answer, a skip or a microphone change (the page saves and
  /// redraws).
  final VoidCallback onChanged;

  /// A listen ended: whether it heard anything. Two in a row, over the whole
  /// run, give the microphone up.
  final void Function({required bool heard}) onListened;

  final Card? Function(String id)? cardOf;

  @override
  State<V3QuestionView> createState() => _V3QuestionViewState();
}

class _V3QuestionViewState extends State<V3QuestionView> {
  final List<int> _placed = <int>[];
  final TextEditingController _typed = TextEditingController();
  bool _listening = false;
  SpeechFailure? _unheard;

  /// The voice failed to play the question: it cannot be answered, so it is
  /// skipped, not marked wrong.
  bool _audioFailed = false;

  V3Question get _q => widget.question;
  V3Run get _run => widget.run;

  @override
  void initState() {
    super.initState();
    // A heard question plays as it appears; the Play button plays it again.
    if (_spokenText != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_play()));
    }
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  /// What the phone says: the target text of a heard question, or the
  /// English meaning of a reverse one (in the learner's own language).
  String? get _spokenText =>
      isSpokenEnglish(_q.format) ? _q.shown : _q.audio;

  Future<void> _play() async {
    if (!mounted) return;
    final text = _spokenText;
    if (text == null) return;
    final state = AppScope.read(context);
    final cardId = _q.item?.cardId;
    final card = cardId == null ? null : widget.cardOf?.call(cardId);
    // A word is played from its card's recording where it has one; a
    // sentence, a letter or a pseudoword by the voice.
    final useCard =
        card != null && _q.format != 'F14' && !isSpokenEnglish(_q.format);
    final failed = await (useCard
        ? state.speakCard(card, widget.language)
        : state.speak(
            text,
            isSpokenEnglish(_q.format) ? widget.native : widget.language,
          ));
    if (!mounted) return;
    if (failed != null || _audioFailed) {
      setState(() => _audioFailed = failed != null);
    }
  }

  void _done(void Function() answer) {
    setState(answer);
    widget.onChanged();
  }

  // ---------------------------------------------------------------- headings

  DrillMode get _drillMode => switch (_q.mode) {
    V3Mode.say || V3Mode.rateSay => DrillMode.speaking,
    V3Mode.tiles || V3Mode.type || V3Mode.gap => DrillMode.production,
    _ => _q.isHeard ? DrillMode.listening : DrillMode.recognition,
  };

  String _title(AppLocalizations l10n) {
    final name = widget.language.name;
    if (_q.script) {
      return _q.isHeard
          ? l10n.findLevelScriptWhichLetter
          : l10n.findLevelScriptWhichSound;
    }
    switch (_q.mode) {
      case V3Mode.say:
        return l10n.findLevelSayWord(name);
      case V3Mode.rateSay:
        return l10n.findLevelRateSay(name);
      case V3Mode.type:
        return l10n.findLevelTypeWord(name);
      case V3Mode.gap:
        return l10n.findLevelFillGap;
      case V3Mode.yesNo:
        return _q.isHeard ? l10n.findLevelHeardYesNo : l10n.findLevelYesNo;
      case V3Mode.tiles:
        return baseFormat(_q.format) == 'F4'
            ? l10n.findLevelBuildWord
            : l10n.findLevelBuildFromMeaning;
      case V3Mode.pick:
        return switch (baseFormat(_q.format)) {
          'F3' => l10n.placementQuestion,
          'F5' => l10n.findLevelWhichSentence,
          'F17' => l10n.findLevelWhichSentenceSounds,
          _ => l10n.findLevelWordMeaning,
        };
    }
  }

  Widget? _shown(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final text = _q.shown;
    final column = <Widget>[];
    if (text != null && text.isNotEmpty) {
      column.add(
        _q.shownIsTarget
            ? TargetText.hero(text, language: widget.language)
            : Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
      );
    }
    if (_q.mode == V3Mode.gap) {
      column.add(
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: TargetText.hero(
            '${_q.gapBefore}＿${_q.gapAfter}',
            language: widget.language,
          ),
        ),
      );
    }
    if (_spokenText != null) {
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

  // ----------------------------------------------------------------- answers

  Widget _dontKnow(AppLocalizations l10n) => TextButton(
    key: const ValueKey<String>('find-level-dont-know'),
    onPressed: () => _done(_run.dontKnow),
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
              onTap: () => _done(() => _run.answerPick(i)),
              label: (style) => _q.optionsAreTarget
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

  void _check() {
    final text = _typed.text.trim();
    if (text.isEmpty) return;
    _done(() => _run.answerTyped(text));
  }

  List<Widget> _typeChildren(AppLocalizations l10n) => <Widget>[
    TextField(
      key: const ValueKey<String>('find-level-answer'),
      controller: _typed,
      autocorrect: false,
      enableSuggestions: false,
      textDirection: widget.language.rtl ? TextDirection.rtl : null,
      decoration: InputDecoration(
        hintText: _q.mode == V3Mode.gap
            ? l10n.findLevelGapHint
            : l10n.findLevelTypeHint,
        border: AppRadii.fieldBorder,
      ),
      onSubmitted: (_) => _check(),
      onChanged: (_) => setState(() {}),
    ),
  ];

  List<Widget> _yesNoChildren(AppLocalizations l10n) => <Widget>[
    FilledButton(
      key: const ValueKey<String>('find-level-yes'),
      style: AppButtonStyles.tall(context),
      onPressed: () => _done(() => _run.answerYesNo(yes: true)),
      child: Text(l10n.findLevelYes),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      key: const ValueKey<String>('find-level-no'),
      style: AppButtonStyles.tall(context),
      onPressed: () => _done(() => _run.answerYesNo(yes: false)),
      child: Text(l10n.findLevelNo),
    ),
  ];

  List<Widget> _rateChildren(AppLocalizations l10n) => <Widget>[
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        l10n.findLevelRateSayBody,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
    FilledButton(
      key: const ValueKey<String>('find-level-said-well'),
      style: AppButtonStyles.tall(context),
      onPressed: () => _done(() => _run.answerRated(good: true)),
      child: Text(l10n.findLevelSaidWell),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      key: const ValueKey<String>('find-level-said-not'),
      style: AppButtonStyles.tall(context),
      onPressed: () => _done(() => _run.answerRated(good: false)),
      child: Text(l10n.findLevelSaidNot),
    ),
  ];

  Future<void> _listen() async {
    setState(() {
      _listening = true;
      _unheard = null;
    });
    final heard = await AppScope.read(context).listenFor(widget.language);
    if (!mounted) return;
    if (heard.failed) {
      setState(() {
        _listening = false;
        _unheard = heard.failure ?? SpeechFailure.noMatch;
      });
      // Not being allowed yet is not a miss: the ask is shown instead.
      if (_unheard != SpeechFailure.notOnDevice) {
        widget.onListened(heard: false);
      }
      return;
    }
    setState(() => _listening = false);
    widget.onListened(heard: true);
    _done(
      () =>
          _run.answerSaid(<String>[for (final a in heard.alternatives) a.text]),
    );
  }

  void _giveUpMicrophone() => _done(_run.giveUpMicrophone);

  List<Widget> _sayChildren(AppLocalizations l10n) {
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
      if (_unheard == SpeechFailure.notOnDevice && !_listening)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: OnlineSpeechAsk(
            language: widget.language,
            onAllowed: _listen,
            onDeclined: _giveUpMicrophone,
          ),
        )
      else if (_unheard != null && !_listening)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              unheardMessage(l10n, _unheard!, widget.language),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ),
      TextButton.icon(
        key: const ValueKey<String>('find-level-cant-speak'),
        onPressed: _listening ? null : _giveUpMicrophone,
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
      mode: _drillMode,
      title: Text(_title(l10n)),
      shown: _shown(context),
      actions: <Widget>[
        FilledButton(
          key: const ValueKey<String>('find-level-skip-audio'),
          onPressed: () => _done(_run.skipUnplayable),
          style: AppButtonStyles.tall(context),
          child: Text(l10n.findLevelSkipQuestion),
        ),
        // The sound failed again and again: Hear and Say are left out, and
        // the run goes on with the rest.
        if (_run.offerNoSound)
          OutlinedButton(
            key: const ValueKey<String>('find-level-no-sound'),
            onPressed: () => _done(_run.dropAudio),
            style: AppButtonStyles.tall(context),
            child: Text(l10n.findLevelCarryOnNoSound),
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
    if (_audioFailed) return _audioFailedFrame(context, l10n);
    final List<Widget> actions = switch (_q.mode) {
      V3Mode.tiles => <Widget>[
        FilledButton(
          key: const ValueKey<String>('find-level-check'),
          // The decoy tiles are never placed: Check waits for some tile.
          onPressed: _placed.isNotEmpty
              ? () => _done(() => _run.answerTiles(List<int>.of(_placed)))
              : null,
          style: AppButtonStyles.tall(context),
          child: Text(l10n.placementCheck),
        ),
        _dontKnow(l10n),
      ],
      V3Mode.type || V3Mode.gap => <Widget>[
        FilledButton(
          key: const ValueKey<String>('find-level-check'),
          onPressed: _typed.text.trim().isEmpty ? null : _check,
          style: AppButtonStyles.tall(context),
          child: Text(l10n.placementCheck),
        ),
        _dontKnow(l10n),
      ],
      V3Mode.say => const <Widget>[],
      V3Mode.rateSay => <Widget>[_dontKnow(l10n)],
      V3Mode.yesNo => <Widget>[_dontKnow(l10n)],
      V3Mode.pick => <Widget>[_dontKnow(l10n)],
    };
    return PlacementFrame(
      number: widget.number,
      mode: _drillMode,
      title: Text(_title(l10n)),
      shown: _shown(context),
      actions: actions,
      children: switch (_q.mode) {
        V3Mode.tiles => _tilesChildren(context),
        V3Mode.type || V3Mode.gap => _typeChildren(l10n),
        V3Mode.yesNo => _yesNoChildren(l10n),
        V3Mode.say => _sayChildren(l10n),
        V3Mode.rateSay => _rateChildren(l10n),
        V3Mode.pick => _pickChildren(l10n),
      },
    );
  }
}
