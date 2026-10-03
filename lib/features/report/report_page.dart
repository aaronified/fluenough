import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/feedback/report.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';

/// A bug, a feature or a suggestion, sent as a public GitHub issue through
/// the relay (ADR-0021): a title, details, and the screenshot of the screen
/// it was raised on, which the learner sees and may leave out.
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
  bool _withScreenshot = true;
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

  /// What the app adds to the issue, which the page says it sends. Keys are
  /// for the issue's reader, not interface text.
  Map<String, String> _context(AppState state) => <String, String>{
    'App': 'fluenough ${AppInfo.version}',
    'System': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    'App language': Localizations.localeOf(context).toLanguageTag(),
    'Learning': <String>[
      for (final language in state.languages)
        if (state.currentProfile.learns(language.code)) language.code,
    ].join(', '),
    'Screen': widget.request.screen,
    'Showing': ?widget.request.detail,
  };

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
    setState(() {
      _sending = true;
      _failure = null;
    });
    final outcome = await state.reports.send(
      Report(
        kind: _kind,
        title: title,
        details: _details.text.trim(),
        context: _context(state),
        screenshot: _withScreenshot ? widget.request.screenshot : null,
      ),
    );
    if (!mounted) return;
    switch (outcome) {
      case ReportSent():
        showAppSnackBar(context, l10n.reportSent);
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
        ReportFailure.offline => l10n.reportOffline,
        ReportFailure.refused => l10n.reportRefused,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final screenshot = widget.request.screenshot;
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
          if (screenshot != null) ...<Widget>[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsetsDirectional.zero,
              value: _withScreenshot,
              onChanged: (on) => setState(() => _withScreenshot = on ?? false),
              title: Text(l10n.reportScreenshot),
            ),
            if (_withScreenshot)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.small),
                  child: Image.memory(
                    screenshot,
                    height: 280,
                    fit: BoxFit.contain,
                    semanticLabel: l10n.reportScreenshotPreview,
                  ),
                ),
              ),
          ],
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
            icon: const Icon(Icons.send_outlined),
            label: Text(_sending ? l10n.reportSending : l10n.reportSend),
          ),
        ],
      ),
    );
  }
}
