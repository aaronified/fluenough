import 'package:flutter/material.dart' hide Card;

import '../../app/settings.dart';
import '../../core/grading/self_grade.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/answer_field.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/speaker.dart';
import 'answer_feedback.dart';
import 'cant_now.dart';
import 'drill_session.dart';
import 'input_mode_choice.dart';
import 'keyboard_hint.dart';
import 'taught_details.dart';

/// Production and listening: a typed answer, graded by `AnswerGrader`.
///
/// - **Production** shows the meaning ("In Spanish?") and takes the target.
///   In a script with a reading it offers typing the transliteration instead
///   (#47, incoming) and, while typing in the script, the keyboard hint.
/// - **Listening** plays the word with the phone's voice, at the learner's
///   rate or 0.7 times it, and takes what was heard.
///
/// Production's word has its speaker once the answer is in; before, hearing
/// it would give the answer away. With the answer in, the card also shows
/// what the word's lesson showed: its reading, its meaning, its note and its
/// first example ([TaughtDetails]).
///
/// Then the feedback: Continue, or for a near miss the learner's own
/// judgement, "Count it wrong" or "I knew it".
///
/// While the keyboard is open the card is compact, so that it stays in view
/// above the field: a smaller prompt, and the script or Latin letters choice
/// and Can't listen now left out until the keyboard closes. The mode chosen
/// is kept.
///
/// Design screens `drill-production-accent`, `drill-production-typo`,
/// `drill-production-script`, `drill-production-translit`,
/// `drill-listening` and `drill-rtl`. Build one per card (key it by the
/// card's position), so that the field starts empty.
class TypedDrill extends StatefulWidget {
  const TypedDrill({
    super.key,
    required this.session,
    required this.onClose,
    this.initialText,
  });

  final DrillSession session;
  final VoidCallback onClose;

  /// Already typed into the field: a gallery preset.
  final String? initialText;

  @override
  State<TypedDrill> createState() => _TypedDrillState();
}

class _TypedDrillState extends State<TypedDrill> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  /// The listening card's speaker, kept as the keyboard comes and goes and
  /// the card is laid out again, so that it does not play again.
  final GlobalKey _speaker = GlobalKey();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DrillSession get _session => widget.session;

  void _check() => _session.check(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    final card = session.item.card;
    final language = session.deck.language;
    final listening = session.item.mode == DrillMode.listening;
    final answer = session.answer;
    final translit = session.transliterating;
    // Typing the answer: the keyboard is open, and the field still there.
    final typing = keyboardOpen(context) && answer == null;

    return DrillFrame(
      skill: session.skill,
      deckName: session.recorded || session.revising
          ? session.deck.deck.name
          : l10n.numbersPracticeTitle,
      position: session.position,
      total: session.total,
      reportDetail: '${session.item.card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: widget.onClose,
      needsSound: listening && session.answer == null,
      card: listening
          ? _listeningCard(context, card, language, typing: typing)
          : _productionCard(context, card, language, typing: typing),
      belowCard: answer != null
          ? null
          : <Widget>[
              if (session.canTransliterate && !typing)
                InputModeChoice(session: session, onChanged: _controller.clear),
              // Keyed, so that the field keeps its focus and text as the
              // choice above it comes and goes with the keyboard.
              AnswerField(
                key: const ValueKey<String>('answer'),
                controller: _controller,
                label: _fieldLabel(l10n, language, listening, translit),
                language: language,
                latin: translit,
                digits: session.typesDigits,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _check(),
              ),
              if (!listening && language.needsReading && !translit && !typing)
                KeyboardHint(language: language),
            ],
      feedback: answer == null
          ? null
          : AnswerFeedback(
              answer: answer,
              card: card,
              expected: session.acceptedAnswers.first,
              transliterating: translit,
              language: session.typesDigits || session.hearsMeaning
                  ? null
                  : language,
            ),
      actions: _actions(context, answer, typing: typing),
    );
  }

  List<Widget> _productionCard(
    BuildContext context,
    Card card,
    LanguageInfo language, {
    required bool typing,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answered = _session.answer != null;
    return <Widget>[
      Text(
        l10n.drillAskIn(language.name),
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      Text(
        card.native,
        textAlign: TextAlign.center,
        style:
            (typing
                    ? theme.textTheme.headlineSmall!
                    : theme.textTheme.displaySmall!)
                .copyWith(fontWeight: FontWeight.w600),
      ),
      if (answered)
        // The meaning is the prompt above. Only now: hearing the word would
        // give the answer away.
        TaughtDetails(
          card: card,
          language: language,
          reading: TaughtReading.inReview(_session),
          wordSize: 28,
          wordColor: scheme.primary,
          meaning: false,
          between: _session.canPlay
              ? Speaker(
                  key: const ValueKey<String>('speaker'),
                  onPlay: _session.play,
                  playing: _session.playing,
                )
              : null,
        ),
    ];
  }

  List<Widget> _listeningCard(
    BuildContext context,
    Card card,
    LanguageInfo language, {
    required bool typing,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = _session;
    final slower = session.slower;
    final play = Speaker(
      key: _speaker,
      onPlay: session.play,
      playing: session.playing,
      size: typing ? 64 : 136,
    );
    final slowerChip = FilterChip(
      label: Text(l10n.drillSlower(SettingsNotifier.slowerFactor)),
      selected: slower,
      onSelected: (_) => session.toggleSlower(),
      showCheckmark: false,
      shape: const StadiumBorder(),
      side: slower
          ? BorderSide(color: scheme.secondaryContainer)
          : BorderSide(color: scheme.outline),
      labelStyle: theme.textTheme.labelLarge!.copyWith(
        fontWeight: FontWeight.w600,
        color: slower ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
      ),
    );
    // Typing: the button smaller, beside Slower, and no hint under it.
    if (typing) {
      return <Widget>[
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: <Widget>[play, slowerChip],
        ),
      ];
    }
    return <Widget>[
      play,
      Text(
        session.playing ? l10n.drillPlayingHint : l10n.drillPlayHint,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      slowerChip,
      if (session.answer != null)
        TaughtDetails(
          card: card,
          language: language,
          reading: TaughtReading.inReview(session),
          wordSize: 28,
          wordColor: scheme.primary,
        ),
    ];
  }

  String _fieldLabel(
    AppLocalizations l10n,
    LanguageInfo language,
    bool listening,
    bool translit,
  ) {
    if (_session.typesDigits) return l10n.numbersTypeDigits;
    if (listening) {
      return _session.hearsMeaning
          ? l10n.drillTypeMeaning
          : l10n.drillTypeHeard;
    }
    if (translit) return l10n.drillTypeLatin(_exampleReading());
    return language.needsReading
        ? l10n.drillTypeInScript(language.name)
        : l10n.drillTypeIn(language.name);
  }

  /// A reading from another card in the deck, as it is typed, to show what
  /// typing in Latin letters looks like without giving this card's answer
  /// away.
  String _exampleReading() {
    final current = _session.item.card;
    for (final card in _session.deck.cards) {
      final reading = card.reading;
      if (card.id != current.id && reading != null && reading != '') {
        return _session.asTyped(reading);
      }
    }
    return '';
  }

  List<Widget> _actions(
    BuildContext context,
    TypedAnswer? answer, {
    required bool typing,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final session = _session;
    final outlined = OutlinedButton.styleFrom(
      minimumSize: const Size(64, AppSizes.primaryButton),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      textStyle: theme.textTheme.titleMedium!.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
    final filled = FilledButton.styleFrom(
      minimumSize: const Size(64, AppSizes.primaryButton),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
      textStyle: theme.textTheme.titleMedium!.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );

    if (answer == null) {
      final empty = _controller.text.trim().isEmpty;
      return <Widget>[
        if (session.item.mode == DrillMode.listening && !typing) ...<Widget>[
          CantNowButton(session: session),
          const SizedBox(height: 4),
        ],
        Row(
          children: <Widget>[
            Flexible(
              child: OutlinedButton(
                onPressed: session.dontKnow,
                style: outlined,
                child: Text(l10n.drillDontKnow, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: empty ? null : _check,
                style: filled,
                child: Text(l10n.drillCheck, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ];
    }
    if (answer.awaitsJudgement) {
      return <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => session.judge(TypoJudgement.countWrong),
                style: outlined,
                child: Text(l10n.drillCountWrong, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => session.judge(TypoJudgement.knewIt),
                style: filled.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    theme.textTheme.titleMedium!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                child: Text(l10n.drillKnewIt, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ];
    }
    return <Widget>[
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
    ];
  }
}
