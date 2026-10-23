import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/routes.dart';
import '../../app/session.dart';
import '../../app/skill.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/bottom_actions.dart';
import '../../ui/widgets/deck_tile.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/system_bar.dart';
import '../../ui/widgets/target_text.dart';
import 'deck_content.dart';
import 'deck_facts.dart';
import 'passage_preview.dart';
import 'path_model.dart' show isSentence;
import 'path_parts.dart';
import 'unreviewed_notice.dart';
import 'word_mastery.dart';
import 'word_sheet.dart';

/// One deck (#693, owner, 2026-10-20): every one of its words, each with its
/// meaning and where the learner stands with it; the tag chips, which filter
/// the words live; and at the foot Practice and + Learn, both acting on the
/// words as the chips leave them. A reading deck lists its passages instead
/// (#98), and every deck ends with its licence, source, voice and id.
///
/// - **A word's row** opens its word sheet, with everything the card has.
///   Inspect, which listed the cards for reviewers, is gone: the sheet has its
///   fields.
/// - **Practice** asks which skills, with All, then drills every word taught
///   in them, due or not; every answer is recorded (#499, ADR-0033).
/// - **+ Learn** teaches the words in view that are not taught yet (ADR-0024),
///   with a badge on its corner counting them. Once every word in view is
///   taught it is **Relearn**, with no badge: a walk through every word in
///   view (#694), which is incoming until it is built.
///
/// Built from the `deck-page-and-teach-card` mockup, removed once built (in
/// git history). The tag chips choose the words
/// that carry any of the chosen tags, as a session's tags do.
class DeckDetailPage extends StatefulWidget {
  const DeckDetailPage({
    super.key,
    required this.deckId,
    this.initialTags = const <String>{},
  });

  /// The deck to show, by its id.
  final String deckId;

  /// Tags already chosen, for the gallery and tests.
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

  /// Removes a deck the learner added (#22), once they confirm.
  Future<void> _confirmRemove(DeckEntry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deckRemoveTitle(entry.deck.name)),
        content: Text(l10n.deckRemoveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deckRemoveConfirm),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    final state = AppScope.read(context);
    showAppSnackBar(context, l10n.deckRemoved(entry.deck.name));
    await Navigator.of(context).maybePop();
    await state.removeDeck(entry.id);
  }

  /// Practice: asks which of [skills], then drills the words in view in them.
  Future<void> _practise(DeckEntry entry, List<Skill> skills) async {
    final chosen = await showDialog<Set<Skill>>(
      context: context,
      builder: (_) => _PracticeDialog(skills: skills),
    );
    if (chosen == null || !mounted) return;
    await AppNavigator.startDrill(
      context,
      DrillRequest.practice(
        entry.id,
        // Every skill ticked is every skill switched on.
        skills: chosen.length == skills.length ? null : chosen,
        tags: _tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final entry = state.deckById(widget.deckId);
    if (entry == null) {
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

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        state.progress,
        state.settings,
      ]),
      builder: (context, _) {
        final reading = entry.deck.kind == DeckKind.reading;
        // The words the chips leave in view: every one that carries a
        // chosen tag, or all of them with none chosen.
        final words = <Card>[
          if (!reading)
            for (final card in entry.cards)
              if (_tags.isEmpty || card.tags.any(_tags.contains)) card,
        ];
        final answers = RecentAnswers(state.progress.log);
        final untaught = state
            .untaughtCards(entry.language.code, deckId: entry.id, tags: _tags)
            .length;
        final skills = deckSkills(entry, state.settings);
        final practiceCount = state
            .buildSession(DrillRequest.practice(entry.id, tags: _tags))
            .items
            .length;
        return Scaffold(
          appBar: AppBar(
            actions: <Widget>[
              if (!entry.bundled)
                IconButton(
                  tooltip: l10n.deckRemove,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmRemove(entry),
                ),
              ReportButton(detail: entry.id),
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
              _Header(entry: entry),
              const SizedBox(height: 16),
              if (showsTagFilter(entry) && !reading) ...<Widget>[
                _TagFilter(
                  tags: cardTagsOf(entry),
                  selected: _tags,
                  onChanged: _toggle,
                ),
                const SizedBox(height: 12),
              ],
              if (reading)
                PassagePreview(entry: entry)
              else ...<Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                  child: Text(
                    l10n.deckWordCount(words.length, entry.cards.length),
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (words.isEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 8,
                      vertical: 24,
                    ),
                    child: Text(
                      l10n.deckNoWordsWithTags,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final card in words)
                  _WordRow(
                    card: card,
                    language: entry.language,
                    showReading: state.settings.showRomanisation,
                    mastery: answers.of(card.id),
                    notOpen: isSentence(card) && !state.isTaught(card),
                    onTap: () => showWordSheet(
                      context,
                      card: card,
                      language: entry.language,
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              DeckFacts(entry: entry),
            ],
          ),
          bottomNavigationBar: _ActionBar(
            practiceEnabled: practiceCount > 0 && skills.isNotEmpty,
            onPractice: () => _practise(entry, skills),
            untaught: untaught,
            // Nothing in view is not "all taught": Learn stays, and is off.
            relearn: untaught == 0 && (reading || words.isNotEmpty),
            learnEnabled: untaught > 0,
            onLearn: () => AppNavigator.startDrill(
              context,
              DrillRequest.lesson(
                language: entry.language.code,
                deckId: entry.id,
                tags: _tags,
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final language = entry.language;
    final description = entry.deck.description;
    final guide = entry.isScript
        ? AppScope.of(context).scriptGuideFor(language)
        : null;
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
                          deckKindLabel(l10n, entry),
                        ),
                        style: theme.textTheme.titleSmall!.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        entry.deck.kind == DeckKind.reading
                            ? l10n.deckReadingCount(
                                entry.deck.passages.length,
                                entry.itemCount,
                              )
                            : l10n.commonCardCount(entry.itemCount),
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
          // How the script works (#30): Tips, as Duolingo's script pages
          // have above their chart.
          if (guide != null) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: () => AppNavigator.openScriptGuide(context, guide.key),
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(
                l10n.deckScriptTips(guide.name),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A chip per card tag. They filter the words below live: a word shows while
/// it carries any chosen tag, and with none chosen every word shows.
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
    return Semantics(
      container: true,
      label: l10n.deckTagsLabel,
      child: Padding(
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
    );
  }
}

/// A word's row: the word and its reading, its meaning and, under the
/// meaning, where the learner stands with it. Opens the word sheet.
class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.card,
    required this.language,
    required this.showReading,
    required this.mastery,
    required this.notOpen,
    required this.onTap,
  });

  final Card card;
  final LanguageInfo language;
  final bool showReading;
  final Mastery mastery;
  final bool notOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reading = card.reading;
    return Semantics(
      hint: l10n.unitOpenWord,
      child: MergeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TargetText(
                        card.target,
                        language: language,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        textAlign: TextAlign.start,
                        card: card,
                      ),
                      if (showReading && reading != null)
                        Text(
                          reading,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 4,
                    children: <Widget>[
                      Text(
                        card.native,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyMedium,
                      ),
                      MasteryChip(mastery: mastery, notOpen: notOpen),
                    ],
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

/// The two buttons at the foot, side by side: Practice and + Learn, which
/// becomes Relearn once every word in view is taught.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.practiceEnabled,
    required this.onPractice,
    required this.untaught,
    required this.relearn,
    required this.learnEnabled,
    required this.onLearn,
  });

  final bool practiceEnabled;
  final VoidCallback onPractice;

  /// How many words in view are not taught yet: the badge on + Learn.
  final int untaught;
  final bool relearn;
  final bool learnEnabled;
  final VoidCallback onLearn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(AppSizes.primaryButton),
    );
    final Widget learn;
    if (relearn) {
      // Relearn walks through every word in view (#694); until that is built
      // it is shown disabled, with the badge (ADR-0008).
      learn = IncomingFeature(
        feature: Feature.walkthrough,
        label: l10n.deckRelearn,
        badge: IncomingBadgePlacement.overlay,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: style,
            onPressed: null,
            icon: const Icon(Icons.replay_rounded, size: 22),
            label: Text(l10n.deckRelearn),
          ),
        ),
      );
    } else {
      learn = Badge(
        isLabelVisible: untaught > 0,
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        label: Text(
          formatCount(context, untaught),
          semanticsLabel: l10n.deckLearnBadge(untaught),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: style,
            onPressed: learnEnabled ? onLearn : null,
            icon: const Icon(Icons.add_rounded, size: 22),
            label: Text(l10n.deckLearn),
          ),
        ),
      );
    }
    return BottomActions(
      child: Row(
        spacing: 12,
        children: <Widget>[
          Expanded(
            child: FilledButton.tonal(
              style: style,
              onPressed: practiceEnabled ? onPractice : null,
              child: Text(l10n.deckPractice),
            ),
          ),
          Expanded(child: learn),
        ],
      ),
    );
  }
}

/// Practice's popup: the skills the deck offers, each ticked, with All on
/// top. Pops the ticked set, or null on Cancel.
class _PracticeDialog extends StatefulWidget {
  const _PracticeDialog({required this.skills});

  final List<Skill> skills;

  @override
  State<_PracticeDialog> createState() => _PracticeDialogState();
}

class _PracticeDialogState extends State<_PracticeDialog> {
  late final Set<Skill> _on = Set<Skill>.of(widget.skills);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final all = _on.length == widget.skills.length;
    return AlertDialog(
      title: Text(l10n.deckPracticeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.deckPracticeBody,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: all,
              onChanged: (on) => setState(() {
                _on.clear();
                if (on ?? false) {
                  _on.addAll(widget.skills);
                }
              }),
              title: Text(
                l10n.deckPracticeAll,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            for (final skill in widget.skills)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _on.contains(skill),
                onChanged: (on) => setState(() {
                  (on ?? false) ? _on.add(skill) : _on.remove(skill);
                }),
                title: Text(skill.label(l10n)),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: _on.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<Skill>.of(_on)),
          child: Text(l10n.deckPracticeStart),
        ),
      ],
    );
  }
}
