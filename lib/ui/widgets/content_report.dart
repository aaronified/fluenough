import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../app/links.dart';
import '../../core/feedback/content_report.dart';
import '../../core/feedback/report.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'hint.dart';
import 'snack.dart';

/// What each row and reason of the content report says, in the reporter's
/// language. The mail itself is in English ([ContentReason.title]).
extension ContentReasonText on ContentReason {
  String text(AppLocalizations l10n) => switch (this) {
    ContentReason.translationWrong => l10n.contentReasonTranslation,
    ContentReason.noCorrectOption => l10n.contentReasonNoCorrect,
    ContentReason.moreThanOneCorrect => l10n.contentReasonMoreThanOne,
    ContentReason.readingWrong => l10n.contentReasonReading,
    ContentReason.audioWrong => l10n.contentReasonAudio,
    ContentReason.pictureWrong => l10n.contentReasonPicture,
    ContentReason.exampleWrong => l10n.contentReasonExample,
    ContentReason.offensive => l10n.contentReportOffensive,
    ContentReason.somethingElse => l10n.contentReportSomethingElse,
  };
}

extension ContentCategoryText on ContentCategory {
  String text(AppLocalizations l10n) => switch (this) {
    ContentCategory.wrongOptions => l10n.contentReportWrongOptions,
    ContentCategory.readingOrSound => l10n.contentReportReadingOrSound,
    ContentCategory.pictureOrExample => l10n.contentReportPictureOrExample,
    ContentCategory.offensive => l10n.contentReportOffensive,
    ContentCategory.somethingElse => l10n.contentReportSomethingElse,
  };
}

/// The bug icon of a screen that teaches something, kept where the content
/// is: a drill's header, a word sheet, a deck, unit, topic or culture item
/// page. It opens the content report for [target] and nowhere else
/// (owner, 2026-11-16); every other screen has no bug icon.
class ContentReportButton extends StatelessWidget {
  const ContentReportButton({super.key, required this.target});

  final ContentTarget target;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LabelledIconButton(
      label: l10n.contentReportTitle(target.subject.name),
      hint: l10n.hintReport,
      icon: const Icon(Icons.bug_report_outlined),
      onPressed: () => showContentReport(context, target),
    );
  }
}

/// Opens the content report for [target] as a bottom sheet.
Future<void> showContentReport(BuildContext context, ContentTarget target) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ContentReportSheet(target: target),
    );

/// Five rows, what goes with the report, an optional one-line note, Cancel
/// and Send (`docs/mockups/menu-and-report.md`). A row with specifics opens
/// a small popup saying exactly what is wrong. The report is handed to the
/// reporter's mail app, with the ids, the language pair and the app's
/// version and nothing else.
class ContentReportSheet extends StatefulWidget {
  const ContentReportSheet({super.key, required this.target});

  final ContentTarget target;

  @override
  State<ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends State<ContentReportSheet> {
  final TextEditingController _note = TextEditingController();
  ContentCategory? _category;
  ContentReason? _reason;
  bool _sending = false;
  bool _done = false;
  ReportFailure? _failure;

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ContentCategory category) async {
    final target = widget.target;
    if (!category.hasPopup(target)) {
      setState(() {
        _category = category;
        _reason = category.only(target);
      });
      return;
    }
    final reason = await showDialog<ContentReason>(
      context: context,
      builder: (_) => _ReasonDialog(
        category: category,
        reasons: category.reasons(target),
        current: _category == category ? _reason : null,
      ),
    );
    if (reason == null || !mounted) return;
    setState(() {
      _category = category;
      _reason = reason;
    });
  }

  bool get _canSend {
    final category = _category;
    if (category == null || _sending) return false;
    return category != ContentCategory.somethingElse ||
        _note.text.trim().isNotEmpty;
  }

  Future<void> _send() async {
    final category = _category;
    final reason = _reason;
    if (category == null || reason == null) return;
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final report = contentReport(
      target: widget.target,
      category: category,
      reason: reason,
      note: _note.text,
      version: 'fluenough ${AppInfo.version}',
    );
    if (!state.features.isAvailable(Feature.feedbackMail)) {
      final body = issueBody(l10n.reportIssuePrompt, <String, String>{
        'Title': report.title,
        if (report.details.isNotEmpty) 'Note': report.details,
        ...report.context,
      });
      await openLink(
        context,
        AppLinks.newIssue(body).toString(),
        copied: l10n.reportLinkCopied,
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _sending = true;
      _failure = null;
    });
    final outcome = await state.reports.send(report);
    if (!mounted) return;
    switch (outcome) {
      case ReportInMailApp():
        state.log.event('Content report in mail app');
        setState(() {
          _sending = false;
          _done = true;
        });
      case ReportFailed(reason: final why):
        state.log.warning('Content report not sent: ${why.name}');
        setState(() {
          _sending = false;
          _failure = why;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(
          24,
          0,
          24,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _done ? _doneView(l10n) : _form(l10n),
      ),
    );
  }

  Widget _doneView(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.check_circle_outline,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.contentReportDoneTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.contentReportDoneBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
    );
  }

  String _failureText(AppLocalizations l10n, ReportFailure failure) =>
      switch (failure) {
        ReportFailure.notSetUp => l10n.reportNotSetUp,
        ReportFailure.noMailApp => l10n.reportNoMailApp,
      };

  Widget _form(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = widget.target;
    final failure = _failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            l10n.contentReportTitle(target.subject.name),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey<String>('content-report-context'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          child: Text(
            contextLines(target.context('fluenough ${AppInfo.version}')),
            style: theme.textTheme.bodySmall!.copyWith(
              fontFamily: 'monospace',
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: l10n.contentReportGroup,
          child: RadioGroup<ContentCategory>(
            groupValue: _category,
            onChanged: (category) {
              if (category != null) _pick(category);
            },
            child: Column(
              children: <Widget>[
                for (final category in ContentCategory.values)
                  _row(l10n, category),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _note,
          maxLength: contentNoteLength,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.contentReportNote,
            isDense: true,
          ),
        ),
        if (failure != null) ...<Widget>[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _failureText(l10n, failure),
              style: theme.textTheme.bodyMedium!.copyWith(color: scheme.error),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _canSend ? _send : null,
              child: Text(l10n.contentReportSend),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(AppLocalizations l10n, ContentCategory category) {
    final target = widget.target;
    final popup = category.hasPopup(target);
    final chosen = _category == category ? _reason : null;
    return ListTile(
      key: ValueKey<String>('content-report-${category.name}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 24,
      leading: Radio<ContentCategory>(
        value: category,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      title: Text(
        popup ? category.text(l10n) : category.only(target).text(l10n),
      ),
      subtitle: popup && chosen != null ? Text(chosen.text(l10n)) : null,
      trailing: popup ? const Icon(Icons.chevron_right) : null,
      onTap: () => _pick(category),
    );
  }
}

/// The small popup that says exactly what is wrong under a row: the row's
/// name as its title, the specifics as radios, and Cancel. Picking one
/// closes it.
class _ReasonDialog extends StatelessWidget {
  const _ReasonDialog({
    required this.category,
    required this.reasons,
    required this.current,
  });

  final ContentCategory category;
  final List<ContentReason> reasons;
  final ContentReason? current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      key: const ValueKey<String>('content-report-popup'),
      title: Text(category.text(l10n)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: RadioGroup<ContentReason>(
        groupValue: current,
        onChanged: (reason) => Navigator.of(context).pop(reason),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final reason in reasons)
              RadioListTile<ContentReason>(
                value: reason,
                title: Text(reason.text(l10n)),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}
