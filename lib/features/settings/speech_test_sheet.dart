import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../core/grading/answer_grader.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../core/speech/speech_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/target_text.dart';
import '../decks/word_sheet.dart' show isRude;
import 'settings_controls.dart';

/// Opens the speaking test for [language].
Future<void> showSpeechTest(BuildContext context, LanguageInfo language) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SpeechTestSheet(language: language),
    );

/// The words of [language]'s course a speaking test offers, in the course's
/// order: its units' word decks, or any of its word decks when it has no
/// path. No script, grammar or number cards, and no rude word: those are
/// never said (docs/plans/offensive-words.md).
List<Card> speechTestWords(AppState state, LanguageInfo language) {
  bool words(DeckEntry deck) =>
      deck.language.code == language.code &&
      !deck.isScript &&
      deck.deck.pattern == null;
  final decks = <DeckEntry>[
    for (final unit in state.courseUnits(language.code))
      for (final deck in unit)
        if (words(deck)) deck,
  ];
  if (decks.isEmpty) decks.addAll(state.decks.where(words));
  final seen = <String>{};
  return <Card>[
    for (final deck in decks)
      for (final card in deck.cards)
        if (!card.practiceOnly && !isRude(card, deck) && seen.add(card.id))
          card,
  ];
}

/// The Voices page's test of the phone's speech recognition in [language]:
/// a word from the course to say, with its reading and meaning, or anything
/// at all; then what the phone heard and, for the word, whether it matches,
/// graded as the speaking drill grades it.
///
/// A failure says why in the drill's words, with the recogniser's own error
/// code in small print for a report (`error_no_match`); the app log has it
/// too (`AppState.listenFor`). Where the language is heard only online and
/// the learner has not allowed it, it asks first, as the drill does.
///
/// A test records nothing. Like a drill's listen, it updates what the app
/// knows about the language: one found not on the device moves to "only
/// online".
class SpeechTestSheet extends StatefulWidget {
  const SpeechTestSheet({
    super.key,
    required this.language,
    this.heard,
    this.heardWord = false,
  });

  final LanguageInfo language;

  /// A listen to show as done, for the gallery: what it heard, and with
  /// [heardWord] whether it was for the word shown rather than anything.
  final SpeechHeard? heard;
  final bool heardWord;

  @override
  State<SpeechTestSheet> createState() => _SpeechTestSheetState();
}

class _SpeechTestSheetState extends State<SpeechTestSheet> {
  late final List<Card> _words = speechTestWords(
    AppScope.read(context),
    widget.language,
  );
  int _index = 0;
  bool _listening = false;

  /// The app a listen is under way in, so that closing the sheet can stop
  /// it: the microphone is not left on until the recogniser gives up.
  AppState? _hearing;

  /// What the last listen gave, or null before one.
  late SpeechHeard? _heard = widget.heard;

  /// The word the last listen was for, or null for "anything".
  late Card? _for = widget.heardWord ? _word : null;

  Card? get _word => _words.isEmpty ? null : _words[_index % _words.length];

  Future<void> _listen(Card? word) async {
    if (_listening) return;
    final state = _hearing = AppScope.read(context);
    setState(() {
      _listening = true;
      _heard = null;
      _for = word;
    });
    final heard = await state.listenFor(widget.language);
    _hearing = null;
    if (!mounted) return;
    setState(() {
      _listening = false;
      _heard = heard;
    });
  }

  @override
  void dispose() {
    _hearing?.stopListening();
    super.dispose();
  }

  /// Whether what was heard is [word], as the speaking drill grades it: its
  /// best reading, or another the recogniser was fairly sure of.
  bool _matches(Card word, List<SpeechAlternative> heard) {
    final accepted = word.acceptedAnswers(DrillMode.speaking);
    final grader = AnswerGrader(
      articles: widget.language.articles,
      typoDistance: 0,
      longTypoDistance: 0,
    );
    for (final (i, alternative) in heard.indexed) {
      final confidence = alternative.confidence;
      if (i > 0 && (confidence == null || confidence < 0.5)) continue;
      final graded = grader.grade(
        alternative.text,
        accepted.first,
        alternates: accepted.sublist(1),
      );
      if (graded.outcome.isCorrect) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.language;
    final word = _word;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.voicesSayLabel(language.name),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Text(l10n.voicesSayIntro, style: muted),
              if (word != null) ...<Widget>[
                const SizedBox(height: 20),
                MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TargetText(word.target, language: language, fontSize: 36),
                      if (word.reading case final reading?)
                        Text(
                          reading,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        word.native,
                        textAlign: TextAlign.center,
                        style: muted,
                      ),
                    ],
                  ),
                ),
                if (_words.length > 1)
                  Center(
                    child: TextButton.icon(
                      onPressed: _listening
                          ? null
                          : () => setState(() {
                              _index++;
                              _heard = null;
                            }),
                      icon: const Icon(Icons.shuffle),
                      label: Text(l10n.voicesAnotherWord),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              if (_listening) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.drillHearingHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: AppScope.read(context).stopListening,
                  icon: const Icon(Icons.stop),
                  label: Text(l10n.drillStopHearing),
                ),
              ] else
                // Two equal halves, 8 px apart, on the title's edges; stacked
                // only when a label does not fit its half on one line
                // (#846, owner, 2026-10-25).
                _halves(context, <(Widget, String)>[
                  if (word != null)
                    (
                      FilledButton.icon(
                        onPressed: () => _listen(word),
                        icon: const Icon(Icons.mic_none),
                        label: Text(l10n.voicesSayWord),
                      ),
                      l10n.voicesSayWord,
                    ),
                  (
                    OutlinedButton.icon(
                      onPressed: () => _listen(null),
                      icon: const Icon(Icons.record_voice_over_outlined),
                      label: Text(l10n.voicesSayAnything),
                    ),
                    l10n.voicesSayAnything,
                  ),
                ]),
              if (!_listening && _heard != null) ...<Widget>[
                const SizedBox(height: 20),
                _result(context, _heard!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// [buttons] in a row of equal halves, or one above the other when a
  /// label, with its icon and padding, does not fit its half on one line.
  Widget _halves(BuildContext context, List<(Widget, String)> buttons) {
    final style = Theme.of(context).textTheme.labelLarge!;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        // The icon (18), its gap (8) and the button's padding (16 + 24).
        const chrome = 66.0;
        final half =
            (box.maxWidth - gap * (buttons.length - 1)) / buttons.length;
        var fits = true;
        for (final (_, label) in buttons) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          if (painter.width + chrome > half) fits = false;
          painter.dispose();
        }
        if (!fits || buttons.length == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: <Widget>[for (final (button, _) in buttons) button],
          );
        }
        return Row(
          spacing: gap,
          children: <Widget>[
            for (final (button, _) in buttons) Expanded(child: button),
          ],
        );
      },
    );
  }

  /// What came of the last listen.
  Widget _result(BuildContext context, SpeechHeard heard) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = widget.language;
    if (!heard.failed) {
      final best = heard.alternatives.first.text;
      final word = _for;
      final match = word != null && _matches(word, heard.alternatives);
      return Semantics(
        liveRegion: true,
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: <Widget>[
              Text.rich(
                TextSpan(
                  text: l10n.voicesHeard(best),
                  locale: Locale(language.code),
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (word != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      match ? Icons.check_circle_outline : Icons.highlight_off,
                      size: 20,
                      color: match ? scheme.primary : scheme.error,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        match ? l10n.voicesHeardMatch : l10n.voicesHeardNoMatch,
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: match ? scheme.primary : scheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }
    final failure = heard.failure ?? SpeechFailure.noMatch;
    if (failure == SpeechFailure.notOnDevice) return _askOnline(context);
    final why = switch (failure) {
      SpeechFailure.noMatch => l10n.drillUnheardNoMatch,
      SpeechFailure.permissionDenied => l10n.drillUnheardPermission,
      SpeechFailure.noRecogniser => l10n.drillUnheardNoRecogniser,
      SpeechFailure.unsupported => l10n.drillUnheardUnsupported(language.name),
      SpeechFailure.network => l10n.drillUnheardNetwork,
      SpeechFailure.notOnDevice ||
      SpeechFailure.other => l10n.drillUnheardOther,
    };
    return Semantics(
      liveRegion: true,
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: <Widget>[
            Text(
              why,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(color: scheme.error),
            ),
            Text(
              l10n.voicesErrorCode(heard.code ?? failure.name),
              textAlign: TextAlign.center,
              style: settingsHelpStyle(theme),
            ),
          ],
        ),
      ),
    );
  }

  /// The phone cannot recognise the language by itself: going online is
  /// the learner's choice, asked as the drill asks it.
  Widget _askOnline(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = widget.language;
    final settings = AppScope.read(context).settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.drillOnlineAsk(language.name),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            settings.allowOnlineSpeech(language.code, true);
            _listen(_for);
          },
          child: Text(
            l10n.drillOnlineAllow(language.name),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => setState(() => _heard = null),
          child: Text(l10n.drillOnlineNotNow, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
