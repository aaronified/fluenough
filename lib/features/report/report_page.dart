import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/feedback/report.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';
import '../../ui/widgets/snack.dart';

/// A bug, a feature or a suggestion, sent by mail from the reporter's own
/// mail app (#160, ADR-0021): a title, details, the screen it was raised on,
/// and the device's details if the reporter ticks the box. Text only. Behind
/// `Feature.feedbackMail`: until it is on, report buttons open GitHub.
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
      context: <String, String>{
        ...widget.request.always,
        if (_withDevice) ...widget.request.device,
      },
    );
    setState(() {
      _sending = true;
      _failure = null;
    });
    final outcome = await state.reports.send(report);
    if (!mounted) return;
    switch (outcome) {
      case ReportInMailApp():
        showAppSnackBar(context, l10n.reportInMailApp);
        await Navigator.of(context).maybePop();
      case ReportFailed(:final reason):
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
        children: <Widget>[
          Semantics(
            container: true,
            label: l10n.reportKindGroup,
            child: SegmentedButton<ReportKind>(
              segments: <ButtonSegment<ReportKind>>[
                ButtonSegment<ReportKind>(
                  value: ReportKind.bug,
                  icon: const Icon(Icons.bug_report_outlined),
                  label: Text(l10n.reportKindBug),
                ),
                ButtonSegment<ReportKind>(
                  value: ReportKind.feature,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(l10n.reportKindFeature),
                ),
                ButtonSegment<ReportKind>(
                  value: ReportKind.suggestion,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(l10n.reportKindSuggestion),
                ),
              ],
              selected: <ReportKind>{_kind},
              showSelectedIcon: false,
              onSelectionChanged: (kinds) =>
                  setState(() => _kind = kinds.first),
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
              hintText: l10n.reportDetailsHint,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          DeviceInfoConsent(
            device: widget.request.device,
            value: _withDevice,
            onChanged: (value) => setState(() => _withDevice = value),
          ),
          const SizedBox(height: 16),
          Text(l10n.reportPublic, style: muted),
          const SizedBox(height: 8),
          Text(l10n.reportAlsoSent, style: muted),
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
