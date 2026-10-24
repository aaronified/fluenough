import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_downloads.dart';
import '../../core/decks/deck_index.dart';
import '../../core/decks/font_check.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/script_name.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/report_button.dart';
import '../downloads/download_text.dart';

/// Shows the font check for [script] in a sheet, and completes when it is
/// closed (#611, docs/mockups/font-check.html, owner, 2026-10-24:
/// "Approved"). The sample is drawn in the phone's own font; "Yes, I can
/// read it" keeps it, "No, it shows boxes" downloads the script's font and
/// shows the sample again in it.
Future<void> showFontCheckSheet(BuildContext context, String script) {
  final fontCheck = AppScope.read(context).fontCheck;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => FontCheckSheet(script: script),
  ).whenComplete(() => fontCheck.answered(script));
}

enum _Step { ask, downloading, readNow, doneDownloaded, donePhone, boxes }

/// The font check's sheet for one script.
class FontCheckSheet extends StatefulWidget {
  const FontCheckSheet({super.key, required this.script});

  final String script;

  @override
  State<FontCheckSheet> createState() => _FontCheckSheetState();
}

class _FontCheckSheetState extends State<FontCheckSheet> {
  _Step _step = _Step.ask;
  DeckDownloadFailure? _failure;

  String get _script => widget.script;

  Future<void> _yes() async {
    final fontCheck = AppScope.read(context).fontCheck;
    await fontCheck.choose(_script, FontChoice.phone);
    if (mounted) setState(() => _step = _Step.donePhone);
  }

  Future<void> _no() async {
    final fontCheck = AppScope.read(context).fontCheck;
    setState(() {
      _step = _Step.downloading;
      _failure = null;
    });
    final failure = await fontCheck.choose(_script, FontChoice.download);
    if (!mounted) return;
    setState(() {
      _failure = failure;
      _step = failure == null ? _Step.readNow : _Step.ask;
    });
  }

  Future<void> _stillBoxes() async {
    await AppScope.read(context).fontCheck.choose(_script, FontChoice.boxes);
    if (mounted) setState(() => _step = _Step.boxes);
  }

  void _close() => Navigator.of(context).pop();

  void _later() {
    AppScope.read(context).fontCheck.later(_script);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final sample = scriptSamples[_script];
    final name = l10n.scriptNameOr(_script, _script);
    final font = state.deckDownloads?.fontOffered(_script);
    final showsFont = _step == _Step.readNow || _step == _Step.doneDownloaded;
    // The first sample is the phone's own font: no family at all.
    final family = showsFont
        ? state.deckDownloads?.fonts.familyFor(_script)
        : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSizes.gutter,
          0,
          AppSizes.gutter,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(switch (_step) {
                _Step.readNow => l10n.fontCheckReadNow,
                _Step.boxes => l10n.fontCheckBoxesTitle,
                _ => l10n.fontCheckTitle(name),
              }, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            if (sample != null && _step != _Step.boxes)
              _Sample(sample: sample, script: _script, family: family),
            const SizedBox(height: 16),
            ..._body(l10n, theme, name, font),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(
    AppLocalizations l10n,
    ThemeData theme,
    String name,
    IndexFont? font,
  ) {
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    switch (_step) {
      case _Step.ask:
        return <Widget>[
          Text(l10n.fontCheckAsk, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton(onPressed: _yes, child: Text(l10n.fontCheckYes)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _no, child: Text(l10n.fontCheckNo)),
          if (font != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              l10n.fontCheckNoCost(
                font.family.isEmpty ? name : font.family,
                formatSize(l10n, font.size),
              ),
              style: muted,
            ),
          ],
          if (_failure != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              downloadFailureText(l10n, _failure),
              style: muted?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          TextButton(onPressed: _later, child: Text(l10n.fontCheckLater)),
        ];
      case _Step.downloading:
        return <Widget>[
          Text(
            l10n.fontCheckDownloading(name),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          TextButton(onPressed: _close, child: Text(l10n.fontCheckBackground)),
        ];
      case _Step.readNow:
        return <Widget>[
          FilledButton(
            onPressed: () => setState(() => _step = _Step.doneDownloaded),
            child: Text(l10n.fontCheckYes),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _stillBoxes,
            child: Text(l10n.fontCheckStillBoxes),
          ),
        ];
      case _Step.doneDownloaded:
      case _Step.donePhone:
        return <Widget>[
          Text(
            _step == _Step.doneDownloaded
                ? l10n.fontCheckDoneDownloaded(name)
                : l10n.fontCheckDonePhone(name),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _close, child: Text(l10n.commonDone)),
        ];
      case _Step.boxes:
        return <Widget>[
          Text(l10n.fontCheckBoxesBody(name), style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                ReportButton.open(context, detail: 'Font check: $_script'),
            child: Text(l10n.fontCheckReport),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _close,
            child: Text(l10n.fontCheckReadingsOnly),
          ),
        ];
    }
  }
}

/// A script sample, its reading and what it means, on a raised block. Drawn
/// in [family] when one is given, else in the phone's own font.
class _Sample extends StatelessWidget {
  const _Sample({
    required this.sample,
    required this.script,
    required this.family,
  });

  final ScriptSample sample;
  final String script;
  final String? family;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            sample.text,
            textDirection: script == 'perso_arabic' ? TextDirection.rtl : null,
            style: theme.textTheme.headlineMedium?.copyWith(fontFamily: family),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.fontCheckSampleLine(
              sample.reading,
              l10n.fontCheckMeaning(sample.meaning),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
