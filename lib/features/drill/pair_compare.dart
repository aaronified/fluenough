import 'dart:math' as math;

import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/skill.dart';
import '../../core/grading/pair_match.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../core/speech/speech_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/card_text_scale.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/hint.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/card_blocks.dart';
import '../decks/card_notes.dart';
import '../review/review_words.dart';
import 'speaking_practice.dart' show unheardMessage;

/// The minimal-pair button and its popup (#423, mockup
/// `minimal-pair`; owner, 2026-10-31).
///
/// A card with a pair note shows a Compare button in its "Sounds like
/// another word" block, on the teach card and, once a question is answered,
/// in what the lesson showed again ([PairCompareButton]). It opens a popup
/// that takes over the screen ([showPairCompare]): the two words side by
/// side, each with its reading and meaning and a Play and a Slow button;
/// Say one, where the phone listens and says what it heard and which of the
/// two it matched, never right or wrong; and Which did you hear, where the
/// app plays one at random and the learner taps it.
///
/// It is practice only. Nothing is recorded: no review, no schedule, no
/// strength, no count.

/// A partner a card sounds almost like, which the Compare button names.
typedef PairPartner = ({Card partner, String? care});

/// The word [card] sounds almost like that its Compare button opens, or null
/// when it has none the learner may see: the first of its pair partners
/// (`pair` and pair notes) that a deck has, leaving out a rude word, which
/// has its own warning and is not named without adult content on.
PairPartner? pairPartnerOf(AppState state, Card card) {
  final rude = <String>{
    for (final r in rudeAlikesOf(state, card)) r.partner.id,
  };
  for (final pair in pairsOf(card)) {
    if (rude.contains(pair.id)) continue;
    final partner = findCard(state, pair.id);
    if (partner != null) return (partner: partner, care: pair.care);
  }
  return null;
}

/// The "Compare with ..." button that opens the popup of [card] and
/// [partner]. It shows text, so it carries no hint.
class PairCompareButton extends StatelessWidget {
  const PairCompareButton({
    super.key,
    required this.card,
    required this.partner,
    required this.language,
  });

  final Card card;
  final Card partner;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The reading only while the setting shows readings, as other target text.
    final reading = AppScope.of(context).settings.showRomanisation;
    final label = l10n.pairCompareWith(
      reading ? _wordReading(l10n, partner) : partner.target,
    );
    return OutlinedButton.icon(
      onPressed: () => showPairCompare(
        context,
        card: card,
        partner: partner,
        language: language,
      ),
      icon: const Icon(Icons.compare_arrows),
      label: Text.rich(
        quotingTarget(label, <String>[partner.target], language),
        textAlign: TextAlign.center,
      ),
    );
  }
}

String _wordReading(AppLocalizations l10n, Card card) => card.reading == null
    ? card.target
    : l10n.pairWordReading(card.target, card.reading!);

String _named(AppLocalizations l10n, Card card) => card.reading == null
    ? l10n.cardPartnerNoReading(card.target, card.native)
    : l10n.cardPartner(card.target, card.reading!, card.native);

/// Opens the minimal-pair popup of [card] and [partner]: full screen, in a
/// 3 px border of the theme's colour with rounded corners, and a cross at
/// its top end that closes it. [random] picks the word Which did you hear
/// plays; tests give it a seed.
Future<void> showPairCompare(
  BuildContext context, {
  required Card card,
  required Card partner,
  required LanguageInfo language,
  math.Random? random,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: l10n.pairCompareSounds,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, _) => PairCompare(
      first: card,
      second: partner,
      language: language,
      random: random,
    ),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// The border of the popup: thick enough to read as a popup over the card.
const double pairPopupBorder = 3;

/// The popup's body: see [showPairCompare].
class PairCompare extends StatefulWidget {
  const PairCompare({
    super.key,
    required this.first,
    required this.second,
    required this.language,
    this.random,
  });

  final Card first;
  final Card second;
  final LanguageInfo language;
  final math.Random? random;

  @override
  State<PairCompare> createState() => _PairCompareState();
}

/// Which word the quiz played, and where it is.
enum _QuizPhase { playing, asking, done }

class _Quiz {
  _Quiz(this.target) : phase = _QuizPhase.playing;

  final int target;
  _QuizPhase phase;
  int? picked;
}

class _PairCompareState extends State<PairCompare> {
  late final math.Random _random = widget.random ?? math.Random();
  late AppState _state;

  /// Bumped by each play, so that an older one finishing does not undo a
  /// newer one's state.
  int _call = 0;
  ({int word, bool slow})? _playing;
  bool _speaking = false;

  bool _listening = false;
  PairMatch? _match;
  Card? _heardCard;
  SpeechFailure? _failure;
  bool _declinedOnline = false;

  _Quiz? _quiz;

  List<Card> get _cards => <Card>[widget.first, widget.second];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.read(context);
  }

  @override
  void dispose() {
    if (_speaking) _state.stopSpeaking();
    if (_listening) _state.stopListening();
    super.dispose();
  }

  Future<void> _say(int word, {required bool slow, bool tile = true}) async {
    final call = ++_call;
    if (_speaking) await _state.stopSpeaking();
    if (!mounted || call != _call) return;
    setState(() {
      _speaking = true;
      _playing = tile ? (word: word, slow: slow) : null;
    });
    try {
      await _state.speakCard(_cards[word], widget.language, slower: slow);
    } finally {
      if (mounted && call == _call) {
        setState(() {
          _speaking = false;
          _playing = null;
          final quiz = _quiz;
          if (quiz != null && quiz.phase == _QuizPhase.playing) {
            quiz.phase = _QuizPhase.asking;
          }
        });
      }
    }
  }

  /// Plays a word to guess: a new one at random, or [again] the same.
  void _playQuiz({bool again = false}) {
    final old = _quiz;
    final target = again && old != null ? old.target : _random.nextInt(2);
    setState(() => _quiz = _Quiz(target));
    _say(target, slow: false, tile: false);
  }

  void _pick(int word) {
    final quiz = _quiz;
    if (quiz == null || quiz.phase != _QuizPhase.asking) return;
    setState(() {
      quiz.picked = word;
      quiz.phase = _QuizPhase.done;
    });
  }

  List<String> _spellings(Card card) {
    final shown = _state.targetShown(card, widget.language).text;
    return <String>[
      shown,
      for (final a in card.acceptedAnswers(DrillMode.speaking))
        if (a != shown) a,
    ];
  }

  Future<void> _listen() async {
    if (_listening) {
      await _state.stopListening();
      return;
    }
    if (_speaking) {
      _call++;
      await _state.stopSpeaking();
    }
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _playing = null;
      _listening = true;
      _match = null;
      _heardCard = null;
      _failure = null;
      if (_quiz?.phase == _QuizPhase.playing) _quiz = null;
    });
    final heard = await _state.listenFor(widget.language);
    if (!mounted) return;
    setState(() {
      _listening = false;
      if (heard.failed) {
        _failure = heard.failure ?? SpeechFailure.noMatch;
        return;
      }
      final match = matchPair(
        <HeardReading>[
          for (final a in heard.alternatives)
            (text: a.text, confidence: a.confidence),
        ],
        first: _spellings(widget.first),
        second: _spellings(widget.second),
        articles: widget.language.articles,
      );
      if (match == null) {
        _failure = SpeechFailure.noMatch;
        return;
      }
      _match = match;
      _heardCard = match.side == null
          ? _state.cardSaying(widget.language, match.heard)
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: scheme.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.dialog),
              side: BorderSide(color: scheme.primary, width: pairPopupBorder),
            ),
            child: Semantics(
              container: true,
              label: l10n.pairCompareSounds,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  l10n.pairCompareSounds,
                                  style: theme.textTheme.titleLarge,
                                ),
                                Text(
                                  l10n.pairPracticeOnly,
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.hintClose,
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        12,
                        16,
                        20,
                      ),
                      child: ListenableBuilder(
                        listenable: Listenable.merge(<Listenable>[
                          _state,
                          _state.settings,
                        ]),
                        builder: (context, _) => _content(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = _state.settings;
    final language = widget.language;
    final canPlay = _state.canSpeak(language);
    final banner = !settings.soundOn
        ? l10n.speakerSoundOff
        : !_state.hasVoice(language)
        ? l10n.pairNoVoice(language.name)
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = pairWraps(
          context,
          cards: _cards,
          language: language,
          width: constraints.maxWidth,
        );
        Widget pair(List<Widget> two) => stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: two,
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: <Widget>[for (final w in two) Expanded(child: w)],
                ),
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 20,
          children: <Widget>[
            if (banner != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      banner,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            pair(<Widget>[
              for (var i = 0; i < 2; i++) _tile(context, i, canPlay: canPlay),
            ]),
            if (settings.isEnabled(Skill.speaking)) _sayOne(context),
            _which(context, canPlay: canPlay, pair: pair),
          ],
        );
      },
    );
  }

  Widget _label(String text) => Semantics(
    header: true,
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall!.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _tile(BuildContext context, int i, {required bool canPlay}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = _cards[i];
    final matched = _match?.side == (i == 0 ? PairSide.first : PairSide.second);
    final playing = _playing?.word == i;
    final word = card.reading ?? card.target;
    Widget button(bool slow) {
      final on = playing && _playing!.slow == slow;
      final label = slow ? l10n.pairSlowWord(word) : l10n.pairPlayWord(word);
      final press = canPlay ? () => _say(i, slow: slow) : null;
      // The hint is the tooltip; the screen reader hears which word.
      return Semantics(
        button: true,
        enabled: canPlay,
        label: label,
        excludeSemantics: true,
        onTap: press,
        child: IconButton.filledTonal(
          tooltip: slow ? l10n.hintSlow : l10n.hintPlay,
          isSelected: on,
          icon: Icon(slow ? Icons.slow_motion_video : Icons.play_arrow),
          selectedIcon: const Icon(Icons.graphic_eq),
          style: on
              ? IconButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                )
              : null,
          onPressed: press,
        ),
      );
    }

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.field),
          border: Border.all(
            color: matched || playing ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (matched)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: <Widget>[
                      Icon(Icons.hearing, size: 16, color: scheme.onPrimary),
                      Text(
                        l10n.pairMatchedTag,
                        style: theme.textTheme.labelMedium!.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            TargetText.card(
              card.target,
              language: widget.language,
              fontSize: pairWordSize,
              card: card,
            ),
            if (card.reading != null)
              Text(
                card.reading!,
                textAlign: TextAlign.center,
                style: _readingStyle(theme),
              ),
            Text(
              card.native,
              textAlign: TextAlign.center,
              style: _meaningStyle(theme),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: <Widget>[button(false), button(true)],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sayOne(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.language;
    final status = _state.speechStatus(language);
    final help = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    if (status == SpeechStatus.onlineOnly) {
      if (_declinedOnline) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: <Widget>[
          _label(l10n.pairSayOne),
          Text(l10n.drillOnlineAsk(language.name), style: help),
          FilledButton(
            onPressed: () {
              _state.settings.allowOnlineSpeech(language.code, true);
              _listen();
            },
            child: Text(
              l10n.drillOnlineAllow(language.name),
              textAlign: TextAlign.center,
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() => _declinedOnline = true),
            child: Text(l10n.drillOnlineNotNow, textAlign: TextAlign.center),
          ),
        ],
      );
    }
    final unavailable = switch (status) {
      SpeechStatus.missing => l10n.drillUnheardUnsupported(language.name),
      SpeechStatus.off ||
      SpeechStatus.checking => l10n.drillUnheardNoRecogniser,
      _ => null,
    };
    final failure = _failure;
    final match = _match;
    final Widget? result;
    if (_listening) {
      result = Semantics(
        liveRegion: true,
        child: Text(
          l10n.drillHearingHint,
          textAlign: TextAlign.center,
          style: help,
        ),
      );
    } else if (unavailable != null) {
      result = Text(unavailable, style: _errorStyle(theme));
    } else if (failure != null && failure != SpeechFailure.noMatch) {
      result = Semantics(
        liveRegion: true,
        child: Text(
          unheardMessage(l10n, failure, language),
          style: _errorStyle(theme),
        ),
      );
    } else if (failure != null) {
      result = _heardBox(
        context,
        Text(l10n.drillUnheardNoMatch, style: theme.textTheme.bodyLarge),
      );
    } else if (match != null) {
      result = _heardBox(context, _heard(context, match));
    } else {
      result = null;
    }
    final mic = Center(
      child: _MicrophoneButton(
        listening: _listening,
        onPressed: unavailable != null ? null : _listen,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: <Widget>[
        _label(l10n.pairSayOne),
        if (result == null && unavailable == null)
          Text(l10n.pairSayHelp, style: help),
        mic,
        ?result,
      ],
    );
  }

  Widget _heardBox(BuildContext context, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: child,
      ),
    );
  }

  Widget _heard(BuildContext context, PairMatch match) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.language;
    final side = match.side;
    final Card? known = switch (side) {
      PairSide.first => widget.first,
      PairSide.second => widget.second,
      null => _heardCard,
    };
    final heard = known == null
        ? l10n.pairHeardPlain(match.heard)
        : l10n.pairHeardWord(_named(l10n, known));
    final chip = side == null
        ? l10n.pairMatchedNeither
        : l10n.pairMatchedWord(known!.target);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: <Widget>[
        Text.rich(
          quotingTarget(heard, <String>[
            match.heard,
            if (known != null) known.target,
          ], language),
          style: theme.textTheme.bodyLarge,
        ),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: side == null
                ? scheme.surfaceContainerHighest
                : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Text.rich(
            quotingTarget(
              chip,
              side == null ? const <String>[] : <String>[known!.target],
              language,
            ),
            style: theme.textTheme.labelLarge!.copyWith(
              color: side == null
                  ? scheme.onSurface
                  : scheme.onSecondaryContainer,
            ),
          ),
        ),
        Text(
          l10n.pairCaveat,
          style: theme.textTheme.bodySmall!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _which(
    BuildContext context, {
    required bool canPlay,
    required Widget Function(List<Widget>) pair,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.language;
    final help = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final quiz = _quiz;
    Widget answer(int i) {
      final card = _cards[i];
      final done = quiz?.phase == _QuizPhase.done;
      final good = done && i == quiz!.target;
      final bad = done && i == quiz!.picked && i != quiz.target;
      final color = good
          ? scheme.primary
          : bad
          ? scheme.error
          : scheme.outline;
      return OutlinedButton(
        onPressed: quiz?.phase == _QuizPhase.asking ? () => _pick(i) : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          side: BorderSide(color: color, width: good || bad ? 2 : 1),
          disabledForegroundColor: scheme.onSurface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TargetText.card(
              card.target,
              language: language,
              fontSize: pairAnswerSize,
              color: scheme.onSurface,
              card: card,
            ),
            if (card.reading != null)
              Text(
                card.reading!,
                textAlign: TextAlign.center,
                style: _readingStyle(theme),
              ),
          ],
        ),
      );
    }

    final answers = pair(<Widget>[answer(0), answer(1)]);
    final Widget body;
    if (quiz == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: <Widget>[
          Text(l10n.pairWhichHelp, style: help),
          FilledButton.tonalIcon(
            onPressed: canPlay ? _playQuiz : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.pairPlayOne),
          ),
        ],
      );
    } else if (quiz.phase == _QuizPhase.playing) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Row(
              spacing: 8,
              children: <Widget>[
                Icon(Icons.graphic_eq, color: scheme.primary),
                Expanded(child: Text(l10n.pairPlayingOne, style: help)),
              ],
            ),
          ),
          answers,
        ],
      );
    } else if (quiz.phase == _QuizPhase.asking) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: <Widget>[
          Text(l10n.pairWhichTitle, style: help),
          answers,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Hint(
              message: l10n.hintReplay,
              child: TextButton.icon(
                onPressed: canPlay ? () => _playQuiz(again: true) : null,
                icon: const Icon(Icons.replay),
                label: Text(l10n.pairPlayAgain),
              ),
            ),
          ),
        ],
      );
    } else {
      final target = _cards[quiz.target];
      final picked = _cards[quiz.picked!];
      final right = quiz.picked == quiz.target;
      final text = right
          ? l10n.pairRight(_named(l10n, target))
          : l10n.pairWrong(_named(l10n, target), _wordReading(l10n, picked));
      final color = right ? scheme.primary : scheme.error;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: <Widget>[
          answers,
          // Right or wrong only here, where the app chose the word, in an
          // icon and words as well as colour.
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: <Widget>[
                Icon(right ? Icons.check : Icons.close, color: color),
                Expanded(
                  child: Text.rich(
                    quotingTarget(text, <String>[
                      target.target,
                      if (!right) picked.target,
                    ], language),
                    style: theme.textTheme.bodyLarge!.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: canPlay ? _playQuiz : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.pairPlayAnother),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: <Widget>[_label(l10n.pairWhichTitle), body],
    );
  }

  static TextStyle _errorStyle(ThemeData theme) =>
      theme.textTheme.bodyLarge!.copyWith(color: theme.colorScheme.error);
}

/// The size of a word of the pair, at a card text size of 1.
const double pairWordSize = 32;

/// The size of a word on an answer of Which did you hear, at 1.
const double pairAnswerSize = 24;

TextStyle _readingStyle(ThemeData theme) => theme.textTheme.bodyMedium!
    .copyWith(color: theme.colorScheme.onSurfaceVariant);

TextStyle _meaningStyle(ThemeData theme) =>
    theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurface);

/// Whether any word of the pair would wrap if the two stood side by side in
/// a [width]-wide popup: its script, its reading or its meaning, at the
/// text size the learner has (the app's 1.4x cap included). Then the pair is
/// stacked (owner, 2026-10-31); otherwise it is always side by side.
bool pairWraps(
  BuildContext context, {
  required List<Card> cards,
  required LanguageInfo language,
  required double width,
}) {
  final state = AppScope.read(context);
  final theme = Theme.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final scale = cardTextScaleOf(context, state.settings);
  final family = state.deckDownloads?.fonts.familyFor(language.script);
  // A tile's two sides and its border, and the gap between the tiles.
  const tilePadding = 12 + 12 + 2 * 2;
  final column = (width - 12) / 2 - tilePadding;
  bool wraps(String text, TextStyle style, {Locale? locale}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style, locale: locale),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout(maxWidth: column);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }

  for (final card in cards) {
    final shown = state.targetShown(card, language);
    final script = TextStyle(
      fontSize: pairWordSize * scale,
      fontFamily: family,
      fontWeight: family == null ? FontWeight.w600 : FontWeight.normal,
      fontVariations: family == null
          ? null
          : <FontVariation>[FontVariation.weight(600)],
      height: shown.language.rightToLeft
          ? TargetSizes.rtlHeight
          : TargetSizes.ltrHeight,
    );
    if (wraps(shown.text, script, locale: targetLocale(shown.language))) {
      return true;
    }
    final reading = card.reading;
    if (reading != null && wraps(reading, _readingStyle(theme))) return true;
    if (wraps(card.native, _meaningStyle(theme))) return true;
  }
  return false;
}

/// A large round button with a microphone, a stop button while the phone
/// listens, in the tertiary colour as the speaking drill's is. Greyed out
/// with a null [onPressed].
class _MicrophoneButton extends StatelessWidget {
  const _MicrophoneButton({required this.listening, required this.onPressed});

  final bool listening;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: listening ? l10n.drillStopHearing : l10n.drillSpeak,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: 72,
        child: Material(
          color: !enabled
              ? scheme.surfaceContainerHighest
              : listening
              ? scheme.tertiary
              : scheme.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Hint(
            message: listening ? l10n.hintStop : l10n.hintSpeak,
            child: InkWell(
              onTap: onPressed,
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic,
                size: 36,
                color: !enabled
                    ? scheme.onSurfaceVariant
                    : listening
                    ? scheme.onTertiary
                    : scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
