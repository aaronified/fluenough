import 'package:flutter/material.dart';

import '../../core/achievements/achievement.dart';
import '../../core/languages/language_skills.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../languages/skill_widgets.dart';
import 'badge_tile.dart';
import 'badge_view.dart';

/// The categories of the badges page, as tabs (the approved mockup
/// `achievements`, revision 2).
enum AchievementTab { levels, skills, sets, other }

/// The badges of one course and the app, in the mockup's four tabs: Levels
/// (A1, A2 and B1, and the word counts), Skills (a Start and a Master for
/// each skill), Sets (word sets and grammar tables) and Other (first lesson,
/// days in a row, answers). Pure: it draws [report] and tells what was
/// tapped; the page opens the sheets.
class AchievementsView extends StatefulWidget {
  const AchievementsView({
    super.key,
    required this.report,
    required this.language,
    required this.onBadge,
    required this.onLevels,
    this.initialTab = AchievementTab.levels,
  });

  final AchievementReport report;
  final LanguageInfo language;

  /// A badge that is not a level was tapped.
  final void Function(BadgeView view) onBadge;

  /// A level badge was tapped: all the course's level badges, in order.
  final void Function(List<BadgeView> levels) onLevels;

  final AchievementTab initialTab;

  @override
  State<AchievementsView> createState() => _AchievementsViewState();
}

class _AchievementsViewState extends State<AchievementsView> {
  late AchievementTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final report = widget.report;
    final hasCourse = report.results.any((r) => !r.def.isAppWide);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      children: <Widget>[
        _TabBar(
          selected: _tab,
          onSelected: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: 8),
        if (!hasCourse && _tab != AchievementTab.other)
          _Note(text: l10n.achvNone)
        else
          ..._body(context, l10n),
      ],
    );
  }

  List<Widget> _body(BuildContext context, AppLocalizations l10n) {
    final report = widget.report;
    switch (_tab) {
      case AchievementTab.levels:
        final levels = chainViews(report.ofKind(AchievementKind.level));
        return <Widget>[
          _Heading(l10n.achvGroupLevels),
          _Grid(
            views: levels,
            columns: 3,
            onTap: (view) => widget.onLevels(levels),
          ),
          _Heading(l10n.achvGroupWords),
          _Grid(
            views: chainViews(report.ofKind(AchievementKind.wordCount)),
            columns: 3,
            onTap: widget.onBadge,
          ),
        ];
      case AchievementTab.skills:
        return _skills(context, l10n);
      case AchievementTab.sets:
        return _sets(l10n);
      case AchievementTab.other:
        return _other(l10n);
    }
  }

  List<Widget> _skills(BuildContext context, AppLocalizations l10n) {
    final report = widget.report;
    final keys = <SkillKey>[];
    for (final result in report.ofKind(AchievementKind.skillStart)) {
      final skill = result.def.skill;
      if (skill != null && !keys.contains(skill)) keys.add(skill);
    }
    const order = <SkillKind>[
      SkillKind.hear,
      SkillKind.speak,
      SkillKind.read,
      SkillKind.write,
      SkillKind.gesture,
    ];
    keys.sort((a, b) {
      final byKind = order.indexOf(a.kind).compareTo(order.indexOf(b.kind));
      return byKind != 0 ? byKind : (a.script ?? '').compareTo(b.script ?? '');
    });
    final scripts = <String>{
      for (final key in keys)
        if (key.script != null)
          l10n.scriptNameOr(key.script, widget.language.name),
    };
    final scriptText = scripts.join(', ');
    return <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.only(top: 8),
        child: _Note(
          text: scriptText.isEmpty
              ? l10n.achvSkillsIntro
              : l10n.achvSkillsIntroScript(scriptText),
        ),
      ),
      for (final key in keys) ...<Widget>[
        _SkillHeading(skillKey: key, language: widget.language),
        _Grid(
          views: chainViews(<AchievementResult>[
            for (final result in report.results)
              if (result.def.skill == key &&
                  (result.def.kind == AchievementKind.skillStart ||
                      result.def.kind == AchievementKind.skillMaster))
                result,
          ]),
          columns: 2,
          onTap: widget.onBadge,
        ),
      ],
    ];
  }

  List<Widget> _sets(AppLocalizations l10n) {
    final sets = widget.report.ofKind(AchievementKind.deckSet);
    final words = <AchievementResult>[
      for (final r in sets)
        if (!r.def.grammarSet) r,
    ];
    final grammar = <AchievementResult>[
      for (final r in sets)
        if (r.def.grammarSet) r,
    ];
    return <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.only(top: 8),
        child: _Note(text: l10n.achvSetsIntro),
      ),
      if (sets.isEmpty)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 16),
          child: _Note(text: l10n.achvSetsEmpty),
        ),
      if (words.isNotEmpty) ...<Widget>[
        _Heading(l10n.achvGroupWordSets),
        _Grid(views: chainViews(words), columns: 3, onTap: widget.onBadge),
      ],
      if (grammar.isNotEmpty) ...<Widget>[
        _Heading(l10n.achvGroupGrammarTables),
        _Grid(views: chainViews(grammar), columns: 3, onTap: widget.onBadge),
      ],
    ];
  }

  List<Widget> _other(AppLocalizations l10n) {
    final report = widget.report;
    final lesson = report
        .ofKind(AchievementKind.other)
        .where((r) => r.def.other == AchievementOther.firstLesson);
    final streaks = report
        .ofKind(AchievementKind.other)
        .where((r) => r.def.other == AchievementOther.streak);
    final answers = report
        .ofKind(AchievementKind.other)
        .where((r) => r.def.other == AchievementOther.answers);
    return <Widget>[
      if (lesson.isNotEmpty) ...<Widget>[
        _Heading(l10n.achvGroupFirsts),
        _Grid(views: chainViews(lesson), columns: 3, onTap: widget.onBadge),
      ],
      _Heading(l10n.achvGroupEveryLanguage),
      _Heading(l10n.achvGroupInARow),
      _Grid(views: chainViews(streaks), columns: 3, onTap: widget.onBadge),
      _Heading(l10n.achvGroupAnswers),
      _Grid(views: chainViews(answers), columns: 3, onTap: widget.onBadge),
    ];
  }
}

/// The row of tabs: Levels, Skills, Sets, Other.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelected});

  final AchievementTab selected;
  final void Function(AchievementTab tab) onSelected;

  String _label(AppLocalizations l10n, AchievementTab tab) => switch (tab) {
    AchievementTab.levels => l10n.achvTabLevels,
    AchievementTab.skills => l10n.achvTabSkills,
    AchievementTab.sets => l10n.achvTabSets,
    AchievementTab.other => l10n.achvTabOther,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: l10n.achvTabsSemantics,
      child: Container(
        padding: const EdgeInsetsDirectional.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          spacing: 4,
          children: <Widget>[
            for (final tab in AchievementTab.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: tab == selected,
                  inMutuallyExclusiveGroup: true,
                  excludeSemantics: true,
                  label: _label(l10n, tab),
                  onTap: () => onSelected(tab),
                  child: Material(
                    color: tab == selected
                        ? scheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelected(tab),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 2,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _label(l10n, tab),
                            maxLines: 1,
                            style: theme.textTheme.labelLarge!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: tab == selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A group's heading over its grid.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16, bottom: 6),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.labelLarge!.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A skill's heading: its icon and name, and for Read and Write the script.
class _SkillHeading extends StatelessWidget {
  const _SkillHeading({required this.skillKey, required this.language});

  final SkillKey skillKey;
  final LanguageInfo language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = skillKey.kind.label(l10n);
    final script = skillKey.script;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16, bottom: 6),
      child: Semantics(
        header: true,
        child: Row(
          spacing: 8,
          children: <Widget>[
            Icon(skillKey.kind.icon, size: 20, color: scheme.onSurfaceVariant),
            Expanded(
              child: Text(
                script == null
                    ? label
                    : l10n.achvSkillHeading(
                        label,
                        l10n.scriptNameOr(script, language.name),
                      ),
                style: theme.textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet line of explanation.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// [views] in [columns] even columns: each row as tall as its tallest tile.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.views,
    required this.columns,
    required this.onTap,
  });

  final List<BadgeView> views;
  final int columns;
  final void Function(BadgeView view) onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < views.length; start += columns) {
      final row = views.skip(start).take(columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: <Widget>[
              for (var i = 0; i < columns; i++)
                Expanded(
                  child: i < row.length
                      ? BadgeTile(view: row[i], onTap: () => onTap(row[i]))
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: rows,
    );
  }
}
