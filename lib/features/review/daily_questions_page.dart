import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../core/models/deck.dart';
import '../../core/review/card_fields.dart' show withReading;
import '../../core/review/facets.dart';
import '../../core/review/review_question.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import 'daily_questions.dart';
import 'facet_labels.dart';

/// Opens the daily questions (#519).
Future<void> showDailyQuestions(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/daily-questions'),
        builder: (_) => const DailyQuestionsPage(),
      ),
    );

/// The reason's words, for a reason key of [QuestionKind.reasons].
String reasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
  'wrong' => l10n.reviewReasonWrong,
  'awkward' => l10n.reviewReasonAwkward,
  'unnatural' => l10n.reviewReasonUnnatural,
  'not_real' => l10n.reviewReasonNotReal,
  'wrong_word' => l10n.reviewReasonWrongWord,
  'noisy' => l10n.reviewReasonNoisy,
  'not_native' => l10n.reviewReasonNotNative,
  'not_the_word' => l10n.reviewReasonNotTheWord,
  'unclear' => l10n.reviewReasonUnclear,
  'not_fit' => l10n.reviewReasonNotFit,
  _ => reason,
};

/// The daily questions: one short question about one data point of a card
/// at a time, the weakest data first, answered Yes or No with a tap, put
/// off with Skip. Built in the style of the reviewer mode mockup; the owner
/// asked for no mockup of its own (#519, 2026-10-17). A No, or a flag on a
/// recording, asks why, with fixed reasons and an optional line that goes
/// in the mail only.
///
/// The day's questions are the reviewer's chosen number (default 10); what
/// is not answered waits for the next day. At the end, Send answers opens
/// the mail app with the answers, one file per language.
class DailyQuestionsPage extends StatefulWidget {
  const DailyQuestionsPage({super.key});

  @override
  State<DailyQuestionsPage> createState() => _DailyQuestionsPageState();
}

class _DailyQuestionsPageState extends State<DailyQuestionsPage> {
  /// Today's queue, worked out once when the screen opens, so that what is
  /// asked does not shift under the reviewer's thumb.
  List<ReviewQuestion>? _queue;

  /// The questions answered or put off on this screen, for going on.
  final Set<String> _past = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queue != null) return;
    final state = AppScope.read(context);
    _queue = dailyQuestionsOf(state);
    _readBuilderQuestions(state);
  }

  /// Reads the deck builders' questions again. A card already on screen
  /// never changes under the reviewer's thumb: when there is one, the new
  /// questions are used the next time the screen opens (the file is kept).
  /// Only a screen with nothing to ask is worked out again.
  Future<void> _readBuilderQuestions(AppState state) async {
    final downloads = state.deckDownloads;
    if (downloads == null || !state.reviewing.on) return;
    if (!await downloads.refreshReviewQueue() || !mounted) return;
    if (_queue!.isNotEmpty || _past.isNotEmpty) return;
    setState(() => _queue = dailyQuestionsOf(state));
  }

  LanguageInfo _languageOf(AppState state, String code) => state.languages
      .firstWhere((l) => l.code == code, orElse: () => _plain(code));

  static LanguageInfo _plain(String code) =>
      LanguageInfo(code: code, iso639_3: code, name: code);

  Future<void> _answer(
    ReviewQuestion question,
    QuestionAnswer answer, {
    String? reason,
    String why = '',
  }) async {
    AppScope.read(context).reviewing
        .answerQuestion(question, answer, reason: reason, why: why);
    setState(() => _past.add(question.id));
  }

  Future<void> _no(ReviewQuestion question, QuestionAnswer answer) async {
    final l10n = AppLocalizations.of(context)!;
    final reasons = question.reasons;
    // A question with no reasons (an old builder point that names no facet)
    // takes the No as the answer itself.
    if (reasons.isEmpty) {
      await _answer(question, answer);
      return;
    }
    final facet = question.facet;
    final builder = question.kind == QuestionKind.builder;
    final picked = await showModalBottomSheet<(String?, String)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReasonSheet(
        title: answer == QuestionAnswer.flag
            ? l10n.reviewQuestionWhyFlag
            : l10n.reviewQuestionWhyNo,
        reasons: reasons,
        labelOf: builder && facet != null
            ? (key) => builderOptionLabel(l10n, facet, key)
            : (key) => reasonLabel(l10n, key),
        // A builder question needs exactly one option (the last is Something
        // else); the other kinds take a No without one.
        reasonRequired: builder,
      ),
    );
    if (picked == null || !mounted) return;
    await _answer(question, answer, reason: picked.$1, why: picked.$2);
  }

  /// Sending is Reviews to send's: Send answers only opens it, where the
  /// answers wait with the reviews in the one mail.
  void _send() => AppNavigator.openReviewedNotSent(context).ignore();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewQuestionsTitle)),
      body: ListenableBuilder(
        listenable: state.settings,
        builder: (context, _) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final reviewing = state.reviewing;
    if (!reviewing.on) {
      return EmptyState(
        icon: Icons.rate_review_outlined,
        title: l10n.reviewQuestionsOffTitle,
        body: l10n.reviewQuestionsOnlyReviewers,
      );
    }
    if (reviewing.questionsPerDay == 0) {
      return EmptyState(
        icon: Icons.quiz_outlined,
        title: l10n.reviewQuestionsOffTitle,
        body: l10n.reviewQuestionsOffBody,
      );
    }
    final waiting = reviewing.unsentAnswers.length;
    final left = reviewing.questionsLeftToday;
    final next = left == 0
        ? null
        : _queue!.where((q) => !_past.contains(q.id)).firstOrNull;
    if (next == null) {
      final answeredToday = reviewing.questions.answeredOn(reviewing.today);
      return _Done(
        answered: answeredToday,
        none: answeredToday == 0 && left > 0,
        waiting: waiting,
        decksWaiting: reviewing.unsent.length,
        sending: false,
        onSend: _send,
      );
    }
    final done = reviewing.questions.answeredOn(reviewing.today);
    final remaining = _queue!.where((q) => !_past.contains(q.id)).length;
    final total = done + (left < remaining ? left : remaining);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        16,
        8,
        16,
        24,
      ).clearingSystemBar(context),
      children: <Widget>[
        _Progress(n: done + 1, total: total),
        const SizedBox(height: 16),
        _QuestionCard(
          question: next,
          language: _languageOf(state, next.language),
        ),
        const SizedBox(height: 16),
        _Buttons(
          question: next,
          onAnswer: (answer) => answer == QuestionAnswer.yes
              ? _answer(next, answer)
              : _no(next, answer),
          onSkip: () {
            reviewing.skipQuestion(next);
            setState(() => _past.add(next.id));
          },
        ),
        if (waiting > 0) ...<Widget>[
          const SizedBox(height: 24),
          _SendButton(waiting: waiting, sending: false, onSend: _send),
        ],
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.n, required this.total});

  final int n;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: l10n.reviewQuestionsProgress(n, total),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: <Widget>[
            Text(
              l10n.reviewQuestionsProgress(n, total),
              style: theme.textTheme.labelLarge,
            ),
            LinearProgressIndicator(value: (n - 1) / total),
          ],
        ),
      ),
    );
  }
}

/// The question, and the data point it is about.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.language});

  final ReviewQuestion question;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final word = withReading(question.word, question.reading);
    final prompt = switch (question.kind) {
      QuestionKind.meaning => l10n.reviewQuestionMeaning(word),
      QuestionKind.example => l10n.reviewQuestionExample,
      QuestionKind.confusable => l10n.reviewQuestionConfusable(word),
      QuestionKind.sound => l10n.reviewQuestionSound,
      QuestionKind.image => l10n.reviewQuestionImage(word),
      QuestionKind.builder => builderAskText(l10n, question.facet),
    };
    final about = switch (question.kind) {
      QuestionKind.example => l10n.reviewQuestionExampleFor(word),
      QuestionKind.sound => l10n.reviewQuestionSoundFor(word),
      _ => null,
    };
    final shown = question.shown;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: <Widget>[
            if (question.kind == QuestionKind.builder)
              Text(
                l10n.reviewBuilderQuestion,
                style: theme.textTheme.labelLarge!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            Semantics(
              header: true,
              child: Text(prompt, style: theme.textTheme.titleLarge),
            ),
            if (question.kind == QuestionKind.builder) ...<Widget>[
              _BuilderCard(question: question, language: language),
              // Context only: shown as written, never the question.
              if (question.concern != null)
                Text(
                  l10n.builderAskConcern(question.concern!),
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ] else if (question.kind == QuestionKind.meaning) ...<Widget>[
              TargetText(
                question.word,
                language: language,
                fontSize: 40,
                textAlign: TextAlign.start,
              ),
              if (question.reading != null)
                Text(
                  question.reading!,
                  style: theme.textTheme.titleMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              Text(
                question.meaning ?? '',
                style: theme.textTheme.headlineSmall,
              ),
            ] else if (shown != null) ...<Widget>[
              if (about != null)
                Text(
                  about,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              TargetText(
                shown,
                language: language,
                fontSize: 28,
                textAlign: TextAlign.start,
              ),
              if (question.shownReading != null)
                Text(
                  question.shownReading!,
                  style: theme.textTheme.titleMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (question.shownMeaning != null)
                Text(
                  question.shownMeaning!,
                  style: theme.textTheme.titleMedium,
                ),
            ] else if (about != null)
              Text(about, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// The card a builder question is about, in full: its word, reading, IPA and
/// meaning, its notes, and every example with its reading and translation, so
/// that the reviewer can judge whatever the builder doubts. The facet asked
/// about is marked (for an example with a ref, that one example alone).
class _BuilderCard extends StatelessWidget {
  const _BuilderCard({required this.question, required this.language});

  final ReviewQuestion question;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final facet = question.facet;
    final ref = question.ref;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: <Widget>[
        // What has no part of its own on the card is named, marked.
        if (facet == Facet.unitPlacement ||
            facet == Facet.offenceRating ||
            facet == Facet.audio)
          _Marked(
            child: Text(
              facetTitle(l10n, facet!),
              style: theme.textTheme.labelLarge!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        _Marked(
          on: facet == Facet.word,
          child: TargetText(
            question.word,
            language: language,
            fontSize: 32,
            textAlign: TextAlign.start,
          ),
        ),
        if (question.reading != null)
          _Marked(
            on: facet == Facet.reading,
            child: Text(
              question.reading!,
              style: theme.textTheme.titleMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (question.ipa != null && question.ipa!.trim().isNotEmpty)
          _Marked(
            on: facet == Facet.ipa,
            child: Text(
              question.ipa!,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (question.meaning != null)
          _Marked(
            on: facet == Facet.meaning,
            child: Text(question.meaning!, style: theme.textTheme.titleLarge),
          ),
        if (question.notes.isNotEmpty)
          _Marked(
            on: facet == Facet.note,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: <Widget>[
                for (final note in question.notes)
                  Text(note, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        if (question.examples.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            l10n.reviewBuilderExamples,
            style: theme.textTheme.labelLarge!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          for (final example in question.examples)
            _Marked(
              on:
                  facet == Facet.example &&
                  (ref == null || pointHash(example.target) == ref),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: <Widget>[
                  TargetText(
                    example.target,
                    language: language,
                    fontSize: 22,
                    textAlign: TextAlign.start,
                  ),
                  if (example.reading != null)
                    Text(
                      example.reading!,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (example.native != null)
                    Text(example.native!, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// A part of the card the question is about: a bar on its start edge, so
/// that the mark does not depend on colour contrast of the text, and the
/// part's own semantics unchanged. Not on, the child as it is.
class _Marked extends StatelessWidget {
  const _Marked({required this.child, this.on = true});

  final Widget child;
  final bool on;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: child,
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.question,
    required this.onAnswer,
    required this.onSkip,
  });

  final ReviewQuestion question;
  final void Function(QuestionAnswer answer) onAnswer;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final negative = question.kind.answers.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: <Widget>[
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          ),
          onPressed: () => onAnswer(QuestionAnswer.yes),
          child: Text(
            question.kind == QuestionKind.builder
                ? l10n.builderAskYes
                : l10n.reviewQuestionYes,
          ),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.primaryButton),
          ),
          onPressed: () => onAnswer(negative),
          child: Text(switch (question.kind) {
            QuestionKind.builder => l10n.builderAskNeedsChange,
            _ when negative == QuestionAnswer.flag => l10n.reviewQuestionFlag,
            _ => l10n.reviewQuestionNo,
          }),
        ),
        TextButton(onPressed: onSkip, child: Text(l10n.reviewQuestionSkip)),
      ],
    );
  }
}

/// Why it is not right: one fixed reason, and a line for people.
class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({
    required this.title,
    required this.reasons,
    required this.labelOf,
    this.reasonRequired = false,
  });

  final String title;
  final List<String> reasons;

  /// The words of a reason key.
  final String Function(String key) labelOf;

  /// Whether Save waits for one reason to be picked.
  final bool reasonRequired;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  String? _reason;
  final TextEditingController _why = TextEditingController();

  @override
  void dispose() {
    _why.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop((_reason, _why.text.trim()));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canSave = !widget.reasonRequired || _reason != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(widget.title, style: theme.textTheme.titleLarge),
            ),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value),
              child: Column(
                children: <Widget>[
                  for (final reason in widget.reasons)
                    RadioListTile<String>(
                      value: reason,
                      title: Text(widget.labelOf(reason)),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            TextField(
              controller: _why,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.reviewQuestionWhyHint,
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: canSave ? _save : null,
              child: Text(l10n.reviewQuestionSave),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.waiting,
    required this.sending,
    required this.onSend,
  });

  final int waiting;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.primaryButton),
      ),
      onPressed: waiting == 0 || sending ? null : onSend,
      icon: const Icon(Icons.outbox_outlined),
      label: Text(l10n.reviewQuestionsSend(waiting)),
    );
  }
}

/// The end of the day's questions, or nothing to ask.
class _Done extends StatelessWidget {
  const _Done({
    required this.answered,
    required this.none,
    required this.waiting,
    required this.decksWaiting,
    required this.sending,
    required this.onSend,
  });

  final int answered;

  /// There was no question to ask at all, rather than all of them answered.
  final bool none;
  final int waiting;

  /// Decks with reviews waiting: they go in the same mail.
  final int decksWaiting;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyState(
      icon: none ? Icons.inbox_outlined : Icons.task_alt,
      title: none
          ? l10n.reviewQuestionsNoneTitle
          : l10n.reviewQuestionsDoneTitle,
      body: <String>[
        none
            ? l10n.reviewQuestionsNoneBody
            : l10n.reviewQuestionsDoneBody(answered),
        if (waiting > 0 && decksWaiting > 0)
          l10n.reviewQuestionsSendWith(decksWaiting),
      ].join(' '),
      action: waiting == 0
          ? null
          : _SendButton(waiting: waiting, sending: sending, onSend: onSend),
    );
  }
}
