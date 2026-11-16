import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/private_import.dart';
import '../../app/private_languages.dart';
import '../../core/logs/log_entry.dart';
import '../../core/private/private_check.dart';
import '../../core/private/private_manifest.dart';
import '../../core/private/private_package.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';
import 'private_install_flow.dart';
import 'private_update_page.dart';
import 'private_widgets.dart';

/// Asks for a `.fnzip` and opens the review of it (Plan-Private-Languages,
/// task 17). Reads the bytes through the app's file chooser
/// (`DeckFiles.openBytes`, the same `file_picker` the deck import uses).
/// Returns whether a package was added or updated.
Future<bool> choosePrivatePackage(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final state = AppScope.read(context);
  final ({String name, List<int> bytes})? picked;
  try {
    picked = await state.deckFiles.openBytes(title: l10n.privatePickTitle);
  } on Object catch (e, stack) {
    state.log.error(describeError('Private decks: file not read', e, stack));
    if (context.mounted) showAppSnackBar(context, l10n.privateReadFailed);
    return false;
  }
  if (picked == null || !context.mounted) return false;
  final file = picked;
  final done = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => PrivateImportPage(fileName: file.name, bytes: file.bytes),
    ),
  );
  return done ?? false;
}

/// The rules whose finding is about a card: the screen shows "Card {id}".
const Set<String> _cardTokens = <String>{
  'idPrefix',
  'duplicateCard',
  'retiredReused',
};

/// The rules a level 0 refusal is made of: the file cannot be opened safely.
const Set<String> _unsafeTokens = <String>{
  'zipUnsafe',
  'tooManyFiles',
  'unpackedTooBig',
  'fileTooBig',
  'fileName',
  'fileType',
  'notUtf8',
  'yamlDepth',
  'yamlAlias',
  'yamlTag',
};

enum _RowSeverity { error, warning, note }

/// One line of the findings: a finding of the checks, or a note about the
/// phone.
class _Row {
  const _Row(
    this.severity,
    this.text, {
    this.file,
    this.line,
    this.card,
    this.hint,
  });

  final _RowSeverity severity;
  final String text;
  final String? file;
  final int? line;
  final String? card;
  final String? hint;
}

/// The review of a chosen package file (mockup `private-import-review`,
/// default variants: findings by severity, detail in the list, rights
/// warnings listed only, a lower revision refused): it checks the file, shows
/// what it holds and what was found, and adds it when no error remains. A
/// refusal (an older revision, over the size limit, not safe to open) is
/// told before anything is unpacked or installed.
class PrivateImportPage extends StatefulWidget {
  const PrivateImportPage({
    super.key,
    required this.fileName,
    required this.bytes,
    @visibleForTesting this.holdChecking = false,
  });

  final String fileName;
  final List<int> bytes;

  /// For a test of the checking screen: the check does not run, so the screen
  /// stays on "Checking…".
  final bool holdChecking;

  @override
  State<PrivateImportPage> createState() => _PrivateImportPageState();
}

class _PrivateImportPageState extends State<PrivateImportPage> {
  PrivateStaging? _staging;
  PrivatePackage? _installed;
  Map<String, String>? _installedFiles;
  bool _cancelled = false;
  bool _working = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_staging == null && !_started) {
      _started = true;
      if (!widget.holdChecking) _check();
    }
  }

  bool _started = false;

  Future<void> _check() async {
    final state = AppScope.read(context);
    PrivateStaging staging;
    try {
      staging = await state.stagePrivateBytes(widget.bytes);
    } on Object catch (e, stack) {
      state.log.error(describeError('Private decks: check failed', e, stack));
      staging = const PrivateStaging(
        findings: <PrivateFinding>[
          PrivateFinding(
            severity: FindingSeverity.error,
            token: 'zipUnsafe',
            params: <String, String>{
              'detail': 'the archive could not be opened',
            },
          ),
        ],
      );
    }
    PrivatePackage? installed;
    Map<String, String>? files;
    final manifest = staging.manifest;
    if (manifest != null) {
      for (final package in await state.privatePackages()) {
        if (package.id == manifest.package) installed = package;
      }
      if (installed != null && staging.canInstall) {
        files = await state.privateStore?.readPackage(manifest.package);
      }
    }
    if (!mounted || _cancelled) return;
    setState(() {
      _staging = staging;
      _installed = installed;
      _installedFiles = files;
    });
  }

  Future<void> _another() async {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final ({String name, List<int> bytes})? picked;
    try {
      picked = await state.deckFiles.openBytes(title: l10n.privatePickTitle);
    } on Object catch (e, stack) {
      state.log.error(describeError('Private decks: file not read', e, stack));
      if (mounted) showAppSnackBar(context, l10n.privateReadFailed);
      return;
    }
    if (picked == null || !mounted) return;
    final file = picked;
    unawaited(
      navigator.pushReplacement(
        MaterialPageRoute<bool>(
          builder: (_) =>
              PrivateImportPage(fileName: file.name, bytes: file.bytes),
        ),
      ),
    );
  }

  Future<void> _add() async {
    final staging = _staging;
    final manifest = staging?.manifest;
    if (staging == null || manifest == null || _working) return;
    final installed = _installed;
    if (installed != null) {
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PrivateUpdatePage(
            staging: staging,
            installed: installed,
            installedFiles: _installedFiles ?? const <String, String>{},
            fileName: widget.fileName,
          ),
        ),
      );
      if (done == true && mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() => _working = true);
    final done = await installPrivateFlow(context, staging, update: false);
    if (!mounted) return;
    setState(() => _working = false);
    if (done) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final staging = _staging;
    final Widget body = staging == null
        ? _Checking(fileName: widget.fileName, onCancel: _cancel)
        : _body(context, staging);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privateReviewTitle)),
      body: body,
    );
  }

  void _cancel() {
    _cancelled = true;
    Navigator.of(context).pop(false);
  }

  Widget _body(BuildContext context, PrivateStaging staging) {
    final tokens = <String>{for (final f in staging.findings) f.token};
    if (tokens.contains('revisionLower')) {
      final finding = staging.findings.firstWhere(
        (f) => f.token == 'revisionLower',
      );
      return _Older(
        language: staging.manifest?.language.name ?? '',
        installed: int.tryParse(finding.params['installed'] ?? '') ?? 0,
        found: int.tryParse(finding.params['found'] ?? '') ?? 0,
        package: staging.manifest?.package ?? '',
        onAnother: _another,
      );
    }
    if (tokens.contains('archiveTooBig')) {
      return _TooBig(
        fileName: widget.fileName,
        bytes: widget.bytes.length,
        onAnother: _another,
      );
    }
    if (staging.manifest == null &&
        staging.files.isEmpty &&
        tokens.any(_unsafeTokens.contains)) {
      return _Unsafe(
        findings: <PrivateFinding>[
          for (final f in staging.findings)
            if (_unsafeTokens.contains(f.token)) f,
        ],
        onAnother: _another,
      );
    }
    return _Review(
      fileName: widget.fileName,
      fileBytes: widget.bytes.length,
      staging: staging,
      update: _installed != null,
      working: _working,
      onAdd: _add,
      onAnother: _another,
    );
  }
}

/// While the file is checked.
class _Checking extends StatelessWidget {
  const _Checking({required this.fileName, required this.onCancel});

  final String fileName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(fileName, style: theme.textTheme.titleMedium),
                        Text(
                          l10n.privateChecking,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _Bottom(
          children: <Widget>[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: onCancel,
              child: Text(l10n.privateCancel),
            ),
          ],
        ),
      ],
    );
  }
}

/// The buttons at the foot of a screen.
class _Bottom extends StatelessWidget {
  const _Bottom({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// The file's name, size and bar.
class _FileBlock extends StatelessWidget {
  const _FileBlock({required this.name, required this.bytes, this.error});

  final String name;
  final int bytes;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 2),
          child: Icon(
            Icons.insert_drive_file_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(name, style: theme.textTheme.titleMedium, softWrap: true),
              Text(
                error ?? l10n.privateFileSize(privateSizeText(bytes)),
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              PrivateSizeBar(bytes: bytes, error: error != null),
            ],
          ),
        ),
      ],
    );
  }
}

/// The three counts of a package.
class _Counts extends StatelessWidget {
  const _Counts({
    required this.cards,
    required this.units,
    required this.decks,
  });

  final int cards;
  final int units;
  final int decks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    Widget tile(int n, String label) => Expanded(
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Column(
          children: <Widget>[
            Text('$n', style: theme.textTheme.titleLarge),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
    return Row(
      children: <Widget>[
        tile(cards, l10n.privateCountCards(cards)),
        const SizedBox(width: 8),
        tile(units, l10n.privateCountUnits(units)),
        const SizedBox(width: 8),
        tile(decks, l10n.privateCountDecks(decks)),
      ],
    );
  }
}

/// The review: what the file holds, what was found, and Add.
class _Review extends StatelessWidget {
  const _Review({
    required this.fileName,
    required this.fileBytes,
    required this.staging,
    required this.update,
    required this.working,
    required this.onAdd,
    required this.onAnother,
  });

  final String fileName;
  final int fileBytes;
  final PrivateStaging staging;
  final bool update;
  final bool working;
  final VoidCallback onAdd;
  final VoidCallback onAnother;

  List<_Row> _rows(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final out = <_Row>[
      for (final f in staging.findings)
        _Row(
          f.isError ? _RowSeverity.error : _RowSeverity.warning,
          f.text,
          file: f.file,
          line: f.line,
          card: _cardTokens.contains(f.token) ? f.params['id'] : null,
        ),
    ];
    final manifest = staging.manifest;
    final counts = staging.counts;
    if (manifest != null &&
        counts != null &&
        manifest.kind == PrivateKind.modifiedLanguage &&
        (counts.replacing > 0 || counts.byReference > 0)) {
      out.add(
        _Row(
          _RowSeverity.note,
          l10n.privateNoteReplaces(counts.replacing, counts.byReference),
          file: privateManifestFile,
          hint: l10n.privateNoteReplacesHint,
        ),
      );
    }
    if (manifest != null) {
      final caps = state.privateCapabilities(manifest.language);
      final name = manifest.language.name;
      if (caps.noVoice) {
        out.add(
          _Row(
            _RowSeverity.note,
            l10n.privateNoteVoice(name),
            file: privateManifestFile,
            hint: l10n.privateNoteNothing,
          ),
        );
      } else if (caps.voice == VoiceStatus.available) {
        out.add(
          _Row(
            _RowSeverity.note,
            l10n.privateNoteVoiceOk(name),
            file: privateManifestFile,
          ),
        );
      }
      if (caps.fontBoxes) {
        out.add(
          _Row(
            _RowSeverity.note,
            l10n.privateNoteFont(name),
            file: privateManifestFile,
          ),
        );
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final manifest = staging.manifest;
    final counts = staging.counts;
    final rows = _rows(context);
    int count(_RowSeverity s) => rows.where((r) => r.severity == s).length;
    final errors = count(_RowSeverity.error);
    final warnings = count(_RowSeverity.warning);
    final notes = count(_RowSeverity.note);
    final facts = <(String, String)>[
      if (manifest != null) ...<(String, String)>[
        (
          l10n.privateLabelLanguage,
          manifest.ownName == null || manifest.ownName == manifest.language.name
              ? manifest.language.name
              : '${manifest.language.name} · ${manifest.ownName}',
        ),
        (
          l10n.privateLabelPackage,
          l10n.privatePackageRevision(manifest.package, manifest.revision),
        ),
        (l10n.privateLabelKind, _kind(l10n, manifest)),
      ],
    ];
    // The first line of the first group that has any opens, as the mockup's
    // default variant draws it.
    final firstSeverity = <_RowSeverity>[
      _RowSeverity.error,
      _RowSeverity.warning,
      _RowSeverity.note,
    ].where((s) => rows.any((r) => r.severity == s)).firstOrNull;
    Widget group(_RowSeverity severity, String heading) {
      final list = <_Row>[
        for (final r in rows)
          if (r.severity == severity) r,
      ];
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              heading,
              style: theme.textTheme.titleSmall!.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          for (final (i, row) in list.indexed)
            _FindingTile(
              row: row,
              initiallyExpanded: severity == firstSeverity && i == 0,
            ),
        ],
      );
    }

    final blocked = !staging.canInstall;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
            children: <Widget>[
              _FileBlock(name: fileName, bytes: fileBytes),
              const SizedBox(height: 12),
              if (facts.isNotEmpty) PrivateFacts(rows: facts),
              if (counts != null)
                _Counts(
                  cards: counts.cards,
                  units: counts.units,
                  decks: counts.decks,
                ),
              const SizedBox(height: 12),
              Semantics(
                container: true,
                liveRegion: true,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    PrivateTag(
                      label: l10n.privateSumErrors(errors),
                      icon: Icons.error_outline,
                      kind: errors > 0
                          ? PrivateTagKind.error
                          : PrivateTagKind.neutral,
                    ),
                    PrivateTag(
                      label: l10n.privateSumWarnings(warnings),
                      icon: Icons.warning_amber_outlined,
                      kind: warnings > 0
                          ? PrivateTagKind.warning
                          : PrivateTagKind.neutral,
                    ),
                    PrivateTag(
                      label: l10n.privateSumNotes(notes),
                      icon: Icons.info_outline,
                    ),
                  ],
                ),
              ),
              group(_RowSeverity.error, l10n.privateGroupErrors(errors)),
              group(_RowSeverity.warning, l10n.privateGroupWarnings(warnings)),
              group(_RowSeverity.note, l10n.privateGroupNotes(notes)),
            ],
          ),
        ),
        _Bottom(
          children: <Widget>[
            if (blocked)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: Text(
                  l10n.privateBlockedReason(errors),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            FilledButton(
              key: const ValueKey<String>('private-add-confirm'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: blocked || working ? null : onAdd,
              child: Text(
                update ? l10n.privateContinueUpdate : l10n.privateAddButton,
              ),
            ),
            TextButton(
              onPressed: onAnother,
              child: Text(l10n.privateChooseAnother),
            ),
          ],
        ),
      ],
    );
  }

  String _kind(AppLocalizations l10n, PrivateManifest manifest) {
    final value = manifest.kind == PrivateKind.modifiedLanguage
        ? l10n.privateKindChangedValue(manifest.language.name)
        : l10n.privateKindNewValue;
    final base = manifest.basedOn;
    return base == null ? value : l10n.privateKindBasedOn(value, base);
  }
}

/// One finding: its severity as a word with an icon, where it is, what is
/// wrong, and in its detail the file, line and card and how to fix it.
class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.row, required this.initiallyExpanded});

  final _Row row;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final (
      String word,
      IconData icon,
      PrivateTagKind kind,
    ) = switch (row.severity) {
      _RowSeverity.error => (
        l10n.privateSevError,
        Icons.error_outline,
        PrivateTagKind.error,
      ),
      _RowSeverity.warning => (
        l10n.privateSevWarning,
        Icons.warning_amber_outlined,
        PrivateTagKind.warning,
      ),
      _RowSeverity.note => (
        l10n.privateSevNote,
        Icons.info_outline,
        PrivateTagKind.neutral,
      ),
    };
    final where = row.file == null
        ? null
        : row.line == null
        ? row.file!
        : l10n.privateFindingAt(row.file!, row.line!);
    final detail = <(String, String)>[
      if (row.file != null) (l10n.privateFileLabel, row.file!),
      if (row.line != null) (l10n.privateLineLabel, '${row.line}'),
      if (row.card != null) (l10n.privateCardLabel, row.card!),
    ];
    return ExpansionTile(
      key: PageStorageKey<String>('${row.severity.name}:${row.text}'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsetsDirectional.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      expandedAlignment: AlignmentDirectional.centerStart,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              PrivateTag(label: word, icon: icon, kind: kind),
              if (where != null) Text(where, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(row.text, style: theme.textTheme.bodyMedium),
          if (row.card != null)
            Text(
              l10n.privateFindingCard(row.card!),
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      children: <Widget>[
        if (detail.isNotEmpty) PrivateFacts(rows: detail),
        Text(
          row.hint ?? l10n.privateHowToFix,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// The page of a refusal: a title with its icon, the Refused tag, what
/// follows, and the way out.
class _Refusal extends StatelessWidget {
  const _Refusal({
    required this.title,
    required this.children,
    required this.onAnother,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(AppSizes.gutter),
            children: <Widget>[
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PrivateTag(
                  label: l10n.privateRefused,
                  icon: Icons.error_outline,
                  kind: PrivateTagKind.error,
                ),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
        _Bottom(
          children: <Widget>[
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              onPressed: onAnother,
              child: Text(l10n.privateChooseAnother),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.privateClose),
            ),
          ],
        ),
      ],
    );
  }
}

class _Older extends StatelessWidget {
  const _Older({
    required this.language,
    required this.installed,
    required this.found,
    required this.package,
    required this.onAnother,
  });

  final String language;
  final int installed;
  final int found;
  final String package;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return _Refusal(
      title: l10n.privateOlderTitle,
      onAnother: onAnother,
      children: <Widget>[
        Text(
          l10n.privateOlderBody(language, installed, found),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        PrivateFacts(
          rows: <(String, String)>[
            (l10n.privateInstalledLabel, l10n.privateRevisionValue(installed)),
            (
              l10n.privateThisFileLabel,
              '${l10n.privateRevisionValue(found)} ($package)',
            ),
          ],
        ),
        Text(
          l10n.privateOlderAdvice(installed + 1),
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _TooBig extends StatelessWidget {
  const _TooBig({
    required this.fileName,
    required this.bytes,
    required this.onAnother,
  });

  final String fileName;
  final int bytes;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return _Refusal(
      title: l10n.privateBigTitle,
      onAnother: onAnother,
      children: <Widget>[
        _FileBlock(
          name: fileName,
          bytes: bytes,
          error: l10n.privateBigBody(privateSizeText(bytes)),
        ),
        const SizedBox(height: 12),
        Text(l10n.privateBigAdvice, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text(
          l10n.privateBigNothing,
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Unsafe extends StatelessWidget {
  const _Unsafe({required this.findings, required this.onAnother});

  final List<PrivateFinding> findings;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return _Refusal(
      title: l10n.privateUnsafeTitle,
      onAnother: onAnother,
      children: <Widget>[
        Text(l10n.privateUnsafeBody, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        for (final f in findings.take(5))
          Container(
            margin: const EdgeInsetsDirectional.only(bottom: 6),
            padding: const EdgeInsetsDirectional.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Text(
              f.file == null ? f.text : '${f.file}: ${f.text}',
              style: theme.textTheme.bodySmall!.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          l10n.privateUnsafeOther,
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
