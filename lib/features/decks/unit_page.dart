import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../app/shell_tab.dart';
import '../../app/session.dart';
import '../../app/unlocks.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/reading.dart' show QuestionCard;
import '../../core/progress/mastery.dart' show kKnownRecall;
import '../../core/progress/unlocks.dart';
import '../../core/scheduling/lesson.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/bottom_actions.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/stat_tile.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import '../review/review_waiting.dart' show pairOf, reviewPairsOf;
import 'deck_content.dart';
import 'number_practice_tile.dart';
import 'path_model.dart';
import 'path_parts.dart';
import 'thanks_notice.dart';
import 'unreviewed_notice.dart';
import 'why_closed_sheet.dart';
import 'word_mastery.dart';
import 'word_sheet.dart';
import '../../ui/card_text_scale.dart';

/// A unit of a course's path (the owner's design): its level and number,
/// its name and description, how many of its words and rules are known and
/// its sentences open, then its words, rules and sentences in the order the
/// unit teaches them, and its decks. "Continue" reviews what is due in it,
/// or else teaches its next words.
///
/// The phrasebook is listed first, never held back. A rule is a grammar or
/// rules deck's table; a sentence is open once it was taught or every word
/// and rule in it is known ([Unlocks.isOffered], ADR-0046), and until then it
/// is greyed with what it waits for, and a tap says why.
///
/// Review, at the top end, is for speakers who check decks: with "Review
/// decks" on in Settings it opens the unit's review (`ReviewPage`), and
/// otherwise says to turn it on first. A unit whose decks list the
/// reviewer's rater code thanks them where the not-yet-checked notice was.
class UnitPage extends StatefulWidget {
  const UnitPage({
    super.key,
    required this.deckId,
    this.plan,
    this.openWord,
    this.openTables = false,
  });

  /// A deck in the unit, by id: the unit is the one holding it.
  final String deckId;

  /// The course's plan, in place of [coursePlanOf], for the unit's level.
  /// For tests and the debug gallery.
  final CoursePlan? plan;

  /// A word to open the card of on arrival, by card id, for the debug
  /// gallery.
  final String? openWord;

  /// Whether every rule's table starts open, for the debug gallery.
  final bool openTables;

  @override
  State<UnitPage> createState() => _UnitPageState();
}

class _UnitPageState extends State<UnitPage> {
  /// How many words show before "Show all".
  static const int _firstWords = 6;

  bool _allWords = false;
  final Set<String> _openTables = <String>{};
  bool _tablesSeeded = false;
  bool _opened = false;

  void _openWordOnce(AppState state, LanguageInfo language) {
    final id = widget.openWord;
    if (_opened || id == null) return;
    _opened = true;
    final card = <Card>[for (final entry in state.decks) ...entry.cards]
        .where((c) => c.id == id)
        .firstOrNull;
    if (card == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showWordSheet(context, card: card, language: language);
    });
  }

  /// Opens the unit's review, or with reviewing off, says to turn it on in
  /// Settings first.
  Future<void> _review(
    BuildContext context,
    AppState state,
    LanguageInfo language,
  ) async {
    if (state.reviewing.on && state.reviewing.code != null) {
      await AppNavigator.openReview(context, widget.deckId);
      return;
    }
    final settings = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          icon: const Icon(Icons.fact_check_outlined),
          title: Text(l10n.reviewFirstTitle),
          content: Text(l10n.reviewFirstBody(language.name)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.reviewFirstNotNow),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.reviewFirstOpenSettings),
            ),
          ],
        );
      },
    );
    if (settings == true && context.mounted) {
      AppNavigator.backToShell(context, tab: ShellTab.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final unit = unitOfDeck(state, widget.deckId, plan: widget.plan);
    if (unit == null) {
      return Scaffold(
        appBar: AppBar(actions: const <Widget>[ReportButton()]),
        body: state.status == CatalogStatus.loading
            ? Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.commonLoadingDecks,
                ),
              )
            : EmptyState(icon: Icons.style_outlined, title: l10n.deckNotFound),
      );
    }
    final decks = unit.decks;
    final first = decks.first;
    final language = first.language;
    _openWordOnce(state, language);
    if (widget.openTables && !_tablesSeeded) {
      _tablesSeeded = true;
      _openTables.addAll(<String>[
        for (final entry in UnitContent(decks).rules) entry.id,
      ]);
    }

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
      ]),
      builder: (context, _) {
        final content = UnitContent(decks);
        final answers = state.recentAnswers;
        final gate = state.unlocks;
        final words = <Card>[
          for (final card in content.words)
            if (!card.phrasebook) card,
        ];
        final sentences = <Card>[
          for (final card in content.sentences)
            if (!card.phrasebook) card,
        ];
        final large = isLargeText(context);
        final ids = <String>{for (final e in decks) e.id};
        final due = state.buildSession(DrillRequest(deckIds: ids)).due.length;
        // The next lesson: from the first deck with words left to teach.
        DrillRequest? lesson;
        var fresh = 0;
        for (final entry in decks) {
          final request = DrillRequest.lesson(
            language: language.code,
            deckId: entry.id,
          );
          final items = state.lessonFor(request);
          if (items.isEmpty) continue;
          lesson = request;
          // A reading lesson is a passage's questions, none taught first.
          fresh = items.first.card is QuestionCard
              ? items.length
              : lessonCardCount(items);
          break;
        }
        final DrillRequest? next = due > 0
            ? DrillRequest(deckIds: ids)
            : lesson;
        var section = 0;
        // Reviewing is for a course whose two languages the learner knows
        // (and reads), not for one they are learning (#525).
        final reviews = reviewPairsOf(state).contains(pairOf(first));
        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.decksCourseHeading(language.name, first.deck.native.name),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            actions: <Widget>[
              if (reviews && large)
                IconButton(
                  tooltip: l10n.unitReview,
                  icon: const Icon(Icons.fact_check_outlined),
                  onPressed: () => _review(context, state, language),
                )
              else if (reviews)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  // Compact, to sit in the app bar: the theme's primary
                  // button is taller than the bar. The tap target stays
                  // 48dp, padded around the 40dp button.
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16,
                      ),
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.padded,
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                    onPressed: () => _review(context, state, language),
                    icon: const Icon(Icons.fact_check_outlined, size: 20),
                    label: Text(l10n.unitReview),
                  ),
                ),
              ReportButton(detail: decks.map((e) => e.id).join(', ')),
            ],
          ),
          body: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              16,
              0,
              16,
              24,
            ).clearingSystemBar(context),
            children: <Widget>[
              _Header(
                number: unit.number,
                level: unit.level,
                title: unitTitle(state, decks),
                decks: decks,
              ),
              const SizedBox(height: 20),
              _Tiles(
                content: content,
                words: words,
                sentences: sentences,
                answers: answers,
                gate: gate,
                state: state,
              ),
              if (content.phrasebook.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                _SectionHeading(title: l10n.unitSectionPhrasebook(++section)),
                const SizedBox(height: 10),
                GroupedList(
                  outerRadius: AppRadii.card,
                  gap: 4,
                  children: <Widget>[
                    for (final card in content.phrasebook)
                      CardRow(
                        card: card,
                        language: language,
                        mastery: answers.of(card.id),
                        phrasebook: true,
                        onTap: () => showWordSheet(
                          context,
                          card: card,
                          language: language,
                        ),
                      ),
                  ],
                ),
              ],
              if (words.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                _SectionHeading(
                  title: content.isScript
                      ? l10n.unitSectionLetters(++section)
                      : l10n.unitSectionWords(++section),
                  aside: l10n.unitKnownMeans((kKnownRecall * 100).round()),
                ),
                const SizedBox(height: 10),
                GroupedList(
                  outerRadius: AppRadii.card,
                  gap: 4,
                  children: <Widget>[
                    for (final card
                        in _allWords ? words : words.take(_firstWords))
                      CardRow(
                        card: card,
                        language: language,
                        mastery: answers.of(card.id),
                        onTap: () => showWordSheet(
                          context,
                          card: card,
                          language: language,
                        ),
                      ),
                  ],
                ),
                if (words.length > _firstWords)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => setState(() => _allWords = !_allWords),
                      child: Text(
                        _allWords
                            ? l10n.unitShowFewer
                            : l10n.unitShowAll(words.length),
                      ),
                    ),
                  ),
              ],
              if (content.rules.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                _SectionHeading(title: l10n.unitSectionRules(++section)),
                const SizedBox(height: 10),
                for (final rule in content.rules) ...<Widget>[
                  _RuleCard(
                    entry: rule,
                    answers: answers,
                    gate: gate,
                    mastery: answers.ofAll(rule.cards.map((c) => c.id)),
                    open: _openTables.contains(rule.id),
                    onToggle: () => setState(() {
                      _openTables.contains(rule.id)
                          ? _openTables.remove(rule.id)
                          : _openTables.add(rule.id);
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (sentences.isNotEmpty) ...<Widget>[
                const SizedBox(height: 24),
                _SectionHeading(
                  title: l10n.unitSectionSentences(++section),
                  aside: l10n.unitSentencesCount(
                    sentences.where(gate.isOffered).length,
                    sentences.length,
                  ),
                ),
                const SizedBox(height: 10),
                GroupedList(
                  outerRadius: AppRadii.card,
                  gap: 4,
                  children: <Widget>[
                    for (final card in sentences)
                      if (gate.isOffered(card))
                        CardRow(
                          card: card,
                          language: language,
                          mastery: answers.of(card.id),
                          notOpen: !state.isTaught(card),
                          onTap: () => showWordSheet(
                            context,
                            card: card,
                            language: language,
                          ),
                        )
                      else
                        CardRow(
                          card: card,
                          language: language,
                          mastery: answers.of(card.id),
                          waiting: <String>[
                            for (final need in gate.waitingFor(card))
                              state.needName(need),
                          ],
                          onTap: () => showWhyClosedSheet(
                            context,
                            card: card,
                            language: language,
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                  child: Text(
                    l10n.unitSentencesNote,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              GroupedList(
                header: l10n.unitDecks,
                outerRadius: AppRadii.card,
                gap: 4,
                children: <Widget>[
                  for (final entry in decks) ...<Widget>[
                    DeckTile(
                      entry: entry,
                      badge: DeckBadge.forEntry(state, entry),
                      onTap: () => AppNavigator.openDeck(context, entry.id),
                    ),
                    if (hasNumberPractice(state, entry))
                      NumberPracticeTile(deck: entry),
                  ],
                ],
              ),
            ],
          ),
          bottomNavigationBar: _ContinueBar(
            label: next == null
                ? l10n.unitNothingLeft
                : l10n.unitContinue(fresh, due),
            onPressed: next == null
                ? null
                : () => AppNavigator.startDrill(context, next),
          ),
        );
      },
    );
  }
}

/// The level and number, the unit's name, its theme deck's description and
/// the notice of a deck no speaker has checked.
class _Header extends StatelessWidget {
  const _Header({
    required this.number,
    required this.level,
    required this.title,
    required this.decks,
  });

  final int number;
  final CefrLevel? level;
  final String title;
  final List<DeckEntry> decks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final described = decks
        .map((e) => e.deck.description)
        .nonNulls
        .where((d) => d.isNotEmpty)
        .firstOrNull;
    final reviewing = AppScope.of(context).reviewing;
    final helped = decks.where(reviewing.helpedBuild).firstOrNull;
    // Thanks take the place of the notice only on the decks the reviewer
    // helped build: another deck of the unit still unchecked keeps it.
    final unchecked = decks
        .where(
          (e) => UnreviewedNotice.appliesTo(e) && !reviewing.helpedBuild(e),
        )
        .firstOrNull;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MergeSemantics(
            child: Row(
              children: <Widget>[
                if (level != null) ...<Widget>[
                  Pill(
                    text: level!.label,
                    background: scheme.primaryContainer,
                    foreground: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  l10n.pathUnitNumber(number),
                  style: theme.textTheme.titleSmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.headlineMedium),
          ),
          if (described != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              described,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (helped != null) ...<Widget>[
            const SizedBox(height: 12),
            ThanksNotice(
              code: '${reviewing.code}',
              others: reviewing.reviewerCount(helped) - 1,
            ),
          ],
          if (unchecked != null) ...<Widget>[
            const SizedBox(height: 12),
            UnreviewedNotice(entry: unchecked),
          ],
        ],
      ),
    );
  }
}

/// Words known, rules known and sentences open, each where the unit has
/// some, abreast. A rule of a rules deck counts by its own answers, a
/// grammar deck's table as one; a sentence is open once taught or once its
/// words and rules are known ([Unlocks.isOffered]).
class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.content,
    required this.words,
    required this.sentences,
    required this.answers,
    required this.gate,
    required this.state,
  });

  final UnitContent content;
  final List<Card> words;
  final List<Card> sentences;
  final RecentAnswers answers;
  final Unlocks gate;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String fraction(int count, int total) => l10n.unitFraction(
      formatCount(context, count),
      formatCount(context, total),
    );
    final known = words
        .where((c) => answers.of(c.id).level == MasteryLevel.known)
        .length;
    var rulesTotal = 0;
    var rulesKnown = 0;
    for (final entry in content.rules) {
      if (entry.deck.kind == DeckKind.rules && entry.deck.rules.isNotEmpty) {
        for (final rule in entry.deck.rules) {
          rulesTotal++;
          if (gate.isRuleKnown(rule.id)) rulesKnown++;
        }
      } else {
        rulesTotal++;
        final standing = answers.ofAll(entry.cards.map((c) => c.id));
        if (standing.level == MasteryLevel.known) rulesKnown++;
      }
    }
    final open = sentences.where(gate.isOffered).length;
    final tiles = <Widget>[
      if (words.isNotEmpty)
        StatTile(
          value: fraction(known, words.length),
          label: content.isScript ? l10n.unitLettersKnown : l10n.unitWordsKnown,
        ),
      if (rulesTotal > 0)
        StatTile(
          value: fraction(rulesKnown, rulesTotal),
          label: l10n.unitRulesKnown,
        ),
      if (sentences.isNotEmpty)
        StatTile(
          value: fraction(open, sentences.length),
          label: l10n.unitSentencesOpen,
        ),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

/// "1 · Words", with a line beside it.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.aside});

  final String title;
  final String? aside;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aside = this.aside;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          if (aside != null)
            Text(
              aside,
              style: theme.textTheme.labelMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

/// A word or a sentence: the target, its meaning and reading, and where it
/// stands. Tapping it opens its card. A phrasebook chunk is marked as one
/// instead of where it stands. A sentence not open yet, with [waiting] what
/// it waits for, is greyed with a lock, and tapping it says why.
class CardRow extends StatelessWidget {
  const CardRow({
    super.key,
    required this.card,
    required this.language,
    required this.mastery,
    required this.onTap,
    this.notOpen = false,
    this.phrasebook = false,
    this.waiting,
  });

  final Card card;
  final LanguageInfo language;
  final Mastery mastery;
  final VoidCallback onTap;
  final bool notOpen;

  /// Whether it is a phrasebook chunk.
  final bool phrasebook;

  /// What a closed sentence waits for, a word or a rule each; null for any
  /// other row.
  final List<String>? waiting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = card.reading;
    final sentence = isSentence(card);
    final closed = waiting != null;
    final muted = scheme.onSurfaceVariant;
    final target = TargetText(
      card.target,
      language: language,
      fontSize: sentence ? 17 : 20,
      textAlign: TextAlign.start,
      color: closed ? muted : null,
      card: card,
    );
    final meaning = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          card.native,
          style: theme.textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w700,
            color: closed ? muted : null,
          ),
        ),
        if (reading != null)
          Text(
            reading,
            style: theme.textTheme.bodySmall!.copyWith(color: muted),
          ),
        if (closed)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Text(
              l10n.unitWaitingFor(waiting!.join(', ')),
              style: theme.textTheme.bodySmall!.copyWith(color: muted),
            ),
          ),
      ],
    );
    final Widget status = closed
        ? Icon(
            Icons.lock_outline,
            color: muted,
            semanticLabel: l10n.unitNotOpen,
          )
        : phrasebook
        ? Pill(
            text: l10n.unitPhrasebook,
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
          )
        : MasteryChip(mastery: mastery, notOpen: notOpen);
    return Semantics(
      hint: closed ? l10n.unitWhyClosedHint : l10n.unitOpenWord,
      child: MergeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
              // A sentence takes the row's width over its meaning; a word
              // sits beside it.
              child: sentence
                  ? Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              target,
                              const SizedBox(height: 2),
                              meaning,
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        status,
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(flex: 4, child: target),
                        const SizedBox(width: 10),
                        Expanded(flex: 5, child: meaning),
                        const SizedBox(width: 8),
                        status,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rule: its name, its pattern's note, how well it is known, and its
/// table of forms, shown on request.
class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.entry,
    required this.answers,
    required this.gate,
    required this.mastery,
    required this.open,
    required this.onToggle,
  });

  final DeckEntry entry;
  final RecentAnswers answers;
  final Unlocks gate;
  final Mastery mastery;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final about = entry.deck.description ?? entry.deck.pattern?.notes;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.deck.name,
                        style: theme.textTheme.titleSmall!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (about != null && about.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          about,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                MasteryChip(mastery: mastery),
              ],
            ),
          ),
          if (open) ...<Widget>[
            const SizedBox(height: 12),
            _RuleTable(entry: entry, answers: answers, gate: gate),
            const SizedBox(height: 8),
            Text(
              entry.deck.kind == DeckKind.rules
                  ? l10n.unitRuleGrows
                  : l10n.unitRuleCells,
              style: theme.textTheme.bodySmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onToggle,
              icon: Icon(open ? Icons.expand_less : Icons.expand_more),
              label: Text(
                open ? l10n.unitRuleHideTable : l10n.unitRuleShowTable,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rule's table: a row per word, a column per form, each cell its form
/// and reading. Scrolls sideways when it is wider than the screen. A
/// grammar deck's comes from its pattern; a rules deck's from its cells,
/// so that it shows the rows its learners are taught (ADR-0036): only the
/// words the learner knows or has been asked, each cell marked known,
/// learning or not asked yet (#417, owner, 2026-10-23: "the rule table
/// hides untaught words").
class _RuleTable extends StatelessWidget {
  const _RuleTable({
    required this.entry,
    required this.answers,
    required this.gate,
  });

  final DeckEntry entry;
  final RecentAnswers answers;
  final Unlocks gate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = entry.language;
    final (heads, rows) = _rows(entry, gate, answers);
    Widget cell(Widget child, {bool head = false}) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
      child: DefaultTextStyle.merge(
        style: head
            ? theme.textTheme.labelMedium!.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              )
            : null,
        child: child,
      ),
    );
    Widget form(String text, String? reading, {String? cardId}) {
      final level = cardId == null ? null : answers.of(cardId).level;
      final shown = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TargetText(
            text,
            language: language,
            fontSize: 16,
            textAlign: TextAlign.start,
            color: switch (level) {
              MasteryLevel.known => scheme.onPrimaryContainer,
              MasteryLevel.learning => scheme.onSecondaryContainer,
              _ => null,
            },
          ),
          if (reading != null)
            Text(
              reading,
              style: theme.textTheme.bodySmall!.copyWith(
                color: switch (level) {
                  MasteryLevel.known => scheme.onPrimaryContainer,
                  MasteryLevel.learning => scheme.onSecondaryContainer,
                  _ => scheme.onSurfaceVariant,
                },
              ),
            ),
          if (level != null)
            Text(
              switch (level) {
                MasteryLevel.known => l10n.unitCellKnown,
                MasteryLevel.learning => l10n.unitCellLearning,
                MasteryLevel.fresh => l10n.unitCellNotAsked,
              },
              style: theme.textTheme.labelSmall!.copyWith(
                color: switch (level) {
                  MasteryLevel.known => scheme.onPrimaryContainer,
                  MasteryLevel.learning => scheme.onSecondaryContainer,
                  MasteryLevel.fresh => scheme.onSurfaceVariant,
                },
              ),
            ),
        ],
      );
      if (level == null) return shown;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: switch (level) {
            MasteryLevel.known => scheme.primaryContainer,
            MasteryLevel.learning => scheme.secondaryContainer,
            MasteryLevel.fresh => null,
          },
          border: level == MasteryLevel.fresh
              ? Border.all(color: scheme.outline)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: shown,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder(
          horizontalInside: BorderSide(color: scheme.outlineVariant),
        ),
        children: <TableRow>[
          TableRow(
            children: <Widget>[
              cell(Text(l10n.unitRuleWord), head: true),
              for (final head in heads) cell(Text(head), head: true),
            ],
          ),
          for (final (word, forms) in rows)
            TableRow(
              children: <Widget>[
                cell(form(word.$1, word.$2)),
                for (final f in forms)
                  cell(
                    f == null
                        ? const SizedBox.shrink()
                        : form(f.$1, f.$2, cardId: f.$3),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// [entry]'s column heads, and its rows: each word, and its form in each
  /// column, or null, each with its reading.
  static (List<String>, List<(_Form, List<_Form?>)>) _rows(
    DeckEntry entry,
    Unlocks gate,
    RecentAnswers answers,
  ) {
    final pattern = entry.deck.pattern;
    if (pattern != null) {
      return (
        pattern.slots,
        <(_Form, List<_Form?>)>[
          for (final row in pattern.entries)
            (
              (row.lemma, row.reading, null),
              <_Form?>[
                for (final slot in pattern.slots)
                  if (row.forms[slot] case final f?)
                    (f, row.readings[slot]?.first, null)
                  else
                    null,
              ],
            ),
        ],
      );
    }
    // A rules deck: a row per word with a cell taught, in the cells' order,
    // and a column per slot with one.
    final table = entry.deck.table;
    final cells = <String, Map<String, Card>>{};
    final words = <String, _Form>{};
    final used = <String>{};
    for (final card in entry.cards) {
      final rule = card.rule;
      if (rule == null) continue;
      words.putIfAbsent(
        rule.word,
        () => (rule.wordTarget, rule.wordReading, null),
      );
      (cells[rule.word] ??= <String, Card>{})[rule.slot] = card;
      used.add(rule.slot);
    }
    final slots = <String>[
      ...?table?.slots.where(used.contains),
      ...used.where((s) => table == null || !table.slots.contains(s)),
    ];
    return (
      <String>[for (final slot in slots) _head(table?.labels[slot] ?? slot)],
      <(_Form, List<_Form?>)>[
        for (final MapEntry(key: word, value: form) in words.entries)
          // Only a word the learner knows, or has been asked a cell of.
          if (gate.isWordKnown(word) ||
              cells[word]!.values.any(
                (c) => answers.of(c.id).level != MasteryLevel.fresh,
              ))
            (
              form,
              <_Form?>[
                for (final slot in slots)
                  if (cells[word]![slot] case final card?)
                    (card.target, card.reading, card.id)
                  else
                    null,
              ],
            ),
      ],
    );
  }

  /// A slot's label as a column head: without the word's meaning, which
  /// the row gives, and the punctuation that joined it ("in {meaning}" is
  /// "in", "{meaning}: with" is "with").
  static String _head(String label) {
    final head = label
        .replaceAll('{meaning}', '')
        .trim()
        .replaceFirst(RegExp(r'^[,:;]\s*'), '')
        .trim();
    return head.isEmpty ? label : head;
  }
}

/// A form, its reading if it has one, and the card of a rules table's cell.
typedef _Form = (String, String?, String?);

/// "Continue · 5 new, 4 due", pinned under the scrolling content.
class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return BottomActions(
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.primaryButton),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
