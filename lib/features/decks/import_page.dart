import 'package:flutter/material.dart';

import '../../app/features.dart';
import '../../core/data/deck_parser.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/incoming.dart';
import 'import_error_card.dart';
import 'option_row.dart';

/// Where a deck to add comes from.
enum ImportSource {
  file(Feature.importFile, Icons.upload_file_outlined),
  url(Feature.importUrl, Icons.link),
  csv(Feature.importCsv, Icons.table_chart_outlined),
  anki(Feature.importAnki, Icons.style_outlined);

  const ImportSource(this.feature, this.icon);

  /// The feature that switches this source on: #22 for a file and a link, a
  /// new issue for spreadsheets, #23 for Anki.
  final Feature feature;

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    ImportSource.file => l10n.importFile,
    ImportSource.url => l10n.importLink,
    ImportSource.csv => l10n.importCsv,
    ImportSource.anki => l10n.importAnki,
  };

  String description(AppLocalizations l10n) => switch (this) {
    ImportSource.file => l10n.importFileDesc,
    ImportSource.url => l10n.importLinkDesc,
    ImportSource.csv => l10n.importCsvDesc,
    ImportSource.anki => l10n.importAnkiDesc,
  };
}

/// The columns a spreadsheet import reads. Deck-format keywords, not
/// interface text, so they are never translated.
const List<String> importCsvColumns = <String>[
  'target',
  'native',
  'reading',
  'tags',
];

/// Add a deck: file, link, spreadsheet or Anki, and the error state with the
/// parser's file, line and message.
///
/// Design screens `import` and `import-error`. Every source is incoming
/// (#22, #23, and a new issue for spreadsheets), so the page is built and
/// shown disabled: the sources dimmed with their badges, the link field and
/// the button disabled. The error state is laid out from a real
/// [DeckParseException], which is what #22's check will raise.
class ImportPage extends StatefulWidget {
  const ImportPage({
    super.key,
    this.initialSource = ImportSource.url,
    this.initialUrl = '',
    this.error,
  });

  /// The source chosen when the page opens; the design opens on a link.
  final ImportSource initialSource;

  /// What the link field holds when the page opens.
  final String initialUrl;

  /// A deck that failed its check, shown under the button.
  final DeckParseException? error;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  late ImportSource _source = widget.initialSource;
  late final TextEditingController _url = TextEditingController(
    text: widget.initialUrl,
  );

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _choose(ImportSource? source) {
    if (source == null || isIncoming(context, source.feature)) return;
    setState(() => _source = source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = widget.error;
    final goLabel = _source == ImportSource.url
        ? l10n.importFetch
        : l10n.importChoose;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
        children: <Widget>[
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: l10n.importSourceGroup,
            child: RadioGroup<ImportSource>(
              groupValue: _source,
              onChanged: _choose,
              child: GroupedList(
                children: <Widget>[
                  for (final source in ImportSource.values) _row(source),
                ],
              ),
            ),
          ),
          ..._help(context),
          const SizedBox(height: 20),
          IncomingFeature(
            feature: _source.feature,
            label: goLabel,
            badge: IncomingBadgePlacement.none,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              // Fetching a link and choosing a file are #22's. Until a
              // source is available there is nothing to run.
              onPressed: null,
              icon: const Icon(Icons.download, size: 22),
              label: Text(goLabel),
            ),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 20),
            ImportErrorCard(error: error),
          ],
        ],
      ),
    );
  }

  Widget _row(ImportSource source) {
    final l10n = AppLocalizations.of(context)!;
    final incoming = isIncoming(context, source.feature);
    final selected = source == _source;
    return OptionRow(
      feature: source.feature,
      selected: selected,
      leading: Icon(source.icon),
      title: source.label(l10n),
      subtitle: source.description(l10n),
      onTap: () => _choose(source),
      trailing: Radio<ImportSource>(
        value: source,
        enabled: !incoming,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// What the chosen source needs: the link field, or a line of help.
  List<Widget> _help(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final helpStyle = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    Widget help(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 20, 8, 0),
      child: Text(text, style: helpStyle),
    );

    switch (_source) {
      case ImportSource.url:
        final incoming = isIncoming(context, Feature.importUrl);
        return <Widget>[
          const SizedBox(height: 20),
          IncomingFeature(
            feature: Feature.importUrl,
            label: l10n.importLinkLabel,
            badge: IncomingBadgePlacement.none,
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.importLinkLabel,
                    style: theme.textTheme.titleSmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _url,
                    enabled: !incoming,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: l10n.importLinkHint,
                      hintTextDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      case ImportSource.csv:
        return <Widget>[
          help(
            l10n.importCsvHelp(importCsvColumns.join(l10n.commonListSeparator)),
          ),
        ];
      case ImportSource.anki:
        return <Widget>[help(l10n.importAnkiHelp)];
      case ImportSource.file:
        return const <Widget>[];
    }
  }
}
