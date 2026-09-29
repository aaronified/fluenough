import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/stat_tile.dart';
import 'deck_content.dart';
import 'deck_facts.dart';
import 'skill_section.dart';
import 'unreviewed_notice.dart';

/// One deck: counts, practise one skill, only these tags, a card preview,
/// licence, source, voice and id, and Review all due.
///
/// Design screens `deck` and `deck-novoice`. The counts are
/// `AppState.countsFor`, the deck's numbers whatever tags are chosen; the
/// skill buttons and Review all due count what their session would drill,
/// which the tag filter narrows.
class DeckDetailPage extends StatefulWidget {
  const DeckDetailPage({
    super.key,
    required this.deckId,
    this.initialTags = const <String>{},
  });

  /// The deck to show, by its id.
  final String deckId;

  /// Tags already chosen in "Only these tags", for the gallery and tests.
  final Set<String> initialTags;

  @override
  State<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends State<DeckDetailPage> {
  late Set<String> _tags = Set<String>.of(widget.initialTags);

  void _toggle(String tag, bool on) => setState(() {
    _tags = Set<String>.of(_tags);
    on ? _tags.add(tag) : _tags.remove(tag);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final entry = state.deckById(widget.deckId);
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: state.status == CatalogStatus.loading
            ? Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.commonLoadingDecks,
                ),
              )
            : EmptyState(icon: Icons.style_outlined, title: l10n.deckNotFound),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
      ]),
      builder: (context, _) {
        final counts = state.countsFor(entry);
        final all = DrillRequest.deck(entry.id, tags: _tags);
        final allCount = state.buildSession(all).items.length;
        return Scaffold(
          appBar: AppBar(),
          body: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
            children: <Widget>[
              _Header(entry: entry),
              const SizedBox(height: 20),
              _Counts(counts: counts),
              const SizedBox(height: 20),
              SkillSection(entry: entry, tags: _tags),
              if (showsTagFilter(entry)) ...<Widget>[
                const SizedBox(height: 20),
                _TagFilter(
                  tags: cardTagsOf(entry),
                  selected: _tags,
                  onChanged: _toggle,
                ),
              ],
              const SizedBox(height: 20),
              CardPreview(entry: entry),
              const SizedBox(height: 20),
              DeckFacts(entry: entry),
            ],
          ),
          bottomNavigationBar: _ReviewAllBar(
            count: allCount,
            onPressed: allCount == 0
                ? null
                : () => AppNavigator.startDrill(context, all),
          ),
        );
      },
    );
  }
}

/// The glyph, "Spanish (spa) · Vocabulary", the card count, the name and the
/// description.
class _Header extends StatelessWidget {
  const _Header({required this.entry});

  final DeckEntry entry;

  /// "Script" for a deck tagged `script` (there is no such deck kind), then
  /// the deck's own kind.
  static String kindOf(AppLocalizations l10n, DeckEntry entry) => entry.isScript
      ? l10n.deckKindScript
      : switch (entry.deck.kind) {
          DeckKind.vocab => l10n.deckKindVocabulary,
          DeckKind.grammar => l10n.deckKindGrammar,
        };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final language = entry.language;
    final description = entry.deck.description;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DeckGlyph(glyph: entry.glyph, language: language, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.deckHeaderLine(
                          language.name,
                          language.iso639_3,
                          kindOf(l10n, entry),
                        ),
                        style: theme.textTheme.titleSmall!.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        l10n.commonCardCount(entry.itemCount),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(entry.deck.name, style: theme.textTheme.headlineMedium),
          ),
          if (description != null && description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyLarge!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (UnreviewedNotice.appliesTo(entry)) ...<Widget>[
            const SizedBox(height: 12),
            UnreviewedNotice(entry: entry),
          ],
        ],
      ),
    );
  }
}

/// Due, New today and Learned, three tiles abreast.
class _Counts extends StatelessWidget {
  const _Counts({required this.counts});

  final DeckCounts counts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tiles = <Widget>[
      StatTile(value: formatCount(context, counts.due), label: l10n.deckDue),
      StatTile(
        value: formatCount(context, counts.fresh),
        label: l10n.deckNewToday,
      ),
      StatTile(
        value: formatCount(context, counts.learned),
        label: l10n.deckLearned,
      ),
    ];
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

/// "Only these tags": a chip per card tag. Chosen tags narrow what the
/// skill buttons and Review all due start.
class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.tags,
    required this.selected,
    required this.onChanged,
  });

  final List<String> tags;
  final Set<String> selected;
  final void Function(String tag, bool on) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          child: Semantics(
            header: true,
            child: Text(
              l10n.deckOnlyTags,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final tag in tags)
                FilterChip(
                  label: Text(tag),
                  selected: selected.contains(tag),
                  onSelected: (on) => onChanged(tag, on),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Review all due · 12", pinned under the scrolling content.
class _ReviewAllBar extends StatelessWidget {
  const _ReviewAllBar({required this.count, required this.onPressed});

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(l10n.deckReviewAll(count)),
          ),
        ),
      ),
    );
  }
}
