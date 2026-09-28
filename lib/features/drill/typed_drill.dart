import 'package:flutter/material.dart' hide Card;

import '../../app/features.dart';
import '../../app/settings.dart';
import '../../core/grading/self_grade.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/answer_field.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/play_button.dart';
import '../../ui/widgets/segmented.dart';
import '../../ui/widgets/target_text.dart';
import 'answer_feedback.dart';
import 'drill_session.dart';
import 'keyboard_hint.dart';

/// Production and listening: a typed answer, graded by `AnswerGrader`.
///
/// - **Production** shows the meaning ("In Spanish?") and takes the target.
///   In a script with a reading it offers typing the transliteration instead
///   (#47, incoming) and, while typing in the script, the keyboard hint.
/// - **Listening** plays the word with the phone's voice, at the learner's
///   rate or 0.7 times it, and takes what was heard.
///
/// Then the feedback: Continue, or for a near miss the learner's own
/// judgement, "Count it wrong" or "I knew it".
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

    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      progress: session.progress,
      onClose: widget.onClose,
      card: listening
          ? _listeningCard(context, card, language)
          : _productionCard(context, card, language),
      belowCard: answer != null
          ? null
          : <Widget>[
              if (session.canTransliterate) _inputModeChoice(context),
              AnswerField(
                controller: _controller,
                label: _fieldLabel(l10n, language, listening, translit),
                language: language,
                latin: translit,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _check(),
              ),
              if (!listening && language.needsReading && !translit)
                KeyboardHint(language: language),
            ],
      feedback: answer == null
          ? null
          : AnswerFeedback(
              answer: answer,
              card: card,
              transliterating: translit,
            ),
      actions: _actions(context, answer),
    );
  }

  List<Widget> _productionCard(
    BuildContext context,
    Card card,
    LanguageInfo language,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answered = _session.answer != null;
    final notes = card.notes;
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
        style: theme.textTheme.displaySmall!.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      if (answered) ...<Widget>[
        TargetText(
          card.target,
          language: language,
          fontSize: 28,
          color: scheme.primary,
        ),
        if (notes != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              notes,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    ];
  }

  List<Widget> _listeningCard(
    BuildContext context,
    Card card,
    LanguageInfo language,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = _session;
    final slower = session.slower;
    return <Widget>[
      PlayButton(onPressed: session.play, playing: session.playing),
      Text(
        session.playing ? l10n.drillPlayingHint : l10n.drillPlayHint,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      FilterChip(
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
      ),
      if (session.answer != null) ...<Widget>[
        TargetText(
          card.target,
          language: language,
          fontSize: 28,
          color: scheme.primary,
        ),
        Text(
          card.native,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    ];
  }

  /// Script or transliteration. Transliteration is #47's, so while it is
  /// incoming the choice is shown dimmed, with its badge.
  Widget _inputModeChoice(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    final language = session.deck.language;
    final incoming = isIncoming(context, Feature.translitInput);
    return IncomingFeature(
      feature: Feature.translitInput,
      label: l10n.drillInputModeGroup,
      badge: IncomingBadgePlacement.below,
      child: Segmented<InputMode>(
        semanticLabel: l10n.drillInputModeGroup,
        height: 44,
        selected: session.transliterating
            ? InputMode.translit
            : InputMode.script,
        onSelected: incoming
            ? null
            : (mode) {
                _controller.clear();
                session.inputMode = mode;
              },
        options: <SegmentOption<InputMode>>[
          SegmentOption<InputMode>(
            value: InputMode.script,
            label: l10n.drillInputScript(language.name),
            leading: TargetText(
              session.deck.glyph,
              language: language,
              fontSize: 16,
            ),
          ),
          SegmentOption<InputMode>(
            value: InputMode.translit,
            label: l10n.drillInputTranslit,
            leading: const Icon(Icons.abc, size: 20),
          ),
        ],
      ),
    );
  }

  String _fieldLabel(
    AppLocalizations l10n,
    LanguageInfo language,
    bool listening,
    bool translit,
  ) {
    if (listening) return l10n.drillTypeHeard;
    if (translit) return l10n.drillTypeLatin(_exampleReading());
    return language.needsReading
        ? l10n.drillTypeInScript(language.name)
        : l10n.drillTypeIn(language.name);
  }

  /// A reading from another card in the deck, to show what typing in Latin
  /// letters looks like without giving this card's answer away.
  String _exampleReading() {
    final current = _session.item.card;
    for (final card in _session.deck.cards) {
      final reading = card.reading;
      if (card.id != current.id && reading != null && reading != '') {
        return reading;
      }
    }
    return '';
  }

  List<Widget> _actions(BuildContext context, TypedAnswer? answer) {
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
