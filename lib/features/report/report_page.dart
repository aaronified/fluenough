import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../core/feedback/report.dart';
import '../../core/logs/log_entry.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';
import 'log_consent.dart';

/// What each [ReportKind] looks like and asks, in the reporter's language.
extension ReportKindText on ReportKind {
  IconData get icon => switch (this) {
    ReportKind.support => Icons.support_agent,
    ReportKind.bug => Icons.bug_report_outlined,
    ReportKind.feedback => Icons.lightbulb_outline,
  };

  /// "Get support", "Report a bug", "Give feedback".
  String title(AppLocalizations l10n) => switch (this) {
    ReportKind.support => l10n.reportKindSupport,
    ReportKind.bug => l10n.reportKindBug,
    ReportKind.feedback => l10n.reportKindFeedback,
  };

  /// Under [title]: what the kind is for, and whether it becomes public.
  String description(AppLocalizations l10n) => switch (this) {
    ReportKind.support => l10n.reportKindSupportDesc,
    ReportKind.bug => l10n.reportKindBugDesc,
    ReportKind.feedback => l10n.reportKindFeedbackDesc,
  };

  /// The hint in the details field.
  String hint(AppLocalizations l10n) => switch (this) {
    ReportKind.support => l10n.reportDetailsHintSupport,
    ReportKind.bug => l10n.reportDetailsHintBug,
    ReportKind.feedback => l10n.reportDetailsHintFeedback,
  };

  /// The questions its mail is preset with, under the details
  /// ([Report.prompts]).
  List<String> prompts(AppLocalizations l10n) => switch (this) {
    ReportKind.support => <String>[l10n.reportPromptSupportTried],
    ReportKind.bug => <String>[
      l10n.reportPromptBugSteps,
      l10n.reportPromptBugExpected,
    ],
    ReportKind.feedback => <String>[l10n.reportPromptFeedbackWhy],
  };
}

/// Get support, report a bug or give feedback, by mail from the reporter's
/// own mail app (#160, ADR-0021): the kind, a title, details, the screen it
/// was raised on, the device's details if the reporter ticks that box, and
/// the app log, as a file, if they tick its box (#162).
/// The mail app opens with the kind's subject and text preset, which the
/// reporter can change before sending. Text only. Bugs and feedback become
/// public issues; support stays private. Behind `Feature.feedbackMail`:
/// until it is on, report buttons open GitHub.
class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.request});

  final ReportRequest request;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _details = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  ReportKind _kind = ReportKind.bug;
  bool _withDevice = false;
  bool _withLog = false;
  bool _titleMissing = false;
  bool _sending = false;
  ReportFailure? _failure;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      // Focus scrolls the field, and its error, back into view.
      setState(() => _titleMissing = true);
      _titleFocus.requestFocus();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final report = Report(
      kind: _kind,
      title: title,
      details: _details.text.trim(),
      prompts: _kind.prompts(l10n),
      context: <String, String>{
        ...widget.request.always,
        if (_withDevice) ...widget.request.device,
      },
      files: <AttachedFile>[
        if (_withLog && !state.log.isEmpty)
          AttachedFile(name: appLogFileName, text: state.log.text),
      ],
    );
    setState(() {
      _sending = true;
      _failure = null;
    });
    final outcome = await state.reports.send(report);
    if (!mounted) return;
    final kind = report.kind.label;
    switch (outcome) {
      case ReportInMailApp(:final filesLeftOut):
        if (filesLeftOut) {
          state.log.warning('Report in mail app ($kind), the log not attached');
        } else {
          state.log.event(
            'Report in mail app ($kind)'
            '${report.files.isEmpty ? '' : ', the log attached'}',
          );
        }
        showAppSnackBar(
          context,
          filesLeftOut ? l10n.reportInMailAppNoLog : l10n.reportInMailApp,
        );
        await Navigator.of(context).maybePop();
      case ReportFailed(:final reason):
        state.log.warning('Report not sent ($kind): ${reason.name}');
        setState(() {
          _sending = false;
          _failure = reason;
        });
    }
  }

  String _failureText(AppLocalizations l10n, ReportFailure failure) =>
      switch (failure) {
        ReportFailure.notSetUp => l10n.reportNotSetUp,
        ReportFailure.noMailApp => l10n.reportNoMailApp,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final failure = _failure;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
        children: <Widget>[
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: l10n.reportKindGroup,
            child: RadioGroup<ReportKind>(
              groupValue: _kind,
              onChanged: (kind) {
                if (kind != null) setState(() => _kind = kind);
              },
              child: GroupedList(
                children: <Widget>[
                  for (final kind in ReportKind.values)
                    GroupedTile(
                      selected: kind == _kind,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      trailingGap: 12,
                      leading: Icon(kind.icon),
                      title: kind.title(l10n),
                      subtitle: kind.description(l10n),
                      onTap: () => setState(() => _kind = kind),
                      trailing: Radio<ReportKind>(
                        value: kind,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            focusNode: _titleFocus,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_titleMissing) setState(() => _titleMissing = false);
            },
            decoration: InputDecoration(
              labelText: l10n.reportTitleLabel,
              errorText: _titleMissing ? l10n.reportTitleMissing : null,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _details,
            minLines: 4,
            maxLines: 10,
            maxLength: 4000,
            decoration: InputDecoration(
              labelText: l10n.reportDetailsLabel,
              hintText: _kind.hint(l10n),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          DeviceInfoConsent(
            device: widget.request.device,
            value: _withDevice,
            onChanged: (value) => setState(() => _withDevice = value),
          ),
          if (state.features.isAvailable(Feature.logs)) ...<Widget>[
            const SizedBox(height: 8),
            LogConsent(
              log: state.log,
              value: _withLog,
              onChanged: (value) => setState(() => _withLog = value),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _kind.public ? l10n.reportPublic : l10n.reportPrivate,
            style: muted,
          ),
          const SizedBox(height: 8),
          Text(l10n.reportAlsoSent, style: muted),
          const SizedBox(height: 8),
          Text(l10n.reportEditable, style: muted),
          if (failure != null) ...<Widget>[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _failureText(l10n, failure),
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.mail_outline),
            label: Text(l10n.reportSend),
          ),
        ],
      ),
    );
  }
}
