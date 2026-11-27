import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_import.dart';
import '../../app/features.dart';
import '../../core/data/deck_parser.dart';
import '../../core/decks/deck_link.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/snack.dart';
import '../../ui/widgets/system_bar.dart';
import 'import_error_card.dart';

/// Where a deck to add comes from.
enum ImportSource {
  file(Feature.importFile, Icons.upload_file_outlined),
  url(Feature.importUrl, Icons.link),
  csv(Feature.importCsv, Icons.table_chart_outlined);

  const ImportSource(this.feature, this.icon);

  /// The feature that switches this source on: #22 for a file and a link, a
  /// new issue for spreadsheets.
  final Feature feature;

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    ImportSource.file => l10n.importFile,
    ImportSource.url => l10n.importLink,
    ImportSource.csv => l10n.importCsv,
  };

  String description(AppLocalizations l10n) => switch (this) {
    ImportSource.file => l10n.importFileDesc,
    ImportSource.url => l10n.importLinkDesc,
    ImportSource.csv => l10n.importCsvDesc,
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

/// The deck template, which the file source offers to save (#22).
const String deckTemplateAsset = 'assets/deck-template.yaml';

/// The name the template is saved as.
const String deckTemplateFile = 'fluenough-deck-template.yaml';

/// Offers the deck template to the learner to save (#22), and says in a toast
/// what came of it. Used by Add a deck and by Your decks.
Future<void> saveDeckTemplate(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final state = AppScope.read(context);
  final bundle = DefaultAssetBundle.of(context);
  final bool saved;
  try {
    final text = await bundle.loadString(deckTemplateAsset);
    saved = await state.deckFiles.save(deckTemplateFile, text);
  } on Exception catch (e) {
    state.log.warning('Deck template not saved: ${e.runtimeType}');
    if (context.mounted) showAppSnackBar(context, l10n.importTemplateFailed);
    return;
  }
  if (saved) state.log.event('Deck template saved');
  if (saved && context.mounted) {
    showAppSnackBar(context, l10n.importTemplateSaved(deckTemplateFile));
  }
}

/// Add a deck: file, link or spreadsheet, and the error state with the
/// parser's file, line and message.
///
/// Design screens `import` and `import-error`. A file is added (#22): the
/// page offers the template, checks the chosen file (`checkAddedDeck`), and
/// shows what is wrong with it or adds it. So is a link (#22): the page
/// downloads the file at an https address and checks it the same way. The
/// spreadsheet source is incoming (a new issue): dimmed with its badge and
/// its button disabled.
class ImportPage extends StatefulWidget {
  const ImportPage({
    super.key,
    this.initialSource = ImportSource.file,
    this.initialUrl = '',
    this.error,
  });

  /// The source chosen when the page opens.
  final ImportSource initialSource;

  /// What the link field holds when the page opens.
  final String initialUrl;

  /// A deck that failed to parse, shown under the button until a file is
  /// chosen. For the gallery and tests.
  final DeckParseException? error;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  late ImportSource _source = widget.initialSource;
  late final TextEditingController _url = TextEditingController(
    text: widget.initialUrl,
  );

  /// The file chosen, and what adding it would do.
  ({String name, String text})? _picked;
  DeckCheck? _check;
  bool _adding = false;

  /// Whether a linked deck is downloading, and why the last link failed.
  bool _fetching = false;
  String? _linkProblem;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _choose(ImportSource? source) {
    if (source == null ||
        AppScope.read(context).features.isIncoming(source.feature)) {
      return;
    }
    setState(() {
      _source = source;
      _picked = null;
      _check = null;
      _linkProblem = null;
    });
  }

  Future<void> _saveTemplate() => saveDeckTemplate(context);

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final ({String name, String text})? picked;
    try {
      picked = await state.deckFiles.open(title: l10n.importPickTitle);
    } on Exception catch (e) {
      state.log.warning('Deck file not read: ${e.runtimeType}');
      if (mounted) showAppSnackBar(context, l10n.importReadFailed('$e'));
      return;
    }
    if (picked == null || !mounted) return;
    final file = picked;
    setState(() {
      _picked = file;
      _check = state.checkDeck(file.text, file.name);
    });
  }

  /// Downloads the deck at the address in the link field and checks it as a
  /// picked file is checked: the same errors, the same Replace prompt.
  Future<void> _fetchLink() async {
    if (_fetching || _adding) return;
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final parsed = parseDeckLink(_url.text);
    final uri = parsed.uri;
    if (uri == null) {
      final why = parsed.failure ?? LinkFailure.notALink;
      setState(() {
        _picked = null;
        _check = null;
        _linkProblem = _linkText(l10n, why);
      });
      return;
    }
    setState(() {
      _fetching = true;
      _picked = null;
      _check = null;
      _linkProblem = null;
    });
    final fetched = await _downloadDeck(state.deckLinks, uri);
    if (!mounted) return;
    final text = fetched.text;
    if (text == null) {
      final failure = fetched.failure ?? LinkFailure.badReply;
      final cause = fetched.cause;
      state.log.warning(
        'Deck link not fetched: ${failure.name}'
        '${cause == null ? '' : ' ($cause)'}',
      );
      setState(() {
        _fetching = false;
        _linkProblem = _linkText(l10n, failure);
      });
      return;
    }
    final name = deckLinkName(uri);
    setState(() {
      _fetching = false;
      _picked = (name: name, text: text);
      _check = state.checkDeck(text, name);
    });
  }

  /// [fetcher]'s answer for [uri]. A fetcher never throws; if one does, the
  /// link counts as unreachable.
  static Future<LinkFetched> _downloadDeck(
    DeckLinkFetcher fetcher,
    Uri uri,
  ) async {
    try {
      return await fetcher.fetch(uri);
    } on Exception catch (e) {
      return LinkFetched.failed(
        LinkFailure.offline,
        cause: e.runtimeType.toString(),
      );
    }
  }

  /// What a failed link means to the learner.
  static String _linkText(AppLocalizations l10n, LinkFailure f) => switch (f) {
    LinkFailure.notALink => l10n.importLinkNotALink,
    LinkFailure.notHttps => l10n.importLinkNotHttps,
    LinkFailure.offline => l10n.importLinkOffline,
    LinkFailure.notFound => l10n.importLinkNotFound,
    LinkFailure.refused => l10n.importLinkRefused,
    LinkFailure.tooLarge => l10n.importLinkTooLarge,
    LinkFailure.notText => l10n.importLinkNotText,
    LinkFailure.badReply => l10n.importLinkBadReply,
  };

  Future<void> _add(DeckAccepted check) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _adding = true);
    final state = AppScope.read(context);
    try {
      await state.addDeck(check.deck, _picked!.text);
    } on Exception catch (e) {
      state.log.warning('Deck not added: ${e.runtimeType}');
      if (!mounted) return;
      setState(() => _adding = false);
      showAppSnackBar(context, l10n.importAddFailed);
      return;
    }
    if (!mounted) return;
    showAppSnackBar(context, l10n.importAdded(check.deck.name));
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = widget.error;
    final goLabel = _source == ImportSource.url
        ? (_fetching ? l10n.importFetching : l10n.importFetch)
        : l10n.importChoose;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          16,
          8,
          16,
          24,
        ).clearingSystemBar(context),
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
              onPressed: _go,
              icon: const Icon(Icons.download, size: 22),
              label: Text(goLabel),
            ),
          ),
          if (_outcome(l10n) case final outcome?) ...<Widget>[
            const SizedBox(height: 20),
            outcome,
          ] else if (error != null) ...<Widget>[
            const SizedBox(height: 20),
            ImportErrorCard(detail: ImportErrorCard.detailFor(l10n, error)),
          ],
        ],
      ),
    );
  }

  /// What the main button does, or null while it cannot.
  VoidCallback? get _go {
    if (_adding || _fetching) return null;
    return switch (_source) {
      ImportSource.file => _pick,
      ImportSource.url => _fetchLink,
      ImportSource.csv => null,
    };
  }

  /// What the chosen file's check found, or null before one is chosen.
  Widget? _outcome(AppLocalizations l10n) {
    if (_linkProblem case final problem?) {
      return ImportErrorCard(detail: problem);
    }
    final name = _picked?.name ?? '';
    return switch (_check) {
      null => null,
      DeckUnreadable(:final error) => ImportErrorCard(
        detail: ImportErrorCard.detailFor(l10n, error),
      ),
      DeckIdBundled(:final deckId) => ImportErrorCard(
        detail: l10n.importErrorIn(name, l10n.importIdBundled(deckId)),
      ),
      DeckCardTaken(:final cardId, :final deckName) => ImportErrorCard(
        detail: l10n.importErrorIn(
          name,
          l10n.importCardTaken(cardId, deckName),
        ),
      ),
      final DeckAccepted check => _CheckedDeck(
        check: check,
        onAdd: _adding ? null : () => _add(check),
      ),
    };
  }

  Widget _row(ImportSource source) {
    final l10n = AppLocalizations.of(context)!;
    final incoming = isIncoming(context, source.feature);
    final selected = source == _source;
    return GroupedTile(
      feature: source.feature,
      selected: selected,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      trailingGap: 12,
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
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => unawaited(_fetchLink()),
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
      case ImportSource.file:
        return <Widget>[
          help(l10n.importFileHelp),
          const SizedBox(height: 12),
          // As wide as the Choose file button under it.
          OutlinedButton.icon(
            onPressed: _saveTemplate,
            icon: const Icon(Icons.description_outlined),
            label: Text(l10n.importTemplate),
          ),
        ];
    }
  }
}

/// A file that passed its check: the deck's name, its cards and licence,
/// and the button that adds it, or replaces the deck added before with its
/// id.
class _CheckedDeck extends StatelessWidget {
  const _CheckedDeck({required this.check, required this.onAdd});

  final DeckAccepted check;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadii.group),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.check_circle_outline, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.importChecked, style: muted)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              check.deck.name,
              style: theme.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.importDeckMeta(check.cardCount, check.deck.license),
              style: muted,
            ),
            if (check.replaces) ...<Widget>[
              const SizedBox(height: 10),
              Text(l10n.importReplaces, style: muted),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: onAdd,
              child: Text(check.replaces ? l10n.importReplace : l10n.importAdd),
            ),
          ],
        ),
      ),
    );
  }
}
