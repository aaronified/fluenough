import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/skill.dart';
import '../../core/scheduling/skill_fit.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/mode_pill.dart';
import 'settings_controls.dart';

/// Settings' "Adjust to me": FSRS fitted to the learner, per skill and
/// language (ADR-0035; mockup
/// `docs/mockups/adapted-to-you.html`, Settings).
///
/// The row's Adjust button fits every skill that can be fitted now, with a
/// progress bar under the row while it runs, then shows what changed in a
/// sheet ([showAdjustedSheet]). Until some skill holds enough answers the
/// button is disabled and the row says "Needs more answers first". Beside
/// it, the switch for the automatic refit, on by default, and a line
/// saying that nothing leaves the phone.
class AdjustSection extends StatelessWidget {
  const AdjustSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final tuner = state.tuner;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        tuner,
        state.settings,
        state.progress,
      ]),
      builder: (context, _) {
        final busy = tuner.busy;
        final canAdjust = tuner.canAdjust;
        final current = tuner.current;
        final String status;
        if (busy && current != null) {
          status = l10n.settingsAdjusting(
            _languageName(state, current.language),
            current.mode.name,
            (tuner.done + 1).clamp(1, tuner.total),
            tuner.total,
          );
        } else if (!canAdjust) {
          status = l10n.settingsAdjustNeedsMore;
        } else if (tuner.lastAdjusted case final last?) {
          status = DateUtils.isSameDay(last, state.now())
              ? l10n.settingsAdjustLastToday
              : l10n.settingsAdjustLast(last);
        } else {
          status = l10n.settingsAdjustNotYet;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GroupedList.settings(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // The line under the title says how far adjusting
                    // has got: read out as it changes.
                    Semantics(
                      liveRegion: busy,
                      child: GroupedTile(
                        leading: const Icon(Icons.tune),
                        title: l10n.settingsAdjust,
                        subtitle: status,
                        trailing: FilledButton.tonal(
                          onPressed: busy || !canAdjust
                              ? null
                              : () => _adjust(context, state),
                          child: Text(l10n.settingsAdjustButton),
                        ),
                      ),
                    ),
                    if (busy)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          60,
                          0,
                          20,
                          16,
                        ),
                        child: LinearProgressIndicator(
                          value: tuner.total == 0
                              ? null
                              : tuner.done / tuner.total,
                          semanticsLabel: l10n.settingsAdjustingLabel,
                        ),
                      ),
                  ],
                ),
                GroupedTile.toggle(
                  leading: const Icon(Icons.autorenew),
                  title: l10n.settingsAdjustAuto,
                  subtitle: l10n.settingsAdjustAutoDesc,
                  value: state.settings.autoAdjust,
                  onChanged: (on) => state.settings.autoAdjust = on,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.settingsAdjustHelp,
                      style: settingsHelpStyle(theme),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _adjust(BuildContext context, AppState state) async {
    final results = await state.tuner.adjustAll();
    if (results == null || !context.mounted) return;
    await showAdjustedSheet(context, state, results);
  }
}

/// The name of the language [code], as its deck files give it, or the code.
String _languageName(AppState state, String code) {
  for (final language in state.languages) {
    if (language.code == code) return language.name;
  }
  return code;
}

/// "Adjusted to you": every skill a fit looked at, what changed for it or
/// that it is not adjusted yet, in the languages the profile learns (all,
/// when it learns none of them), with a heading per language when there
/// are several. "How you learn" leaves the sheet for that page.
Future<void> showAdjustedSheet(
  BuildContext context,
  AppState state,
  List<SkillFitResult> results,
) {
  final learned = <SkillFitResult>[
    for (final r in results)
      if (state.currentProfile.learns(r.key.language)) r,
  ];
  final shown = (learned.isEmpty ? results : learned).toList()
    ..sort((a, b) {
      final byLanguage = a.key.language.compareTo(b.key.language);
      return byLanguage != 0
          ? byLanguage
          : a.key.mode.index.compareTo(b.key.mode.index);
    });
  final languages = <String>{for (final r in shown) r.key.language};
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final muted = theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      final rows = <Widget>[];
      String? heading;
      for (final r in shown) {
        if (languages.length > 1 && heading != r.key.language) {
          heading = r.key.language;
          rows.add(
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 12),
              child: Semantics(
                header: true,
                child: Text(
                  _languageName(state, heading),
                  style: theme.textTheme.titleSmall!.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          );
        }
        rows.add(_ResultRow(result: r));
      }
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.adjustedTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Text(l10n.adjustedSubtitle, style: muted),
              const SizedBox(height: 8),
              ...rows,
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.adjustedPrivacy,
                      style: settingsHelpStyle(theme),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  TextButton(
                    onPressed: () =>
                        AppNavigator.openHowYouLearn(context, replacing: true),
                    child: Text(l10n.howYouLearnTitle),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonDone),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One skill in the sheet: its pill, which way it moved, and by how much.
/// "More reviews" is never in the error colour: forgetting faster is not a
/// fault.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});

  final SkillFitResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mode = result.key.mode.name;
    final before = result.before;
    final after = result.after;
    final fitted = result.fitted != null;
    final direction = fitted ? SkillFit.direction(before, after) : 0;
    final (IconData icon, Color colour, String title, String detail) = !fitted
        ? (
            Icons.hourglass_empty,
            scheme.onSurfaceVariant,
            l10n.adjustedNotYet(mode),
            l10n.adjustedNotYetDetail,
          )
        : switch (direction) {
            < 0 => (
              Icons.south,
              scheme.primary,
              l10n.adjustedFewer(mode),
              l10n.adjustedChange(
                after.days,
                before.days,
                after.reviews,
                before.reviews,
              ),
            ),
            > 0 => (
              Icons.north,
              scheme.tertiary,
              l10n.adjustedMore(mode),
              l10n.adjustedChange(
                after.days,
                before.days,
                after.reviews,
                before.reviews,
              ),
            ),
            _ => (
              Icons.drag_handle,
              scheme.onSurfaceVariant,
              l10n.adjustedSame(mode),
              l10n.adjustedSameDetail(after.days),
            ),
          };
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: ModePill(
                skill: Skill.of(result.key.mode),
                size: ModePillSize.small,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2),
                        child: Icon(icon, size: 18, color: colour),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(title, style: theme.textTheme.titleSmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 24),
                    child: Text(
                      detail,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
