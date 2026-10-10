import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../app/skill.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/reading.dart';
import '../../core/scheduling/skill_difficulty.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/target_text.dart';
import '../drill/grammar_cells.dart';
import 'card_notes.dart';

/// Every card of a deck as one scrolling list, for reviewers: two or three
/// lines a card, its script and romanisation, its meaning, and its id, so
/// that a whole deck reads quickly and a mistake can be pointed at exactly.
/// A card with more to it (other accepted forms and meanings, part of
/// speech, tags, notes, examples, the skills it is limited to) opens in
/// place when tapped, with how hard it has been for the learner in each
/// skill it has been answered in (FSRS's D, docs/plans/difficulty-by-skill.md).
///
/// A grammar deck lists each table's cells under its lemma; a reading deck
/// each passage's sentences, then its questions, the right answer shown,
/// then its glossary. The text can be selected and copied.
class InspectPage extends StatelessWidget {
  const InspectPage({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final entry = state.deckById(deckId);
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(actions: <Widget>[ReportButton(detail: deckId)]),
        body: EmptyState(icon: Icons.style_outlined, title: l10n.deckNotFound),
      );
    }
    final spoken = state.settings.spokenLanguages;
    final List<WidgetBuilder> rows = switch (entry.deck.kind) {
      DeckKind.grammar => _grammarRows(entry),
      DeckKind.reading => <WidgetBuilder>[
        for (final passage in entry.deck.passages)
          ..._passageRows(passage, entry, spoken),
      ],
      // A rules deck's cells are cards, listed as a vocab deck's are.
      DeckKind.vocab || DeckKind.rules => <WidgetBuilder>[
        for (final card in entry.cards)
          (_) => _CardRow(card: card, entry: entry),
      ],
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inspectTitle(entry.deck.name)),
        actions: <Widget>[ReportButton(detail: entry.id)],
      ),
      body: SelectionArea(
        child: ListView.separated(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 24),
          itemCount: rows.length + 1,
          separatorBuilder: (_, i) =>
              i == 0 ? const SizedBox(height: 8) : const Divider(height: 1),
          itemBuilder: (context, i) => i == 0
              ? Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                  child: _Muted(l10n.inspectIntro(entry.id)),
                )
              : rows[i - 1](context),
        ),
      ),
    );
  }

  /// A heading per row of the table, then a line per cell under it.
  static List<WidgetBuilder> _grammarRows(DeckEntry entry) {
    final rows = <String, List<(GrammarCell, Card)>>{};
    for (final card in entry.cards) {
      final cell = grammarCellOf(card, entry.deck);
      if (cell == null) continue;
      rows.putIfAbsent(cell.entry.lemma, () => <(GrammarCell, Card)>[]).add((
        cell,
        card,
      ));
    }
    return <WidgetBuilder>[
      if (entry.deck.pattern?.notes case final notes? when notes.isNotEmpty)
        (_) => Padding(
          padding: const EdgeInsetsDirectional.all(8),
          child: _Muted(notes),
        ),
      for (final cells in rows.values) ...<WidgetBuilder>[
        (_) => _Heading(
          title: cells.first.$1.entry.lemma,
          subtitle: cells.first.$1.entry.gloss,
          language: entry.language,
        ),
        for (final (cell, card) in cells)
          (_) => _CellRow(cell: cell, card: card, entry: entry),
      ],
    ];
  }

  /// A passage's heading, its sentences, its questions and its glossary.
  static List<WidgetBuilder> _passageRows(
    Passage passage,
    DeckEntry entry,
    List<String> spoken,
  ) => <WidgetBuilder>[
    (context) => _Heading(
      title: passage.title,
      subtitle: passage.source == null
          ? null
          : AppLocalizations.of(context)!.readingSource(passage.source!),
      id: passage.id,
    ),
    for (final sentence in passage.sentences)
      (_) => _Line(
        top: TargetText(
          sentence.text,
          language: entry.language,
          fontSize: 18,
          fontWeight: FontWeight.w400,
          textAlign: TextAlign.start,
        ),
        middle: sentence.reading,
      ),
    for (final question in passage.questions)
      (_) => _QuestionRow(question: question, spoken: spoken, deckId: entry.id),
    for (final gloss in passage.glossary)
      (context) => _Line(
        top: TargetText(
          gloss.word,
          language: entry.language,
          fontSize: 18,
          textAlign: TextAlign.start,
        ),
        middle: <String>[
          AppLocalizations.of(context)!.readingGlossToday,
          gloss.modern,
          ?gloss.reading,
        ].join(' · '), // ui-literal-ok: a separator, not language
        bottom: gloss.meaning[bestLanguage(gloss.meaning.keys, spoken)],
      ),
  ];
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

/// A card, cell, passage or question id, in a fixed-width face so that it
/// reads exactly.
class _Id extends StatelessWidget {
  const _Id(this.id);

  final String id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context)!.inspectId(id),
      style: theme.textTheme.labelMedium!.copyWith(
        fontFamily: 'monospace',
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// "Label  value", for a field shown when a card is opened.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: 6),
    child: Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: '  '),
          TextSpan(text: value),
        ],
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );
}

/// How hard a card has been in each skill it has been answered in: a
/// heading, then a line a skill, "Hear: 7 of 10, harder". Nothing for a
/// skill not yet answered, and nothing at all for a card never answered.
class _Difficulties extends StatelessWidget {
  const _Difficulties(this.difficulties);

  final List<SkillDifficulty> difficulties;

  /// The lines for [card], or null when no skill of it has been answered.
  static Widget? of(BuildContext context, Card card) {
    final difficulties = SkillDifficulty.of(
      card.id,
      AppScope.of(context).progress.stateOf,
    );
    return difficulties.isEmpty ? null : _Difficulties(difficulties);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 6),
          child: Semantics(
            header: true,
            child: Text(
              l10n.inspectDifficulty,
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        for (final d in difficulties)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
            child: Text(
              l10n.inspectDifficultyIn(d.mode.name, d.shown, d.lean.name),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// The script with its romanisation beside it: one line where it fits.
class _Script extends StatelessWidget {
  const _Script(
    this.text,
    this.reading, {
    required this.language,
    this.size = 20,
  });

  final String text;
  final String? reading;
  final LanguageInfo language;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reading = this.reading;
    return Wrap(
      spacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        TargetText(
          text,
          language: language,
          fontSize: size,
          textAlign: TextAlign.start,
        ),
        if (reading != null && reading.isNotEmpty) _Muted(reading),
      ],
    );
  }
}

/// Two or three lines: [top] (the script and its romanisation), [middle]
/// and [bottom], then the [id], with "Report this card" beside it when the
/// row has a [deckId] to report it in (#160). With [more], it opens in
/// place to show it.
class _Line extends StatelessWidget {
  const _Line({
    required this.top,
    this.middle,
    this.bottom,
    this.id,
    this.deckId,
    this.more = const <Widget>[],
  });

  final Widget top;
  final String? middle;
  final String? bottom;
  final String? id;
  final String? deckId;
  final List<Widget> more;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final middle = this.middle;
    final bottom = this.bottom;
    final id = this.id;
    final subtitle = <Widget>[
      if (middle != null && middle.isNotEmpty) _Muted(middle),
      if (bottom != null && bottom.isNotEmpty)
        Text(bottom, style: theme.textTheme.bodyLarge),
      if (id != null)
        if (deckId case final deck?)
          Row(
            children: <Widget>[
              Flexible(child: _Id(id)),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () =>
                    ReportButton.open(context, detail: '$id in $deck'),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(AppLocalizations.of(context)!.inspectReport),
              ),
            ],
          )
        else
          _Id(id),
    ];
    final Widget? sub = subtitle.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: subtitle,
          );
    if (more.isEmpty) {
      return ListTile(title: top, subtitle: sub);
    }
    return ExpansionTile(
      title: top,
      subtitle: sub,
      shape: const Border(),
      collapsedShape: const Border(),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
      children: more,
    );
  }
}

/// A heading over a grammar row's cells, or a passage.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.subtitle, this.id, this.language});

  final String title;
  final String? subtitle;
  final String? id;
  final LanguageInfo? language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = this.language;
    final subtitle = this.subtitle;
    final id = this.id;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: language == null
                ? Text(title, style: theme.textTheme.titleLarge)
                : TargetText(
                    title,
                    language: language,
                    fontSize: 22,
                    textAlign: TextAlign.start,
                  ),
          ),
          if (subtitle != null) _Muted(subtitle),
          ?(id == null ? null : _Id(id)),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card, required this.entry});

  final Card card;
  final DeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = entry.language;
    final separator = l10n.commonListSeparator;
    final notes = notesText(card);
    final skills = <String>[
      for (final skill in Skill.values)
        if (skill.modes.any(card.modes.contains)) skill.label(l10n),
    ];
    return _Line(
      top: _Script(card.target, card.reading, language: language),
      bottom: card.native,
      id: card.id,
      deckId: entry.id,
      more: <Widget>[
        if (card.altTarget.isNotEmpty)
          _Field(l10n.inspectAlsoAccepted, card.altTarget.join(separator)),
        if (card.altNative.isNotEmpty)
          _Field(l10n.inspectAlsoMeans, card.altNative.join(separator)),
        if (card.pos case final pos?) _Field(l10n.inspectPartOfSpeech, pos),
        if (card.gender case final gender?) _Field(l10n.inspectGender, gender),
        if (card.tags.isNotEmpty)
          _Field(l10n.inspectTags, card.tags.join(separator)),
        // A card that names no skills is drilled in all that apply.
        if (skills.isNotEmpty)
          _Field(l10n.inspectOnlyIn, skills.join(separator)),
        if (notes != null) _Field(l10n.inspectNotes, notes),
        if (card.examples.isNotEmpty) ...<Widget>[
          _Field(l10n.inspectExamples, ''),
          for (final example in card.examples)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TargetText(
                    example.target,
                    language: language,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    textAlign: TextAlign.start,
                  ),
                  _Muted(example.native),
                ],
              ),
            ),
        ],
        ?_Difficulties.of(context, card),
      ],
    );
  }
}

/// One cell of a grammar table: its form and romanisation, its slot, and
/// its card id; any other accepted forms when opened.
class _CellRow extends StatelessWidget {
  const _CellRow({required this.cell, required this.card, required this.entry});

  final GrammarCell cell;
  final Card card;
  final DeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _Line(
      top: _Script(
        card.target,
        card.reading,
        language: entry.language,
        size: 18,
      ),
      bottom: '${cell.pattern.slotName}: ${cell.slot}', // ui-literal-ok: deck content, label and value
      id: card.id,
      deckId: entry.id,
      more: <Widget>[
        if (card.altTarget.isNotEmpty)
          _Field(
            l10n.inspectAlsoAccepted,
            card.altTarget.join(l10n.commonListSeparator),
          ),
        ?_Difficulties.of(context, card),
      ],
    );
  }
}

/// A question: its prompt, the right answer, its id; every choice when
/// opened, the right one marked.
class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.spoken,
    required this.deckId,
  });

  final ReadingQuestion question;
  final List<String> spoken;
  final String deckId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final code = question.languageFor(spoken);
    final choices = question.options.isEmpty
        ? <String>[l10n.readingTrue, l10n.readingFalse]
        : <String>[
            for (final option in question.options)
              option[code] ?? option['en'] ?? option.values.first,
          ];
    return _Line(
      top: Text(
        question.prompt[code] ?? question.prompt.values.first,
        style: theme.textTheme.bodyLarge,
      ),
      middle: '✓ ${choices[question.answer]}', // ui-literal-ok: a mark, not language
      id: question.id,
      deckId: deckId,
      more: <Widget>[
        for (final (i, choice) in choices.indexed)
          Semantics(
            label: i == question.answer ? l10n.readingChoiceRight : null,
            child: Row(
              children: <Widget>[
                Icon(
                  i == question.answer
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: i == question.answer
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    choice,
                    style: i == question.answer
                        ? const TextStyle(fontWeight: FontWeight.w700)
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
