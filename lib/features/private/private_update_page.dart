import 'package:flutter/material.dart';

import '../../core/private/private_package.dart';
import '../../core/private/private_update.dart';
import '../../app/private_import.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'private_install_flow.dart';
import 'private_widgets.dart';

/// How many cards of a list the summary shows before Show all.
const int _previewCards = 3;

/// The summary of a newer file of an installed package (Plan-Private-
/// Languages, task 18; mockup `private-update-summary`, default variants:
/// the four counts, then the lists; progress in one block with How it works;
/// retired ids explained on the page): what is new, changed and removed, how
/// the learner's progress is kept, and Update or Cancel.
///
/// Opened by the import review once the file passed it; pops true when the
/// package was updated.
class PrivateUpdatePage extends StatefulWidget {
  const PrivateUpdatePage({
    super.key,
    required this.staging,
    required this.installed,
    required this.installedFiles,
    required this.fileName,
  });

  final PrivateStaging staging;
  final PrivatePackage installed;

  /// The files of the installed package, to compare with.
  final Map<String, String> installedFiles;
  final String fileName;

  @override
  State<PrivateUpdatePage> createState() => _PrivateUpdatePageState();
}

class _PrivateUpdatePageState extends State<PrivateUpdatePage> {
  late final PrivateUpdateSummary _summary = PrivateUpdateSummary.compute(
    before: widget.installedFiles,
    after: widget.staging.files,
    fromRevision: widget.installed.revision,
    toRevision: widget.staging.manifest?.revision ?? widget.installed.revision,
    retired: widget.staging.retired,
  );
  final Set<String> _open = <String>{};
  bool _working = false;

  Future<void> _update() async {
    if (_working) return;
    setState(() => _working = true);
    final done = await installPrivateFlow(
      context,
      widget.staging,
      update: true,
    );
    if (!mounted) return;
    setState(() => _working = false);
    if (done) Navigator.of(context).pop(true);
  }

  void _how() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => _HowPage(summary: _summary)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = _summary;
    final manifest = widget.staging.manifest;
    final name = manifest?.language.name ?? widget.installed.id;

    Widget tile(String label, int n) => Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Column(
        children: <Widget>[
          Text('$n', style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    Widget block({required Widget child}) => Container(
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: child,
    );

    final parts = <WidgetBuilder>[
      (c) => block(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.sync, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, style: theme.textTheme.titleMedium),
                  Text(
                    l10n.privateUpdateRevisions(
                      summary.fromRevision,
                      summary.toRevision,
                      widget.fileName,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (summary.unitsBefore != summary.unitsAfter)
                    Text(
                      l10n.privateUnitsChange(
                        summary.unitsBefore,
                        summary.unitsAfter,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      (c) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            tile(l10n.privateTileNew, summary.added.length),
            tile(l10n.privateTileChanged, summary.changed.length),
            tile(l10n.privateTileRemoved, summary.removed.length),
            tile(l10n.privateTileRetired, summary.retiredTotal),
          ],
        ),
      ),
      if (summary.isEmpty)
        (c) => Padding(
          padding: const EdgeInsetsDirectional.only(top: 12),
          child: Text(
            l10n.privateNothingChanges,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      (c) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 12),
        child: block(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.privateProgressTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                summary.replacing.isEmpty
                    ? l10n.privateProgressPlain
                    : l10n.privateProgressEdited(summary.replacing.length),
                style: theme.textTheme.bodyMedium,
              ),
              TextButton(onPressed: _how, child: Text(l10n.privateHowItWorks)),
            ],
          ),
        ),
      ),
      (c) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 12),
        child: block(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.privateRetiredTitle(summary.retiredTotal),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                l10n.privateRetiredBody(
                  summary.retiredNow,
                  summary.retiredEarlier,
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      ..._list(
        context,
        'new',
        l10n.privateListNew(summary.added.length),
        summary.added,
      ),
      ..._list(
        context,
        'changed',
        l10n.privateListChanged(summary.changed.length),
        summary.changed,
      ),
      ..._list(
        context,
        'removed',
        l10n.privateListRemoved(summary.removed.length),
        summary.removed,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privateUpdateTitle(name))),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
              itemCount: parts.length,
              itemBuilder: (c, i) => parts[i](c),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton(
                    key: const ValueKey<String>('private-update-confirm'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppSizes.primaryButton,
                      ),
                    ),
                    onPressed: _working ? null : _update,
                    child: Text(l10n.privateUpdateTo(summary.toRevision)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A heading, the first cards of [cards] and Show all, as lazy parts of the
  /// page's list. Empty for no cards.
  List<WidgetBuilder> _list(
    BuildContext context,
    String key,
    String heading,
    List<PrivateCardLine> cards,
  ) {
    if (cards.isEmpty) return const <WidgetBuilder>[];
    final open = _open.contains(key);
    final shown = open ? cards : cards.take(_previewCards).toList();
    return <WidgetBuilder>[
      (c) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 16, bottom: 4),
        child: Semantics(
          header: true,
          child: Text(
            heading,
            style: Theme.of(c).textTheme.titleSmall!
                .copyWith(color: Theme.of(c).colorScheme.primary),
          ),
        ),
      ),
      for (final card in shown) (c) => _CardRow(card: card),
      if (cards.length > _previewCards)
        (c) {
          final l10n = AppLocalizations.of(c)!;
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() {
                if (!_open.add(key)) _open.remove(key);
              }),
              child: Text(
                open
                    ? l10n.privateShowFewer
                    : l10n.privateShowAll(cards.length),
              ),
            ),
          );
        },
    ];
  }
}

/// One card of a list: the word, its reading and meaning, and its id.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.card});

  final PrivateCardLine card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final line = <String>[
      if (card.reading != null) card.reading!,
      if (card.meaning != null) card.meaning!,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(card.target, style: theme.textTheme.titleMedium),
          if (line.isNotEmpty) Text(line, style: muted),
          Text(
            <String>[
              card.id,
              if (card.fields.isNotEmpty)
                l10n.privateChangedFields(card.fields.join(', ')),
              if (card.replaces != null)
                l10n.privateReplacesCard(card.replaces!),
            ].join(' · '),
            style: muted.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

/// How the learner's progress is kept, case by case.
class _HowPage extends StatelessWidget {
  const _HowPage({required this.summary});

  final PrivateUpdateSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    Widget row(String title, int n, String body) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleSmall),
              PrivateTag(label: '$n'),
            ],
          ),
          Text(
            body,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privateHowTitle)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
              children: <Widget>[
                Text(l10n.privateHowIntro, style: theme.textTheme.bodyLarge),
                row(
                  l10n.privateHowUnchanged,
                  summary.unchanged,
                  l10n.privateHowUnchangedBody,
                ),
                row(
                  l10n.privateHowChanged,
                  summary.keepingProgress.length,
                  l10n.privateHowChangedBody,
                ),
                row(
                  l10n.privateHowEdited,
                  summary.replacing.length,
                  l10n.privateHowEditedBody,
                ),
                row(
                  l10n.privateHowNew,
                  summary.added.length,
                  l10n.privateHowNewBody,
                ),
                row(
                  l10n.privateHowRemoved,
                  summary.removed.length,
                  l10n.privateHowRemovedBody,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.privateGotIt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
