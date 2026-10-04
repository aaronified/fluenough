import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/settings.dart';
import '../../core/models/deck.dart';
import '../../core/models/drill_mode.dart';
import '../../core/models/reading.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/ipa_text.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import 'cant_now.dart';
import 'choice_tile.dart';
import 'drill_session.dart';

/// Reading comprehension (#98, ADR-0019): a passage on its own, then its
/// questions one at a time, each answered by a choice that is right or
/// wrong and recorded at once. Then the feedback, with the right answer.
///
/// - **Read**: the passage a sentence at a time, each with its reading when
///   Show romanisation is on and a button to hear it, and a speaker for the
///   whole passage. Each question has its
///   choices, and the passage again under them, to look back at.
/// - **Heard**, a reading question in listening: the passage is read aloud
///   and its text is hidden until the question is answered, as a listening
///   card hides its word. Can't listen now works as it does there.
///
/// Where the passage comes from shows on every one of its screens, small and
/// in full. A passage with a glossary has Words wherever its text shows,
/// which opens the glossary: older words, their form today and meaning.
///
/// The passage is the deck's language, for screen readers too. A question
/// and its choices are in the language the learner speaks best of those it
/// is written in, and read in it.
///
/// No screen in the design draws this. It copies Duolingo Stories
/// (docs/market-research.md, "Stories and dialogues"): the lines with audio,
/// then a question with large choices. Build one per card and per phase.
class ReadingDrill extends StatelessWidget {
  const ReadingDrill({super.key, required this.session, required this.onClose});

  final DrillSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _build(context, settings),
    );
  }

  Widget _build(BuildContext context, SettingsNotifier settings) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final card = session.question!;
    final language = session.deck.language;
    final heard = session.item.mode == DrillMode.listening;
    final text = _PassageText(
      session: session,
      passage: card.passage,
      language: language,
      showReading: settings.showRomanisation,
      canPlay: state.hasVoice(language),
    );
    final source = card.source;

    if (session.showsPassage) {
      return DrillFrame(
        skill: session.skill,
        deckName: session.deck.deck.name,
        position: session.position,
        total: session.total,
        reportDetail: '${session.item.card.id} in ${session.deck.id}',
        progress: session.progress,
        onClose: onClose,
        card: <Widget>[
          _Label(
            heard
                ? l10n.readingListenIntro(session.passageQuestionsLeft)
                : l10n.readingIntro(session.passageQuestionsLeft),
          ),
          _Title(card.passage.title),
          // Read: the whole passage can be heard too, a sentence at a time.
          if (!heard && state.hasVoice(language))
            Speaker(
              onPlay: session.play,
              playing: session.playing && session.playingSentence == null,
              label: l10n.readingPlayPassage,
            ),
          if (heard) ..._listen(context, large: true) else text,
          if (!heard) ?_RomanisationToggle.of(card.passage, settings),
          if (!heard && card.passage.glossary.isNotEmpty)
            _WordsButton(passage: card.passage, language: language),
          if (source != null) _Source(source),
        ],
        actions: <Widget>[
          if (heard) ...<Widget>[
            CantNowButton(session: session),
            const SizedBox(height: 4),
          ],
          FilledButton(
            onPressed: session.toQuestions,
            style: AppButtonStyles.tall(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    l10n.readingToQuestions,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward, size: 22),
              ],
            ),
          ),
        ],
      );
    }

    final question = card.question;
    final shown = session.questionLanguage;
    final choice = session.choice;
    final answered = choice != null;
    return DrillFrame(
      skill: session.skill,
      deckName: session.deck.deck.name,
      position: session.position,
      total: session.total,
      reportDetail: '${session.item.card.id} in ${session.deck.id}',
      progress: session.progress,
      onClose: onClose,
      card: <Widget>[
        _Label(card.passage.title),
        if (question.isTrueFalse) _Label(l10n.readingTrueOrFalse),
        _InLanguage(
          question.prompt[shown]!,
          code: shown,
          style: Theme.of(context).textTheme.headlineSmall!
              .copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        if (source != null) _Source(source),
      ],
      belowCard: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (place, i) in session.choiceOrder.indexed) ...<Widget>[
              if (place > 0) const SizedBox(height: 10),
              ChoiceTile(
                right: answered && question.isRight(i),
                chosen: choice == i,
                answered: answered,
                onTap: () => session.choose(i),
                label: (style) => _InLanguage(
                  _choiceText(l10n, question, i, shown),
                  code: question.isTrueFalse ? null : shown,
                  style: style,
                ),
              ),
            ],
          ],
        ),
        if (heard) _ListenRow(children: _listen(context, large: false)),
        if (session.showsPassageText)
          _PassagePanel(
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.readingPassage,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              text,
              ?_RomanisationToggle.of(card.passage, settings),
              if (card.passage.glossary.isNotEmpty)
                _WordsButton(passage: card.passage, language: language),
            ],
          ),
      ],
      feedback: answered ? _feedback(l10n, question, choice, shown) : null,
      actions: answered
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
          : <Widget>[if (heard) CantNowButton(session: session)],
    );
  }

  /// The play button, its hint, Slower, and that the text is hidden.
  List<Widget> _listen(BuildContext context, {required bool large}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final playing = session.playing && session.playingSentence == null;
    final slower = session.slower;
    final canPlay = AppScope.read(context).hasVoice(session.deck.language);
    return <Widget>[
      // Played as it shows, when words play automatically, on the passage
      // only: not again on each of its questions.
      Speaker(
        onPlay: session.play,
        playing: playing,
        size: large ? 136 : 104,
        label: l10n.readingPlayPassage,
        enabled: canPlay,
        autoplay: large,
      ),
      if (large)
        Text(
          playing ? l10n.drillPlayingHint : l10n.drillPlayHint,
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
      if (!session.showsPassageText)
        Text(
          l10n.readingTextHidden,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
    ];
  }

  static String _choiceText(
    AppLocalizations l10n,
    ReadingQuestion question,
    int i,
    String shown,
  ) => question.isTrueFalse
      ? (i == 0 ? l10n.readingTrue : l10n.readingFalse)
      : question.options[i][shown]!;

  /// Right or wrong, and the right answer either way.
  Widget _feedback(
    AppLocalizations l10n,
    ReadingQuestion question,
    int choice,
    String shown,
  ) {
    final right = question.isRight(choice);
    return FeedbackBanner(
      kind: right ? FeedbackKind.correct : FeedbackKind.wrong,
      title: right ? l10n.feedbackCorrect : l10n.feedbackWrong,
      detail: l10n.feedbackAnswer(
        _choiceText(l10n, question, question.answer, shown),
      ),
    );
  }
}

/// Small text over the card's main line.
/// Show romanisation, on the passage itself: a learner who reads by the
/// romanisation, without the script, can still take the passage as the
/// test of its words and grammar. The same setting as in Settings, so it
/// holds for every passage and the glossary. Only for a passage that has
/// readings.
class _RomanisationToggle extends StatelessWidget {
  const _RomanisationToggle(this.settings);

  static _RomanisationToggle? of(Passage passage, SettingsNotifier settings) =>
      passage.sentences.any((s) => s.reading != null)
      ? _RomanisationToggle(settings)
      : null;

  final SettingsNotifier settings;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FilterChip(
      label: Text(AppLocalizations.of(context)!.settingsRomanisation),
      selected: settings.showRomanisation,
      onSelected: (on) => settings.showRomanisation = on,
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.labelLarge!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The passage's title, in the language the deck is taught from.
class _Title extends StatelessWidget {
  const _Title(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall!
          .copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

/// "Source: …", from the deck file: small, but always there in full.
class _Source extends StatelessWidget {
  const _Source(this.source);

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context)!.readingSource(source),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium!.copyWith(
        fontSize: 13,
        height: 18 / 13,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Text in the learner's language [code], read by screen readers in it when
/// it is not the interface's, as a question shown in Bengali to a learner
/// whose interface is English.
class _InLanguage extends StatelessWidget {
  const _InLanguage(
    this.text, {
    required this.code,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;

  /// The text's language, or null for the interface's.
  final String? code;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final code = this.code;
    final interface = Localizations.localeOf(context).languageCode;
    return Text(
      text,
      textAlign: textAlign,
      style: style,
      locale: code == null || code == interface ? null : Locale(code),
    );
  }
}

/// The passage, a sentence at a time: the text, its reading when Show
/// romanisation is on, its IPA when Show IPA is, and with a voice, a button
/// to hear it.
class _PassageText extends StatelessWidget {
  const _PassageText({
    required this.session,
    required this.passage,
    required this.language,
    required this.showReading,
    required this.canPlay,
  });

  final DrillSession session;
  final Passage passage;
  final LanguageInfo language;
  final bool showReading;
  final bool canPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (i, sentence) in passage.sentences.indexed)
          Padding(
            padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TargetText.card(
                          sentence.text,
                          language: language,
                          fontSize: 22,
                          textAlign: TextAlign.start,
                        ),
                        if (showReading && sentence.reading != null)
                          Text(
                            sentence.reading!,
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        if (ipaToShow(context, sentence.ipa) case final ipa?)
                          IpaText(
                            ipa,
                            fontSize: 14,
                            textAlign: TextAlign.start,
                          ),
                      ],
                    ),
                  ),
                ),
                if (canPlay)
                  SpeakerIcon(
                    onPlay: () => session.playSentence(i),
                    label: l10n.readingPlaySentence,
                    playing: session.playingSentence == i,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The passage under a question's choices, to look back at.
class _PassagePanel extends StatelessWidget {
  const _PassagePanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (i, child) in children.indexed) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          child,
        ],
      ],
    ),
  );
}

/// The play button and Slower, side by side where they fit.
class _ListenRow extends StatelessWidget {
  const _ListenRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 12,
    children: children,
  );
}

/// Words: opens the passage's glossary.
class _WordsButton extends StatelessWidget {
  const _WordsButton({required this.passage, required this.language});

  final Passage passage;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) => Center(
    child: OutlinedButton.icon(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => Glossary(passage: passage, language: language),
      ),
      icon: const Icon(Icons.translate),
      label: Text(
        AppLocalizations.of(context)!.readingWords,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// A passage's glossary: each older or unusual word as the passage writes
/// it, today's form, its reading when Show romanisation is on, its IPA when
/// Show IPA is, its meaning and any note, in the language the learner
/// speaks best of those given.
class Glossary extends StatelessWidget {
  const Glossary({super.key, required this.passage, required this.language});

  final Passage passage;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _build(context, settings),
    );
  }

  Widget _build(BuildContext context, SettingsNotifier settings) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final spoken = settings.spokenLanguages;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.readingWordsTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          for (final entry in passage.glossary) ...<Widget>[
            const SizedBox(height: 16),
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: <Widget>[
                      TargetText(
                        entry.word,
                        language: language,
                        fontSize: 22,
                        textAlign: TextAlign.start,
                      ),
                      // A word still written the same today has no
                      // today's form to point to.
                      if (entry.modern != entry.word) ...<Widget>[
                        Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                          semanticLabel: l10n.readingGlossToday,
                        ),
                        TargetText(
                          entry.modern,
                          language: language,
                          fontSize: 22,
                          textAlign: TextAlign.start,
                        ),
                      ],
                    ],
                  ),
                  if (settings.showRomanisation && entry.reading != null)
                    Text(
                      entry.reading!,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (ipaToShow(context, entry.ipa) case final ipa?)
                    IpaText(ipa, fontSize: 14, textAlign: TextAlign.start),
                  _InLanguage(
                    entry.meaning[bestLanguage(entry.meaning.keys, spoken)]!,
                    code: bestLanguage(entry.meaning.keys, spoken),
                    style: theme.textTheme.bodyLarge!,
                  ),
                  if (entry.note.isNotEmpty)
                    _InLanguage(
                      entry.note[bestLanguage(entry.note.keys, spoken)]!,
                      code: bestLanguage(entry.note.keys, spoken),
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
