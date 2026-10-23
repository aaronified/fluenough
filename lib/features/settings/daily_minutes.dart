import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/scheduling/daily_budget.dart';
import '../../l10n/app_localizations.dart';

/// "Minutes a day" on a learned course in Languages I'm learning (#485): how
/// long a day the learner gives it, as presets of 5, 10, 15, 20 and 30
/// minutes and a custom value from 5 to 60, 15 until chosen, and what the
/// minutes buy in cards. The onboarding step waits for #474.
///
/// Mockup `docs/mockups/today-chain.html`, screen 2, "Presets + custom".
class DailyMinutes extends StatelessWidget {
  const DailyMinutes({super.key, required this.language});

  /// The course's language, by code.
  final String language;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final minutes = state.settings.dailyMinutesFor(language);
    final perCard = state.secondsPerCardIn(language);
    final custom = !DailyBudget.presets.contains(minutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MergeSemantics(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.minutesTitle,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              Text(
                l10n.minutesValue(minutes),
                style: theme.textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          container: true,
          label: l10n.minutesTitle,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final preset in DailyBudget.presets)
                ChoiceChip(
                  key: ValueKey<String>('minutes-$language-$preset'),
                  label: Text('$preset'),
                  selected: minutes == preset,
                  onSelected: (_) =>
                      state.settings.setDailyMinutes(language, preset),
                ),
              ChoiceChip(
                key: ValueKey<String>('minutes-$language-custom'),
                label: Text(
                  custom
                      ? l10n.minutesCustomValue(minutes)
                      : l10n.minutesCustom,
                ),
                selected: custom,
                onSelected: (_) => _chooseCustom(context, state, minutes),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.minutesCards(
            DailyBudget.cardsFor(minutes, secondsPerCard: perCard),
            NumberFormat('#.#', locale).format(perCard),
          ),
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _chooseCustom(
    BuildContext context,
    AppState state,
    int current,
  ) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _CustomMinutes(
        initial: current,
        perCard: state.secondsPerCardIn(language),
      ),
    );
    if (chosen != null) state.settings.setDailyMinutes(language, chosen);
  }
}

/// The sheet for a number of minutes of the learner's own: a minus, the
/// number and a plus, what it buys, and Cancel and Save.
class _CustomMinutes extends StatefulWidget {
  const _CustomMinutes({required this.initial, required this.perCard});

  final int initial;
  final double perCard;

  @override
  State<_CustomMinutes> createState() => _CustomMinutesState();
}

class _CustomMinutesState extends State<_CustomMinutes> {
  late int _minutes = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.minutesCustomTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.minutesCustomHint(
                DailyBudget.minMinutes,
                DailyBudget.maxMinutes,
              ),
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton.outlined(
                  tooltip: l10n.minutesLess,
                  onPressed: _minutes > DailyBudget.minMinutes
                      ? () => setState(() => _minutes--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 16),
                Text('$_minutes', style: theme.textTheme.displaySmall),
                const SizedBox(width: 16),
                IconButton.outlined(
                  tooltip: l10n.minutesMore,
                  onPressed: _minutes < DailyBudget.maxMinutes
                      ? () => setState(() => _minutes++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.minutesCustomCards(
                DailyBudget.cardsFor(_minutes, secondsPerCard: widget.perCard),
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 8,
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_minutes),
                  child: Text(l10n.minutesSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
