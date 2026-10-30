import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/situations.dart';
import '../../core/models/situation.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/incoming.dart';
import '../situations/situation_page.dart';
import '../situations/situation_visuals.dart';

/// The situation buttons on Today, under quick revision (#724): one button
/// for each of the six everyday moments, hailing a cab to the rail station,
/// each in a colour of its own, with how many of its cards the learner has
/// not met yet. A button opens its sheet.
///
/// A course whose situations are not written shows the same buttons dimmed
/// with an "Upcoming" pill and no counts (owner, 2026-10-30: "Other decks
/// show the Situations card blank, with the upcoming pill"). Mockup
/// `docs/mockups/situations.html`, screen 1.
class SituationsCard extends StatelessWidget {
  const SituationsCard({super.key});

  /// How many buttons sit in a row.
  static const int perRow = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final language = state.situationsLanguage;
    final file = language == null ? null : state.situationsOf(language);
    final buttons = <_ButtonSpec>[
      for (final key in situationIcons)
        _spec(context, state, language, file?.withIcon(key), key),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSizes.textInset,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.todaySituationsTitle,
                    style: theme.textTheme.sectionTitle,
                  ),
                ),
              ),
              if (file != null) ...<Widget>[
                Icon(
                  Icons.offline_pin_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.situationsOffline,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (
          var start = 0;
          start < buttons.length;
          start += perRow
        ) ...<Widget>[
          if (start > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: <Widget>[
                for (var i = start; i < start + perRow; i++)
                  Expanded(
                    child: i < buttons.length
                        ? _SituationButton(spec: buttons[i])
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  _ButtonSpec _spec(
    BuildContext context,
    AppState state,
    String? language,
    Situation? sheet,
    String key,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (sheet == null || language == null) {
      return _ButtonSpec(
        icon: key,
        title: key.situationName(l10n),
        count: null,
        onTap: () => showIncomingSnackBar(context),
      );
    }
    return _ButtonSpec(
      icon: key,
      title: sheet.titleFor(state.settings.spokenLanguages),
      count: state.newCardsIn(language, sheet),
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.situation,
        arguments: SituationRequest(language: language, situationId: sheet.id),
      ),
    );
  }
}

/// What one button shows: its icon key, its title, how many cards are new
/// (null while the course has no sheet) and what a tap does.
class _ButtonSpec {
  const _ButtonSpec({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  final String icon;
  final String title;
  final int? count;
  final VoidCallback onTap;

  bool get live => count != null;
}

class _SituationButton extends StatelessWidget {
  const _SituationButton({required this.spec});

  final _ButtonSpec spec;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = spec.icon.situationColor(context);
    final count = spec.count;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.onContainer.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(spec.icon.situationIcon, color: colors.onContainer),
        ),
        const SizedBox(height: 6),
        Text(
          spec.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge!.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onContainer,
          ),
        ),
        if (count != null && count > 0)
          Text(
            l10n.situationNewCount(count),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall!.copyWith(
              color: colors.onContainer,
            ),
          ),
      ],
    );
    final face = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 6,
        vertical: 12,
      ),
      child: spec.live
          ? content
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Opacity(opacity: kIncomingOpacity, child: content),
                const SizedBox(height: 6),
                // Full contrast, so the state is not shown by dimming alone.
                const _UpcomingPill(),
              ],
            ),
    );
    final button = Material(
      color: colors.container,
      borderRadius: BorderRadius.circular(AppRadii.field),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.field),
        onTap: spec.onTap,
        child: face,
      ),
    );
    return Semantics(
      button: true,
      label: spec.live
          ? l10n.situationButtonLabel(spec.title, count ?? 0)
          : l10n.situationUpcomingLabel(spec.title),
      excludeSemantics: true,
      onTap: spec.onTap,
      child: button,
    );
  }
}

class _UpcomingPill extends StatelessWidget {
  const _UpcomingPill();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        AppLocalizations.of(context)!.situationUpcoming,
        maxLines: 1,
        style: Theme.of(context).textTheme.badge
            .copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
