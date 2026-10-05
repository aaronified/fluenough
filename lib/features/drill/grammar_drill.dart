import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/skill.dart';
import '../../core/grading/answer_grader.dart';
import '../../core/grading/self_grade.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/answer_field.dart';
import '../../ui/widgets/drill_frame.dart';
import '../../ui/widgets/feedback_banner.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/reading_first.dart';
import '../../ui/widgets/speaker.dart';
import '../../ui/widgets/target_text.dart';
import '../gallery/fixtures.dart';
import '../gallery/gallery_entry.dart';
import 'drill_session.dart';
import 'grammar_cells.dart';
import 'input_mode_choice.dart';

/// The deck the fixture drills: the real bundled pattern, read from the
/// catalog.
const String grammarFixtureDeckId = 'es-en-grammar-present-ar';

/// A cell named by its content: the lemma and the slot label.
typedef GrammarPick = ({String lemma, String slot});

/// The cells the fixture asks, in order: the design's three grammar cards.
const List<GrammarPick> grammarFixturePicks = <GrammarPick>[
  (lemma: 'hablar', slot: 'vosotros'),
  (lemma: 'trabajar', slot: 'nosotros'),
  (lemma: 'comprar', slot: 'yo'),
];

/// The grammar drill: the pattern's prompt for one cell, the typed form, and
/// after answering the lemma's whole table, with the asked cell marked, and
/// the pattern's notes.
///
/// Design screen `drill-grammar`. [GrammarDrill.live] drills a session's
/// grammar card (#14): the card is an expanded cell (#2), and the session
/// grades it with `AnswerGrader` as the production drill does, records it,
/// and moves on, and once it is answered the form has its speaker. Behind
/// `Feature.drillGrammar`.
///
/// While the keyboard is open the card is compact, so that it stays in view
/// above the field: a smaller prompt, and the script or Latin letters choice
/// left out until the keyboard closes.
///
/// The unnamed constructor is the gallery's: it runs on [GrammarCell]s
/// shaped from the real pattern of [deckId], picked by [picks], graded
/// locally and not recorded, and disabled and marked while the feature is
/// incoming.
class GrammarDrill extends StatefulWidget {
  const GrammarDrill({
    super.key,
    this.deckId = grammarFixtureDeckId,
    this.picks = grammarFixturePicks,
    this.typed,
    this.check = false,
  }) : session = null,
       onClose = null;

  /// A live session's current grammar card, graded and recorded by
  /// [session]. Build one per card (key it by the card's position).
  const GrammarDrill.live({
    super.key,
    required DrillSession this.session,
    required VoidCallback this.onClose,
  }) : deckId = grammarFixtureDeckId,
       picks = const <GrammarPick>[],
       typed = null,
       check = false;

  /// Null for the gallery's fixture.
  final DrillSession? session;
  final VoidCallback? onClose;

  final String deckId;
  final List<GrammarPick> picks;

  /// Already typed into the field: a gallery preset.
  final String? typed;

  /// Check [typed] straight away: a gallery preset.
  final bool check;

  @override
  State<GrammarDrill> createState() => _GrammarDrillState();
}

typedef _Answer = ({String typed, GradedAnswer? graded});

/// What each button of the foot does: locally for the gallery's fixture,
/// through the session for a live card.
typedef _Moves = ({
  VoidCallback dontKnow,
  VoidCallback check,
  VoidCallback next,
  VoidCallback countWrong,
  VoidCallback knewIt,
});

class _GrammarDrillState extends State<GrammarDrill> {
  static const AnswerGrader _grader = AnswerGrader();

  late final TextEditingController _controller = TextEditingController(
    text: widget.typed,
  );
  late bool _presetCheck = widget.check;
  int _index = 0;

  /// Null while asking; a null `graded` means "Don't know".
  _Answer? _answer;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<GrammarCell> _cells(AppState state) {
    final pattern = state.deckById(widget.deckId)?.deck.pattern;
    if (pattern == null) return const <GrammarCell>[];
    return <GrammarCell>[
      for (final pick in widget.picks)
        ?findGrammarCell(pattern, lemma: pick.lemma, slot: pick.slot),
    ];
  }

  _Answer _grade(GrammarCell cell) => (
    typed: _controller.text,
    graded: _grader.grade(
      _controller.text,
      cell.answer,
      alternates: cell.alternatives,
    ),
  );

  void _check(GrammarCell cell) {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _answer = _grade(cell));
  }

  void _next(int total) {
    if (_index + 1 >= total) {
      Navigator.maybePop(context);
      return;
    }
    setState(() {
      _index++;
      _answer = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session != null) return _live(context, session);

    final state = AppScope.of(context);
    final entry = state.deckById(widget.deckId);
    final cells = _cells(state);
    // The catalog is still loading, or the deck is gone: nothing to ask.
    if (entry == null || cells.isEmpty) return const Scaffold();

    final cell = cells[_index];
    if (_presetCheck) {
      _presetCheck = false;
      if (_controller.text.trim().isNotEmpty) _answer = _grade(cell);
    }
    final total = cells.length;
    return _frame(
      context,
      deck: entry.deck,
      cell: cell,
      position: _index + 1,
      total: total,
      answer: _answer,
      incoming: isIncoming(context, Feature.drillGrammar),
      onClose: () => Navigator.maybePop(context),
      moves: (
        dontKnow: () => setState(() => _answer = (typed: '', graded: null)),
        check: () => _check(cell),
        next: () => _next(total),
        countWrong: () => _next(total),
        knewIt: () => _next(total),
      ),
    );
  }

  /// The session's card, answered through the session.
  Widget _live(BuildContext context, DrillSession session) {
    final deck = session.deck.deck;
    final cell = grammarCellOf(session.item.card, deck);
    // A grammar card always comes from a pattern cell; guard all the same.
    if (cell == null) return const Scaffold();
    final given = session.answer;
    final reading = session.item.card.reading;
    return _frame(
      context,
      deck: deck,
      cell: cell,
      position: session.position,
      total: session.total,
      answer: given == null ? null : (typed: given.typed, graded: given.graded),
      incoming: false,
      inputChoice: session.canTransliterate
          ? InputModeChoice(session: session, onChanged: _controller.clear)
          : null,
      latin: session.transliterating,
      reading: session.transliterating ? reading : null,
      readingFirst: !session.learnsAlphabet,
      speaker: session.canPlay
          ? Speaker(onPlay: session.play, playing: session.playing)
          : null,
      onClose: widget.onClose!,
      moves: (
        dontKnow: session.dontKnow,
        check: () => session.check(_controller.text),
        next: session.next,
        countWrong: () => session.judge(TypoJudgement.countWrong),
        knewIt: () => session.judge(TypoJudgement.knewIt),
      ),
    );
  }

  Widget _frame(
    BuildContext context, {
    required Deck deck,
    required GrammarCell cell,
    required int position,
    required int total,
    required _Answer? answer,
    required bool incoming,
    required VoidCallback onClose,
    required _Moves moves,
    Widget? inputChoice,
    bool latin = false,
    String? reading,
    bool readingFirst = false,
    Widget? speaker,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final language = deck.language;
    // Typing the answer: the keyboard is open, and the field still there.
    final typing = keyboardOpen(context) && answer == null;
    return DrillFrame(
      skill: Skill.grammar,
      deckName: deck.name,
      position: position,
      total: total,
      reportDetail: '${cell.entry.lemma}, ${cell.slot} in ${deck.id}',
      progress: (position - 1 + (answer == null ? 0 : 0.5)) / total,
      onClose: onClose,
      card: _card(
        context,
        cell,
        language,
        answered: answer != null,
        readingFirst: readingFirst,
        typing: typing,
        speaker: speaker,
      ),
      belowCard: answer != null
          ? null
          : <Widget>[
              if (!typing) ?inputChoice,
              // Keyed, so that the field keeps its focus and text as the
              // choice above it comes and goes with the keyboard.
              AnswerField(
                key: const ValueKey<String>('answer'),
                controller: _controller,
                label: l10n.drillTypeSlot(cell.slot),
                language: language,
                latin: latin,
                enabled: !incoming,
                autofocus: !incoming,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (_controller.text.trim().isNotEmpty) moves.check();
                },
              ),
            ],
      feedback: answer == null
          ? null
          : _feedback(
              l10n,
              cell,
              answer,
              reading == null
                  ? cell.answer
                  : l10n.feedbackReadingWithTarget(reading, cell.answer),
            ),
      actions: _actions(context, answer, incoming, moves),
    );
  }

  /// The prompt, the slot and, once answered, the table; with
  /// [readingFirst], for a language learned without its alphabet, the
  /// readings first.
  List<Widget> _card(
    BuildContext context,
    GrammarCell cell,
    LanguageInfo language, {
    required bool answered,
    bool readingFirst = false,
    bool typing = false,
    Widget? speaker,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes = cell.pattern.notes;
    final readingPrompt = readingFirst ? cell.readingPrompt : null;
    final promptSize = typing ? 22.0 : 32.0;
    return <Widget>[
      if (readingPrompt != null)
        ReadingFirst(
          reading: readingPrompt,
          target: cell.prompt,
          language: language,
          fontSize: promptSize,
        )
      else
        TargetText.card(
          cell.prompt,
          language: language,
          fontSize: promptSize,
          fontWeight: FontWeight.w600,
        ),
      Padding(
        padding: EdgeInsetsDirectional.only(top: typing ? 0 : 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            Text(
              cell.pattern.slotName,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                child: TargetText.card(
                  cell.slot,
                  language: language,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
      if (answered) ...<Widget>[
        // Only once answered: hearing the form would give it away.
        ?speaker,
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: _GrammarTable(
            cell: cell,
            language: language,
            readingFirst: readingFirst,
          ),
        ),
        if (notes != null)
          // Padding, not a max-width box: the frame measures the card's
          // intrinsic height, and a ConstrainedBox reports its child's
          // height at the full width, so wrapped notes would overflow.
          // 19 each side is the design's 280 on a phone's 318 card.
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 19),
            child: Text(
              notes,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 15,
                height: 22 / 15,
              ),
            ),
          ),
      ],
    ];
  }

  /// [shown] is the form, or its reading with the form after it when the
  /// answer was typed in Latin letters.
  Widget _feedback(
    AppLocalizations l10n,
    GrammarCell cell,
    _Answer answer,
    String shown,
  ) {
    final graded = answer.graded;
    if (graded == null) {
      return FeedbackBanner(
        kind: FeedbackKind.wrong,
        title: l10n.feedbackGaveUp,
        detail: l10n.feedbackAnswer(shown),
      );
    }
    return switch (graded.outcome) {
      AnswerOutcome.exact => FeedbackBanner(
        kind: FeedbackKind.correct,
        title: l10n.feedbackCorrect,
        detail: shown,
      ),
      AnswerOutcome.closeDiacritics => FeedbackBanner(
        kind: FeedbackKind.close,
        title: l10n.feedbackAccent,
        detail: l10n.feedbackTypedWritten(answer.typed, shown),
      ),
      AnswerOutcome.closeTypo => FeedbackBanner(
        kind: FeedbackKind.nearMiss,
        title: l10n.feedbackTypo(shown),
        detail: l10n.feedbackTypoDetail(answer.typed),
      ),
      AnswerOutcome.wrong => FeedbackBanner(
        kind: FeedbackKind.wrong,
        title: l10n.feedbackWrong,
        detail: l10n.feedbackAnswer(shown),
      ),
    };
  }

  /// The foot, as the production drill draws it. While the feature is
  /// incoming every button is disabled and the whole foot is marked.
  List<Widget> _actions(
    BuildContext context,
    _Answer? answer,
    bool incoming,
    _Moves moves,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    VoidCallback? live(VoidCallback f) => incoming ? null : f;
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

    final Widget foot;
    if (answer == null) {
      final empty = _controller.text.trim().isEmpty;
      foot = Row(
        children: <Widget>[
          Flexible(
            child: OutlinedButton(
              onPressed: live(moves.dontKnow),
              style: outlined,
              child: Text(l10n.drillDontKnow, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: empty ? null : live(moves.check),
              style: filled,
              child: Text(l10n.drillCheck, textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    } else if (answer.graded?.outcome == AnswerOutcome.closeTypo) {
      foot = Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: live(moves.countWrong),
              style: outlined,
              child: Text(l10n.drillCountWrong, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: live(moves.knewIt),
              style: filled,
              child: Text(l10n.drillKnewIt, textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    } else {
      foot = FilledButton(
        onPressed: live(moves.next),
        style: AppButtonStyles.tall(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(child: Text(l10n.commonContinue)),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward, size: 22),
          ],
        ),
      );
    }
    if (!incoming) return <Widget>[foot];
    return <Widget>[
      IncomingFeature(
        feature: Feature.drillGrammar,
        label: l10n.skillGrammar,
        badge: IncomingBadgePlacement.below,
        child: foot,
      ),
    ];
  }
}

/// The lemma's whole row of the pattern, slot by slot, with the asked cell
/// on `primaryContainer` in bold, as the design draws it. The asked row is
/// also marked selected for screen readers, so the colour never stands
/// alone. Slots and forms are deck content, laid out in the deck's direction.
class _GrammarTable extends StatelessWidget {
  const _GrammarTable({
    required this.cell,
    required this.language,
    this.readingFirst = false,
  });

  final GrammarCell cell;
  final LanguageInfo language;

  /// Each form's reading first, then the form, smaller.
  final bool readingFirst;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = cell.table;
    // The design's 240 wide on a phone's 318 card; padding rather than a
    // max width, for the frame's intrinsic measurement (see the notes).
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 39),
      child: Directionality(
        textDirection: language.rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 2),
              _row(scheme, rows[i], asked: i == cell.slotIndex),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    ColorScheme scheme,
    ({String slot, String? form, String? reading}) row, {
    required bool asked,
  }) {
    final fg = asked ? scheme.onPrimaryContainer : scheme.onSurface;
    final weight = asked ? FontWeight.w700 : FontWeight.w400;
    final form = row.form;
    final reading = readingFirst ? row.reading : null;
    return MergeSemantics(
      child: Semantics(
        selected: asked ? true : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: asked ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TargetText.card(
                    row.slot,
                    language: language,
                    fontSize: 15,
                    fontWeight: weight,
                    color: fg,
                    textAlign: TextAlign.start,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: form == null
                      ? Text(
                          '—', // ui-literal-ok: an em dash is not language
                          textAlign: TextAlign.end,
                          style: TextStyle(color: fg),
                        )
                      : reading != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              reading,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: weight,
                                color: fg,
                              ),
                            ),
                            TargetText.card(
                              form,
                              language: language,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: fg,
                              textAlign: TextAlign.end,
                            ),
                          ],
                        )
                      : TargetText.card(
                          form,
                          language: language,
                          fontSize: 15,
                          fontWeight: weight,
                          color: fg,
                          textAlign: TextAlign.end,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The gallery runs the drill as shipped: its feature is on (#14).
AppState _grammarState(AppState app) => GalleryFixtures.state(app);

/// B4's gallery entries for the grammar drill. `drill/gallery_entries.dart`
/// already includes them. The design's state: "hablamos" typed for the
/// vosotros form of hablar, which shows the whole table.
final List<GalleryEntry> grammarGalleryEntries = <GalleryEntry>[
  GalleryEntry(
    id: 'drill-grammar',
    section: GallerySection.drills,
    label: 'Grammar, wrong', // ui-literal-ok: debug-only gallery
    note: 'Shows the whole table', // ui-literal-ok: debug-only gallery
    builder: (_) => const GrammarDrill(typed: 'hablamos', check: true),
    state: _grammarState,
  ),
];

/// More grammar states than the design's Gallery lists. The gallery lists
/// them after the design's screens, and B4's tests pump each one.
final List<GalleryEntry> grammarGalleryStates = <GalleryEntry>[
  GalleryEntry(
    id: 'drill-grammar-prompt',
    section: GallerySection.drills,
    label: 'Grammar, asking', // ui-literal-ok: debug-only gallery
    note:
        'The pattern prompt and the slot', // ui-literal-ok: debug-only gallery
    builder: (_) => const GrammarDrill(),
    state: _grammarState,
  ),
  GalleryEntry(
    id: 'drill-grammar-right',
    section: GallerySection.drills,
    label: 'Grammar, right', // ui-literal-ok: debug-only gallery
    note: 'Correct, with the table and notes', // ui-literal-ok: debug-only gallery
    builder: (_) => const GrammarDrill(typed: 'habláis', check: true),
    state: _grammarState,
  ),
];
