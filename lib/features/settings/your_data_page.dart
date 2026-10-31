import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/features.dart';
import '../../app/memory_progress.dart';
import '../../app/skill.dart';
import '../../core/data/log_jsonl.dart';
import '../../core/models/card.dart' as model;
import '../../core/scheduling/fsrs.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/skill_visuals.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/system_bar.dart';
import 'backup_section.dart';
import 'settings_controls.dart';

/// Settings' Your data page, the backup page itself (owner, 2026-10-12):
/// [BackupSection], then the review log fully expanded, never folded, on
/// one page. The log is its intro, Export review log and Import review log
/// as rows, then every answer by day, newest first, each the card in its
/// script with its reading, its meaning, the activity, the time and the
/// rating.
class YourDataPage extends StatelessWidget {
  const YourDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsRowData),
        actions: const <Widget>[ReportButton()],
      ),
      body: ListenableBuilder(
        listenable: state.progress,
        builder: (context, _) => _Body(state: state),
      ),
    );
  }
}

/// The page's list. The log shows the newest [_Body.fewRows] answers, or up
/// to [_Body.manyRows] once expanded (owner, 2026-10-17: "It should show last
/// 10 rows, and be expandable upto 50 rows. The log export anyway does export
/// all logs").
class _Body extends StatefulWidget {
  const _Body({required this.state});

  final AppState state;

  static const int fewRows = 10;
  static const int manyRows = 50;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _expanded = false;

  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final log = state.progress.log;
    // Newest first, grouped by calendar day.
    final all = <ReviewEvent>[...log]..sort((a, b) => b.at.compareTo(a.at));
    final limit = _expanded ? _Body.manyRows : _Body.fewRows;
    final events = all.take(limit).toList();
    final cards = <String, model.Card>{
      for (final entry in state.decks)
        for (final card in entry.cards) '${entry.id}\u0000${card.id}': card,
    };
    final today = state.now();
    final days = <DateTime, List<ReviewEvent>>{};
    for (final event in events) {
      final at = event.at;
      days
          .putIfAbsent(
            DateTime(at.year, at.month, at.day),
            () => <ReviewEvent>[],
          )
          .add(event);
    }
    final help = settingsHelpStyle(Theme.of(context));
    final top = <Widget>[
      const BackupSection(),
      const SizedBox(height: 20),
      SettingsHeading(l10n.settingsDataLog),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSizes.textInset,
        ),
        child: Text(l10n.settingsDataLogIntro(log.length), style: help),
      ),
      const SizedBox(height: 12),
      GroupedList.settings(
        children: <Widget>[
          GroupedTile(
            leading: const Icon(Icons.file_download_outlined),
            title: l10n.settingsExport,
            subtitle: l10n.settingsExportDesc(log.length),
            feature: Feature.logExport,
            padding: _tallRow,
            onTap: () => _export(context, state),
          ),
          GroupedTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: l10n.settingsImport,
            subtitle: l10n.settingsImportDesc,
            feature: Feature.logImport,
            padding: _tallRow,
            onTap: () => _import(context, state),
          ),
        ],
      ),
    ];
    // One item per day heading and per answer, so that a long log is built
    // as it scrolls.
    final items = <_LogItem>[
      for (final MapEntry(key: day, value: dayEvents)
          in days.entries) ...<_LogItem>[
        _LogItem.day(day),
        for (var i = 0; i < dayEvents.length; i++)
          _LogItem.answer(
            dayEvents[i],
            first: i == 0,
            last: i == dayEvents.length - 1,
          ),
      ],
    ];
    final bottom = <Widget>[
      if (all.length > events.length || _expanded) ...<Widget>[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSizes.textInset,
          ),
          child: Text(
            l10n.settingsDataLogShowing(events.length, all.length),
            style: help,
          ),
        ),
        if (all.length > _Body.fewRows)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey<String>('review-log-more'),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? l10n.settingsDataLogFewer
                    : l10n.settingsDataLogMore(
                        all.length < _Body.manyRows
                            ? all.length
                            : _Body.manyRows,
                      ),
              ),
            ),
          ),
      ],
    ];
    return ListView.builder(
      padding: const EdgeInsetsDirectional.fromSTEB(
        16,
        8,
        16,
        24,
      ).clearingSystemBar(context),
      itemCount: top.length + items.length + bottom.length,
      itemBuilder: (context, i) {
        if (i < top.length) return top[i];
        if (i >= top.length + items.length) {
          return bottom[i - top.length - items.length];
        }
        final item = items[i - top.length];
        if (item.event case final event?) {
          return _Answer(
            event: event,
            card: cards['${event.deckId}\u0000${event.cardId}'],
            first: item.first,
            last: item.last,
          );
        }
        return Padding(
          padding: const EdgeInsetsDirectional.only(top: 20, bottom: 8),
          child: SettingsHeading(_dayName(context, item.day!, today)),
        );
      },
    );
  }

  static String _dayName(BuildContext context, DateTime day, DateTime now) {
    final l10n = AppLocalizations.of(context)!;
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l10n.settingsDataToday;
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return l10n.settingsDataYesterday;
    }
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }

  /// Saves the review log as `fluenough-<profile>-reviews.jsonl`, where the
  /// learner picks.
  static Future<void> _export(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final name = 'fluenough-${state.currentProfile.id}-reviews.jsonl';
    final bool saved;
    try {
      saved = await state.logFiles.save(name, state.progress.exportJsonl());
    } on Exception catch (e) {
      state.log.warning('Review log not exported: ${e.runtimeType}');
      if (context.mounted) showAppSnackBar(context, l10n.settingsExportFailed);
      return;
    }
    if (!saved) return;
    state.log.event('Review log exported');
    if (context.mounted) showAppSnackBar(context, l10n.settingsExported(name));
  }

  /// Merges a picked backup into this profile's log and says how many
  /// reviews were new, or what is wrong with the file.
  static Future<void> _import(BuildContext context, AppState state) async {
    final l10n = AppLocalizations.of(context)!;
    final String? text;
    try {
      text = await state.logFiles.open(title: l10n.settingsImportPick);
    } on Exception catch (e) {
      state.log.warning('Review log not imported: ${e.runtimeType}');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsImportFailed('$e'));
      }
      return;
    }
    if (text == null) return;
    final int added;
    try {
      final backup = LogJsonl.decode(text);
      added = await state.progress.importLog(
        backup.reviews,
        backup.leechActions,
        fitted: backup.fitted,
      );
    } on FormatException catch (e) {
      state.log.warning('Review log not imported: not a backup');
      if (context.mounted) {
        showAppSnackBar(context, l10n.settingsImportFailed(e.message));
      }
      return;
    }
    state.log.event('Review log imported: $added new');
    if (context.mounted) showAppSnackBar(context, l10n.settingsImported(added));
  }

  /// The design's button rows: 16 above and below.
  static const EdgeInsetsGeometry _tallRow = EdgeInsetsDirectional.symmetric(
    horizontal: 20,
    vertical: 16,
  );
}

/// A day heading, or an answer, in the log's list.
class _LogItem {
  const _LogItem.day(DateTime this.day)
    : event = null,
      first = false,
      last = false;
  const _LogItem.answer(
    ReviewEvent this.event, {
    this.first = false,
    this.last = false,
  }) : day = null;

  final DateTime? day;
  final ReviewEvent? event;
  final bool first;
  final bool last;
}

/// One answer: the card in its script with its reading, its meaning, the
/// activity and the time, and the rating at the end.
class _Answer extends StatelessWidget {
  const _Answer({
    required this.event,
    required this.card,
    required this.first,
    required this.last,
  });

  final ReviewEvent event;

  /// The card answered, or null once its deck is gone.
  final model.Card? card;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = this.card;
    final reading = card?.reading?.trim() ?? '';
    final word = card == null
        ? event.cardId
        : reading.isEmpty
        ? card.target
        : '${card.target} ($reading)';
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(event.at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final activity = Skill.of(event.mode).label(l10n);
    final rating = event.isView
        ? l10n.rateSeen
        : switch (Fsrs.ratingOf(
            event.grade,
            rated: event.answerGiven == null,
          )) {
            Rating.again => l10n.rateAgain,
            Rating.hard => l10n.rateHard,
            Rating.good => l10n.rateGood,
            Rating.easy => l10n.rateEasy,
          };
    const outer = Radius.circular(AppRadii.card);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 2),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(
          top: first ? outer : Radius.zero,
          bottom: last ? outer : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          child: MergeSemantics(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(word, style: theme.textTheme.titleMedium),
                      Text(
                        l10n.settingsDataLogEntry(
                          card?.native ?? '',
                          activity,
                          time,
                        ),
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  rating,
                  style: theme.textTheme.labelLarge!.copyWith(
                    color: scheme.primary,
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
