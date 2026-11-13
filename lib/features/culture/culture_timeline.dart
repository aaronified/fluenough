import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/culture.dart';
import '../../app/routes.dart';
import '../../core/decks/timeline_entries.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/page_parts.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/system_bar.dart';
import '../decks/result_marks.dart';
import 'culture_parts.dart';

/// How an event of the line stands to the learner: this one (the work or the
/// person being looked at), met (every card of the item is taught), not met
/// yet, or today.
enum _Stand { thisOne, met, notYet, today }

_Stand _standOf(AppState state, TimelineEntry entry, String? creatorId) {
  if (entry.kind == TimelineEntryKind.today) return _Stand.today;
  if (creatorId != null && entry.creator?.id == creatorId) {
    return _Stand.thisOne;
  }
  final item = entry.item;
  if (item != null && state.isCultureItemDone(item)) return _Stand.met;
  return _Stand.notYet;
}

IconData _iconOf(_Stand stand) => switch (stand) {
  _Stand.thisOne => Icons.radio_button_checked,
  _Stand.met => Icons.check_circle,
  _Stand.notYet => Icons.circle_outlined,
  _Stand.today => Icons.flag,
};

Color _colorOf(BuildContext context, _Stand stand) {
  final scheme = Theme.of(context).colorScheme;
  return switch (stand) {
    _Stand.thisOne => amberOf(context),
    _Stand.met => scheme.primary,
    _Stand.notYet => scheme.outline,
    _Stand.today => scheme.primary,
  };
}

/// What an event says: a work as `Creator · Work`, a legacy item by its text,
/// and today.
String _labelOf(
  BuildContext context,
  AppState state,
  String language,
  TimelineEntry entry,
) {
  final l10n = AppLocalizations.of(context)!;
  final spoken = cultureSpoken(context, state);
  switch (entry.kind) {
    case TimelineEntryKind.today:
      return l10n.cultureTimelineToday;
    case TimelineEntryKind.legacy:
      return entry.legacy?.textFor(spoken) ?? '';
    case TimelineEntryKind.work:
      final item = entry.item!;
      final work =
          item.source?.work ??
          item.source?.collection ??
          item.target.split('\n').first;
      final who = entry.creator?.nameFor(spoken, target: language).text;
      return who == null ? work : l10n.cultureTimelineWork(who, work);
  }
}

/// The line as a strip, one dot to an event, scrolling sideways to today
/// (approved mockup, variant A): the person in [creatorId] marked, what the
/// learner has met filled, what is ahead outlined. "Full timeline" opens the
/// screen. Nothing for a language with no events.
class TimelineStrip extends StatelessWidget {
  const TimelineStrip({super.key, required this.language, this.creatorId});

  final String language;
  final String? creatorId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entries = state.cultureTimelineEntriesOf(language);
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          container: true,
          label: l10n.cultureTimelineStripLabel,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final (i, entry) in entries.indexed)
                    _StripEvent(
                      entry: entry,
                      stand: _standOf(state, entry, creatorId),
                      label: _labelOf(context, state, language, entry),
                      first: i == 0,
                      last: i == entries.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ),
        TextButton(
          style: AppButtonStyles.inline(context),
          onPressed: () =>
              AppNavigator.openCultureTimeline(context, language, creatorId),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  l10n.cultureTimelineFull,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class _StripEvent extends StatelessWidget {
  const _StripEvent({
    required this.entry,
    required this.stand,
    required this.label,
    required this.first,
    required this.last,
  });

  final TimelineEntry entry;
  final _Stand stand;
  final String label;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = _colorOf(context, stand);
    final year = entry.kind == TimelineEntryKind.today
        ? l10n.cultureTimelineToday
        : '${entry.year}';
    final spoken = switch (stand) {
      _Stand.thisOne => l10n.cultureTimelineThis,
      _Stand.met => l10n.cultureTimelineMet,
      _Stand.notYet => l10n.cultureTimelineNotYet,
      _Stand.today => '',
    };
    return Semantics(
      container: true,
      label: stand == _Stand.today
          ? year
          : l10n.cultureTimelineEventLabel(year, label, spoken),
      child: ExcludeSemantics(
        child: SizedBox(
          width: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      height: 2,
                      color: first ? Colors.transparent : scheme.outlineVariant,
                    ),
                  ),
                  Icon(_iconOf(stand), size: 20, color: colour),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: last ? Colors.transparent : scheme.outlineVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      year,
                      style: theme.textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: stand == _Stand.thisOne ? colour : null,
                      ),
                    ),
                    if (stand != _Stand.today)
                      Text(
                        label,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What opens the timeline screen: the language, and the person to mark.
class CultureTimelineRequest {
  const CultureTimelineRequest({required this.language, this.creatorId});

  final String language;
  final String? creatorId;
}

/// The full timeline (approved mockup, screen 4): the works the learner has
/// met and this one, grouped by the language's own eras, running to today with
/// what the person still means now.
class CultureTimelinePage extends StatelessWidget {
  const CultureTimelinePage({super.key, required this.request});

  final CultureTimelineRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final language = request.language;
    final info = cultureLanguage(state, language);
    final file = state.creatorsOf(language);
    final entries = state.cultureTimelineEntriesOf(language);
    final creator = request.creatorId == null
        ? null
        : file?.byId(request.creatorId!);
    final spoken = cultureSpoken(context, state);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final legacy = creator?.legacyFor(state.levelIn(language), spoken);
    final children = <Widget>[];
    String? band;
    for (final entry in entries) {
      final era = entry.era;
      final bandId = entry.kind == TimelineEntryKind.today ? null : era?.id;
      if (era != null && bandId != band) {
        band = bandId;
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSizes.textInset,
              16,
              AppSizes.textInset,
              4,
            ),
            child: Semantics(
              header: true,
              child: Text(
                eraNameText(era, language, spoken),
                style: theme.textTheme.titleSmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }
      final stand = _standOf(state, entry, request.creatorId);
      final item = entry.item;
      final label = _labelOf(context, state, language, entry);
      final standText = switch (stand) {
        _Stand.thisOne => l10n.cultureTimelineThis,
        _Stand.met => l10n.cultureTimelineMet,
        _Stand.notYet => l10n.cultureTimelineNotYet,
        _Stand.today => '',
      };
      children.add(
        ListTile(
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSizes.textInset,
          ),
          leading: Icon(_iconOf(stand), color: _colorOf(context, stand)),
          title: Text(
            entry.kind == TimelineEntryKind.today
                ? l10n.cultureTimelineToday
                : l10n.cultureTimelineYearLabel(entry.year, label),
          ),
          subtitle: standText.isEmpty ? null : Text(standText),
          onTap: item == null
              ? null
              : () => AppNavigator.openCultureItem(context, language, item.id),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cultureTimelineTitle),
        actions: const <Widget>[ReportButton()],
      ),
      body: entries.isEmpty
          ? EmptyState(icon: Icons.timeline, title: l10n.cultureTimelineEmpty)
          : ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                0,
                8,
                0,
                24,
              ).clearingSystemBar(context),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSizes.textInset,
                  ),
                  child: Text(
                    creator == null
                        ? l10n.cultureTimelineIntro(info.name)
                        : l10n.cultureTimelineIntroCreator(
                            creator.nameFor(spoken, target: language).text,
                            info.name,
                          ),
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...children,
                if (legacy != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      12,
                      16,
                      0,
                    ),
                    child: LegacyBlock(view: legacy, language: info),
                  ),
              ],
            ),
    );
  }
}
