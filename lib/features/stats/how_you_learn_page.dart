import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/shell_tab.dart';
import '../../app/skill.dart';
import '../../core/models/drill_mode.dart';
import '../../core/scheduling/skill_fit.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/mode_pill.dart';
import '../../ui/widgets/pace_parts.dart';
import '../../ui/widgets/report_button.dart';

/// The order skills are listed in: Today's tiles', then passages.
const List<DrillMode> _order = <DrillMode>[
  DrillMode.recognition,
  DrillMode.listening,
  DrillMode.speaking,
  DrillMode.production,
  DrillMode.grammar,
  DrillMode.reading,
];

/// How you learn (ADR-0035, "Shown prominently"; mockup
/// `docs/mockups/adapted-to-you.html`, screen 4): per skill, how fast the
/// learner forgets beside how every skill starts.
///
/// For each skill with answers: one plain sentence ("A heard word you get
/// right comes back in 6 days, not 4."), a bar of the gap a right answer
/// gives, the learner's filled and the start's as a tick, which way that
/// moved the reviews in the plan's words, and the next 30 days' reviews.
/// A skill not adjusted yet says how many answers it has, and, if a fit
/// kept the start's pace, that it did. Until some skill is adjusted (a
/// fit that kept the defaults is not, as on Today and Progress) the page
/// says what will happen, and points to Settings.
///
/// [language] alone, when given (Progress's chosen language); else every
/// language the profile learns, with a heading each when there are
/// several. The figures are [SkillFit]'s, worked out off the main thread
/// by `AppState.pacing`.
class HowYouLearnPage extends StatelessWidget {
  const HowYouLearnPage({super.key, this.language});

  final String? language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.howYouLearnTitle),
        actions: const <Widget>[ReportButton()],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            state.pacing,
            state.progress,
          ]),
          builder: (context, _) {
            final paces = state.pacing.paces;
            if (paces == null) {
              return Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.howYouLearnWorking,
                ),
              );
            }
            return _Body(
              state: state,
              paces: _shown(state, paces.values),
              someAdjusted: state.pacing.adjusted,
            );
          },
        ),
      ),
    );
  }

  /// [paces] in [language], or in the languages the profile learns (all,
  /// when it learns none of them), by language and then skill.
  List<SkillPace> _shown(AppState state, Iterable<SkillPace> paces) {
    final code = language;
    final learned = <SkillPace>[
      for (final p in paces)
        if (code == null
            ? state.currentProfile.learns(p.key.language)
            : p.key.language == code)
          p,
    ];
    final shown = code == null && learned.isEmpty ? paces.toList() : learned;
    return shown..sort((a, b) {
      final byLanguage = a.key.language.compareTo(b.key.language);
      return byLanguage != 0
          ? byLanguage
          : _order.indexOf(a.key.mode).compareTo(_order.indexOf(b.key.mode));
    });
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.paces,
    required this.someAdjusted,
  });

  final AppState state;
  final List<SkillPace> paces;

  /// Whether some fit kept a set other than the defaults, in any language.
  final bool someAdjusted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final languages = <String>{for (final p in paces) p.key.language};
    // One scale for every bar, so that the skills compare: a third more
    // than the longest gap, up to a round number.
    final longest = paces.fold<int>(
      1,
      (most, p) => math.max(most, math.max(p.start.days, p.now.days)),
    );
    final axis = _roundUp((longest * 4 / 3).ceil());
    final shownAdjusted = paces.any((p) => p.adjusted);

    final children = <Widget>[
      Text(l10n.howYouLearnIntro, style: theme.textTheme.bodyLarge),
      if (!someAdjusted) ...<Widget>[
        const SizedBox(height: 16),
        _NotYet(state: state),
      ],
      if (shownAdjusted) ...<Widget>[
        const SizedBox(height: 16),
        const _Legend(),
      ],
    ];
    for (final code in languages) {
      final group = <Widget>[
        for (final p in paces)
          if (p.key.language == code)
            _SkillRow(pace: p, axis: axis, state: state),
      ];
      children.add(const SizedBox(height: 16));
      if (languages.length > 1) {
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                _languageName(state, code),
                style: theme.textTheme.titleSmall!.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        );
      }
      children.add(GroupedList(gap: 2, children: group));
    }

    final footnote = _lastFit(context, languages);
    if (footnote != null) {
      children.addAll(<Widget>[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 64, end: 16),
          child: Text(footnote, style: muted),
        ),
      ]);
    }
    children.addAll(<Widget>[
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 36,
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.adjustedPrivacy, style: muted)),
          ],
        ),
      ),
    ]);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
      children: children,
    );
  }

  /// "Adjusted today, from 2,140 of your answers.": the latest fit of the
  /// [languages] shown that adjusted its skill, and the answers those fits
  /// were made from. A fit that kept the defaults adjusted nothing, so it
  /// is not counted; with only those, there is no footnote.
  String? _lastFit(BuildContext context, Set<String> languages) {
    final l10n = AppLocalizations.of(context)!;
    DateTime? last;
    var answers = 0;
    for (final MapEntry(:key, :value)
        in state.progress.parameters.fitted.entries) {
      if (!languages.contains(key.language)) continue;
      if (SkillFit.isDefaults(value.values)) continue;
      answers += value.reviewCount;
      if (last == null || value.fittedAt.isAfter(last)) last = value.fittedAt;
    }
    if (last == null) return null;
    return DateUtils.isSameDay(last, state.now())
        ? l10n.paceAdjustedToday(answers)
        : l10n.paceAdjustedOn(last, answers);
  }
}

/// Until some skill is adjusted: what will happen, and the way to
/// Settings, where "Adjust to me" is.
class _NotYet extends StatelessWidget {
  const _NotYet({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.howYouLearnNone,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                AppNavigator.backToShell(context, tab: ShellTab.settings),
            child: Text(l10n.howYouLearnOpenSettings),
          ),
        ],
      ),
    );
  }
}

/// "You" (the filled part of a bar) and "At the start" (its tick).
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall!.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );
    Widget key(Widget mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: style)),
      ],
    );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        children: <Widget>[
          key(
            Container(
              width: 16,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            l10n.howYouLearnLegendYou,
          ),
          key(
            Container(
              width: 2,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.onSurface,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            l10n.howYouLearnLegendStart,
          ),
        ],
      ),
    );
  }
}

/// One skill: its pill and name, then under the name its sentence, its
/// bar, which way it moved, and its next 30 days.
class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.pace,
    required this.axis,
    required this.state,
  });

  final SkillPace pace;

  /// The days at the bar's far end.
  final int axis;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mode = pace.key.mode.name;
    final start = pace.start;
    final now = pace.now;
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final body = <Widget>[];
    if (!pace.adjusted) {
      body.addAll(<Widget>[
        Text(
          // A fit that lost to the start's pace kept it: the skill did
          // have enough answers.
          state.progress.parameters.fitted.containsKey(pace.key)
              ? l10n.paceKeptStart(pace.answers)
              : l10n.paceNotYet(pace.answers),
          style: theme.textTheme.bodyMedium,
        ),
        _Track(days: null, start: start.days, axis: axis),
        _Verdict(
          icon: Icons.hourglass_empty,
          text: l10n.adjustedNotYet(mode),
          background: scheme.surfaceContainerHigh,
          foreground: scheme.onSurfaceVariant,
        ),
      ]);
    } else {
      final direction = PaceDirection.of(start, now);
      final source = state.progress.parameters.sourceOf(
        pace.key.language,
        pace.key.mode,
      );
      final (Color background, Color foreground) = switch (direction) {
        PaceDirection.fewer => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
        PaceDirection.more => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
        PaceDirection.same => (
          scheme.surfaceContainerHigh,
          scheme.onSurfaceVariant,
        ),
      };
      body.addAll(<Widget>[
        Text(
          now.days == start.days
              ? l10n.paceComesBackSame(mode, now.days)
              : l10n.paceComesBack(mode, now.days, start.days),
          style: theme.textTheme.bodyMedium,
        ),
        if (source != null && source != pace.key.language)
          Text(l10n.paceBorrowed(_languageName(state, source)), style: muted),
        _Track(days: now.days, start: start.days, axis: axis),
        _Verdict(
          icon: direction.icon,
          text: direction.verdict(l10n, mode),
          background: background,
          foreground: foreground,
        ),
        Text(
          now.reviews == start.reviews
              ? l10n.paceReviewsSteady(now.reviews)
              : l10n.paceReviews(now.reviews, start.reviews),
          style: muted,
        ),
      ]);
    }

    return Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: ModePill(
              skill: Skill.of(pace.key.mode),
              size: ModePillSize.small,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.paceSkillName(mode),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                for (final child in body) ...<Widget>[
                  const SizedBox(height: 8),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The gap a right answer gives, on a bar from 0 to [axis] days: the
/// learner's [days] filled, the [start]'s a tick. With no [days], the
/// skill is not adjusted: an empty outline and the tick.
class _Track extends StatelessWidget {
  const _Track({required this.days, required this.start, required this.axis});

  final int? days;
  final int start;
  final int axis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final filled = days;
    double at(int d) => math.min(d, axis) / axis;
    final bar = SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              PositionedDirectional(
                start: 0,
                end: 0,
                top: 4,
                height: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: filled == null
                        ? null
                        : scheme.surfaceContainerHighest,
                    border: filled == null
                        ? Border.all(color: scheme.outline, width: 1.5)
                        : null,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              if (filled != null)
                PositionedDirectional(
                  start: 0,
                  top: 4,
                  height: 10,
                  width: width * at(filled),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              PositionedDirectional(
                start: (width * at(start) - 1).clamp(
                  0.0,
                  math.max(0.0, width - 2),
                ),
                top: 0,
                width: 2,
                height: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onSurface,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    final style = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          label: filled == null ? null : l10n.paceTrackLabel(filled, start),
          child: bar,
        ),
        ExcludeSemantics(
          child: Row(
            children: <Widget>[
              Text(NumberFormat.decimalPattern(locale).format(0), style: style),
              const Spacer(),
              Text(l10n.paceAxisEnd(axis), style: style),
            ],
          ),
        ),
      ],
    );
  }
}

/// Which way a skill moved, as a small tonal label: an arrow and words.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 10, 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 1),
              child: Icon(icon, size: 16, color: foreground),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [days] up to a round number of days for a bar's far end: 2, 4, 6, 8
/// or 10; then fives, tens, thirties and hundreds.
int _roundUp(int days) {
  final step = days <= 10
      ? 2
      : days <= 50
      ? 5
      : days <= 100
      ? 10
      : days <= 365
      ? 30
      : 100;
  return math.max(step, (days / step).ceil() * step);
}

/// The name of the language [code], as its deck files give it, or the code.
String _languageName(AppState state, String code) {
  for (final language in state.languages) {
    if (language.code == code) return language.name;
  }
  return code;
}
