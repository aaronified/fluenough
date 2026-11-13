import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/private_languages.dart';
import '../../core/logs/log_entry.dart';
import '../../core/private/private_check.dart';
import '../../core/private/private_export.dart';
import '../../core/private/private_manifest.dart';
import '../../core/private/private_package.dart';
import '../../core/private/private_starter.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/snack.dart';
import '../settings/settings_controls.dart';
import 'private_cap_sheet.dart';
import 'private_download_page.dart';
import 'private_import_page.dart';
import 'private_notes.dart';
import 'private_widgets.dart';

/// One installed package with what its group shows of it.
class _Entry {
  const _Entry(this.package, this.manifest, this.counts);

  final PrivatePackage package;
  final PrivateManifest? manifest;
  final PrivateCounts? counts;

  String get name => manifest?.language.name ?? package.id;
}

/// What the private language packages part of Your decks shows and does
/// (#1017, Plan-Private-Languages tasks 13 to 16; mockup
/// `private-your-decks`, variants A): the Add a private language action, the
/// rows for what comes later, and a group for each package, or the empty
/// state. The page asks it for [rows], one widget a row, so the page's list
/// stays lazy and its length is known; it listens to it for what it loaded.
class PrivatePackagesController extends ChangeNotifier {
  PrivatePackagesController(this.state);

  final AppState state;
  List<_Entry>? _entries;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    final entries = <_Entry>[];
    try {
      final store = state.privateStore;
      for (final package in await state.privatePackages()) {
        PrivateManifest? manifest;
        PrivateCounts? counts;
        try {
          final files = await store?.readPackage(package.id);
          if (files != null) {
            final text = files[privateManifestFile];
            if (text != null) manifest = PrivateManifest.parse(text);
            counts = PrivateCheck.counts(files);
          }
        } on Object catch (e, stack) {
          // One package that cannot be read costs only its details.
          state.log.error(
            describeError('Private decks: details of ${package.id}', e, stack),
          );
        }
        entries.add(_Entry(package, manifest, counts));
      }
    } on Object catch (e, stack) {
      state.log.error(describeError('Private decks: page load', e, stack));
    }
    if (_disposed) return;
    _entries = entries;
    notifyListeners();
  }

  Future<void> _add(BuildContext context) async {
    await choosePrivatePackage(context);
    await load();
  }

  Future<void> _switch(BuildContext context, _Entry entry, bool on) async {
    final l10n = AppLocalizations.of(context)!;
    final id = entry.package.id;
    if (!on) {
      if (await state.setPrivateActive(id, active: false) !=
              PrivateActivation.done &&
          context.mounted) {
        showAppSnackBar(context, l10n.privateSwitchFailed);
      }
    } else {
      final done = await state.setPrivateActive(id, active: true);
      if (!context.mounted) return;
      if (done == PrivateActivation.needsDeactivation) {
        final all = _entries ?? const <_Entry>[];
        final off = await showPrivateCapSheet(
          context,
          newId: id,
          newName: entry.name,
          active: <PrivatePackage>[
            for (final e in all)
              if (e.package.active && e.package.id != id) e.package,
          ],
          names: <String, String>{for (final e in all) e.package.id: e.name},
          sizes: <String, int>{
            for (final e in all) e.package.id: e.package.size,
          },
        );
        if (off != null) await state.swapPrivate(off: off, on: id);
      } else if (done != PrivateActivation.done) {
        showAppSnackBar(context, l10n.privateSwitchFailed);
      }
    }
    await load();
  }

  Future<void> _export(BuildContext context, _Entry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final id = entry.package.id;
    final done = await state.exportPrivate(id);
    if (!context.mounted || done == PrivateSave.cancelled) return;
    if (done == PrivateSave.saved) {
      showAppSnackBar(
        context,
        l10n.privateExportSaved(
          PrivateExport.fileName(id, entry.package.revision),
        ),
      );
    } else {
      state.haptics.error();
      showAppSnackBar(context, l10n.privateExportFailed);
    }
  }

  Future<void> _starter(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final done = await state.saveStarterPackage();
    if (!context.mounted || done == PrivateSave.cancelled) return;
    showAppSnackBar(
      context,
      done == PrivateSave.saved
          ? l10n.privateStarterSaved(privateStarterFileName)
          : l10n.privateStarterFailed,
    );
  }

  Future<void> _remove(BuildContext context, _Entry entry) async {
    final l10n = AppLocalizations.of(context)!;
    final name = entry.name;
    final modified = entry.manifest?.kind == PrivateKind.modifiedLanguage;
    final choice = await showDialog<_RemoveChoice>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final error = TextStyle(color: scheme.error);
        return AlertDialog(
          title: Text(l10n.privateRemoveTitle(name)),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.privateRemoveBody),
              if (modified) ...<Widget>[
                const SizedBox(height: 8),
                Text(l10n.privateRemoveCourse(name)),
              ],
              const SizedBox(height: 8),
              Text(l10n.privateRemoveDeleteNote),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(_RemoveChoice.cancel),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_RemoveChoice.keep),
              child: Text(l10n.privateRemoveConfirm, style: error),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_RemoveChoice.delete),
              child: Text(l10n.privateRemoveDelete, style: error),
            ),
          ],
        );
      },
    );
    if (choice == null || choice == _RemoveChoice.cancel || !context.mounted)
      return;
    final removed = await state.removePrivate(
      entry.package.id,
      deleteProgress: choice == _RemoveChoice.delete,
    );
    if (!context.mounted) return;
    if (removed) {
      state.haptics.danger();
      showAppSnackBar(context, l10n.privateRemoved(name));
    } else {
      state.haptics.error();
      showAppSnackBar(context, l10n.privateRemoveFailed);
    }
    await load();
  }

  /// The rows of the part, each its own widget.
  List<Widget> rows(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (!state.canAddPrivate) {
      return <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSizes.textInset,
          ),
          child: Text(l10n.privateUnavailable, style: settingsHelpStyle(theme)),
        ),
      ];
    }
    final entries = _entries;
    final active = entries?.where((e) => e.package.active).length ?? 0;
    final used = entries?.fold<int>(0, (n, e) => n + e.package.size) ?? 0;
    return <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Text(l10n.privateIntro, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey<String>('private-add'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.primaryButton),
            ),
            onPressed: () => _add(context),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(l10n.privateAdd),
          ),
        ],
      ),
      GroupedList.settings(
        children: <Widget>[
          GroupedTile(
            leading: const Icon(Icons.download_outlined),
            title: l10n.privateDownload,
            subtitle: l10n.privateDownloadDesc,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivateDownloadPage(),
                ),
              ),
            ),
          ),
          GroupedTile(
            leading: const Icon(Icons.description_outlined),
            title: l10n.privateStarter,
            subtitle: l10n.privateStarterDesc,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(_starter(context)),
          ),
        ],
      ),
      if (entries != null && entries.isEmpty) _Empty(),
      if (entries != null && entries.isNotEmpty) ...<Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.textInset,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.privateListHeading(entries.length),
                  style: theme.textTheme.groupLabel.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSizes.textInset,
              ),
              child: Text(
                l10n.privateUsage(active, privateSizeText(used)),
                style: settingsHelpStyle(theme),
              ),
            ),
          ],
        ),
        for (final entry in entries)
          _Group(
            entry: entry,
            slotsFull: active >= maxActivePrivatePackages,
            onSwitch: (on) => _switch(context, entry, on),
            onUpdate: () => _add(context),
            onExport: () => _export(context, entry),
            onRemove: () => _remove(context, entry),
          ),
      ],
    ];
  }
}

enum _RemoveChoice { cancel, keep, delete }

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.menu_book_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.privateEmptyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.privateEmptyBody,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// One package: its name and tags, what it holds, the Active switch, the
/// capability notice, and Update, Export and Remove.
class _Group extends StatelessWidget {
  const _Group({
    required this.entry,
    required this.slotsFull,
    required this.onSwitch,
    required this.onUpdate,
    required this.onExport,
    required this.onRemove,
  });

  final _Entry entry;
  final bool slotsFull;
  final ValueChanged<bool> onSwitch;
  final VoidCallback onUpdate;
  final VoidCallback onExport;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final package = entry.package;
    final manifest = entry.manifest;
    final modified = manifest?.kind == PrivateKind.modifiedLanguage;
    final needsSlot = !package.active && slotsFull;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final own = manifest?.ownName ?? manifest?.language.name ?? package.id;
    final counts = entry.counts;
    final facts = <(String, String)>[
      (l10n.privateSize, l10n.privateSizeValue(privateSizeText(package.size))),
      if (counts != null)
        (
          l10n.privateHolds,
          l10n.privateHoldsValue(counts.cards, counts.units, counts.decks),
        ),
      if (manifest?.basedOn case final base?) (l10n.privateBasedOn, base),
      (
        l10n.privateAddedOn,
        DateFormat.yMMMd(locale).format(package.importedAt.toLocal()),
      ),
    ];
    final language = manifest?.language;
    final noVoice =
        package.active &&
        language != null &&
        !modified &&
        state.privateNoVoice(language);
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.group),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: Text(own.characters.first),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          entry.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        l10n.privateSubtitle(own, package.id, package.revision),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                PrivateTag(
                  label: modified
                      ? l10n.privateKindChanged
                      : l10n.privateKindNew,
                ),
                if (modified && package.active)
                  PrivateTag(
                    label: l10n.privateModified,
                    icon: Icons.edit_outlined,
                    kind: PrivateTagKind.modified,
                  ),
                if (needsSlot)
                  PrivateTag(
                    label: l10n.privateNeedsSlot,
                    icon: Icons.warning_amber_outlined,
                    kind: PrivateTagKind.warning,
                  )
                else if (package.active)
                  PrivateTag(
                    label: l10n.privateActive,
                    icon: Icons.check,
                    kind: PrivateTagKind.active,
                  )
                else
                  PrivateTag(label: l10n.privateNotActive),
              ],
            ),
            const SizedBox(height: 12),
            PrivateFacts(rows: facts),
            PrivateSizeBar(bytes: package.size),
            const SizedBox(height: 8),
            GroupedTile.toggle(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
              title: l10n.privateActive,
              subtitleOn: l10n.privateSwitchOn,
              subtitleOff: needsSlot
                  ? l10n.privateSwitchNeeds
                  : l10n.privateSwitchOff,
              value: package.active,
              onChanged: onSwitch,
            ),
            if (noVoice) ...<Widget>[
              const SizedBox(height: 8),
              PrivateNoVoiceBlock(name: entry.name),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                OutlinedButton(
                  onPressed: onUpdate,
                  child: Text(l10n.privateUpdate),
                ),
                OutlinedButton(
                  onPressed: onExport,
                  child: Text(l10n.privateExport),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  onPressed: onRemove,
                  child: Text(l10n.privateRemove),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
