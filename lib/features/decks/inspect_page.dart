import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../app/skill.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../core/models/reading.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/target_text.dart';
import '../drill/grammar_cells.dart';

/// Every card of a deck in full, for reviewers: what the deck file says of
/// each, and its id, so a mistake can be pointed at exactly.
///
/// A vocab or script deck lists its cards with every field the deck gives:
/// romanisation, meaning, other accepted forms and meanings, part of speech,
/// tags, notes, examples and the skills it is limited to. A grammar deck
/// shows each table whole, a form and its card id per row. A reading deck
/// shows each passage with its romanisation, questions (the right answer
/// marked) and glossary. The text can be selected and copied.
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
        appBar: AppBar(),
        body: EmptyState(icon: Icons.style_outlined, title: l10n.deckNotFound),
      );
    }
    final spoken = state.settings.spokenLanguages;
    final List<Widget> items = switch (entry.deck.kind) {
      DeckKind.grammar => _grammarTables(entry),
      DeckKind.reading => <Widget>[
        for (final passage in entry.deck.passages)
          _PassageBlock(passage: passage, entry: entry, spoken: spoken),
      ],
      DeckKind.vocab => <Widget>[
        for (final card in entry.cards) _CardBlock(card: card, entry: entry),
      ],
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.inspectTitle(entry.deck.name))),
      body: SelectionArea(
        child: ListView.separated(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => i == 0
              ? Text(
                  l10n.inspectIntro(entry.id),
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : items[i - 1],
        ),
      ),
    );
  }

  /// One table per entry of the pattern, in the deck's order.
  static List<Widget> _grammarTables(DeckEntry entry) {
    final rows = <String, List<(GrammarCell, Card)>>{};
    for (final card in entry.cards) {
      final cell = grammarCellOf(card, entry.deck);
      if (cell == null) continue;
      rows.putIfAbsent(cell.entry.lemma, () => <(GrammarCell, Card)>[]).add((
        cell,
        card,
      ));
    }
    return <Widget>[
      if (entry.deck.pattern?.notes case final notes? when notes.isNotEmpty)
        _Block(child: _Muted(notes)),
      for (final cells in rows.values)
        _GrammarTable(cells: cells, entry: entry),
    ];
  }
}

/// A panel for one card, table or passage.
class _Block extends StatelessWidget {
  const _Block({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.small),
    ),
    child: child,
  );
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

/// A card or cell id, in a fixed-width face so that it reads exactly.
class _Id extends StatelessWidget {
  const _Id(this.id);

  final String id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Text(
      l10n.inspectId(id),
      style: theme.textTheme.labelMedium!.copyWith(
        fontFamily: 'monospace',
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// "Label: value", for a field the deck gives.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _CardBlock extends StatelessWidget {
  const _CardBlock({required this.card, required this.entry});

  final Card card;
  final DeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = entry.language;
    final separator = l10n.commonListSeparator;
    final reading = card.reading;
    final notes = card.notes;
    final skills = <String>[
      for (final skill in Skill.values)
        if (skill.mode != null && card.modes.contains(skill.mode))
          skill.label(l10n),
    ];
    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Id(card.id),
          const SizedBox(height: 6),
          TargetText(
            card.target,
            language: language,
            fontSize: 24,
            textAlign: TextAlign.start,
          ),
          if (reading != null) _Muted(reading),
          const SizedBox(height: 4),
          Text(card.native, style: theme.textTheme.titleMedium),
          if (card.altTarget.isNotEmpty)
            _Field(l10n.inspectAlsoAccepted, card.altTarget.join(separator)),
          if (card.altNative.isNotEmpty)
            _Field(l10n.inspectAlsoMeans, card.altNative.join(separator)),
          if (card.pos case final pos?) _Field(l10n.inspectPartOfSpeech, pos),
          if (card.gender case final gender?)
            _Field(l10n.inspectGender, gender),
          if (card.tags.isNotEmpty)
            _Field(l10n.inspectTags, card.tags.join(separator)),
          // A card that names no skills is drilled in all that apply.
          if (skills.isNotEmpty)
            _Field(l10n.inspectOnlyIn, skills.join(separator)),
          if (notes != null && notes.isNotEmpty)
            _Field(l10n.inspectNotes, notes),
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
        ],
      ),
    );
  }
}

/// One entry of a grammar table: its lemma and meaning, then a row per form
/// with the form, any other accepted forms, and the cell's card id.
class _GrammarTable extends StatelessWidget {
  const _GrammarTable({required this.cells, required this.entry});

  final List<(GrammarCell, Card)> cells;
  final DeckEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final first = cells.first.$1;
    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TargetText(
            first.entry.lemma,
            language: entry.language,
            fontSize: 22,
            textAlign: TextAlign.start,
          ),
          Text(first.entry.gloss, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final (cell, card) in cells)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${first.pattern.slotName}: ${cell.slot}', // ui-literal-ok: deck content, label and value
                    style: theme.textTheme.labelLarge,
                  ),
                  TargetText(
                    card.target,
                    language: entry.language,
                    fontSize: 18,
                    textAlign: TextAlign.start,
                  ),
                  if (card.altTarget.isNotEmpty)
                    _Field(
                      l10n.inspectAlsoAccepted,
                      card.altTarget.join(l10n.commonListSeparator),
                    ),
                  _Id(card.id),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A passage: its id, title and source, every sentence with its
/// romanisation, its questions with the right answer marked, and its
/// glossary.
class _PassageBlock extends StatelessWidget {
  const _PassageBlock({
    required this.passage,
    required this.entry,
    required this.spoken,
  });

  final Passage passage;
  final DeckEntry entry;
  final List<String> spoken;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final source = passage.source;
    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Id(passage.id),
          const SizedBox(height: 6),
          Text(passage.title, style: theme.textTheme.titleLarge),
          if (source != null) _Muted(l10n.readingSource(source)),
          _Field(l10n.readingPassage, ''),
          for (final sentence in passage.sentences)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TargetText(
                    sentence.text,
                    language: entry.language,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    textAlign: TextAlign.start,
                  ),
                  if (sentence.reading case final reading?) _Muted(reading),
                ],
              ),
            ),
          _Field(l10n.inspectQuestions, ''),
          for (final question in passage.questions)
            _QuestionLines(question: question, spoken: spoken),
          if (passage.glossary.isNotEmpty) ...<Widget>[
            _Field(l10n.readingWords, ''),
            for (final gloss in passage.glossary)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 4),
                child: Text(
                  <String>[
                    gloss.word,
                    l10n.readingGlossToday,
                    gloss.modern,
                    ?gloss.reading,
                    gloss.meaning[bestLanguage(gloss.meaning.keys, spoken)]!,
                  ].join(' · '), // ui-literal-ok: a separator, not language
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _QuestionLines extends StatelessWidget {
  const _QuestionLines({required this.question, required this.spoken});

  final ReadingQuestion question;
  final List<String> spoken;

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
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Id(question.id),
          Text(
            question.prompt[code] ?? question.prompt.values.first,
            style: theme.textTheme.bodyLarge,
          ),
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
      ),
    );
  }
}
