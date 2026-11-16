import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/private_import.dart';
import '../../app/private_languages.dart';
import '../../core/private/private_package.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/snack.dart';
import 'private_cap_sheet.dart';

/// Installs the checked package [staging] (Plan-Private-Languages, tasks 13,
/// 17 and 18): a fourth active package opens the sheet at once, the least
/// recently studied preselected; the learner turns one off (the package
/// goes in on) or keeps the new one off. Says in a toast what came of it.
///
/// [update] is whether the package is a newer file of one installed: only
/// the toast differs. Returns whether the package was installed.
Future<bool> installPrivateFlow(
  BuildContext context,
  PrivateStaging staging, {
  required bool update,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final state = AppScope.read(context);
  final manifest = staging.manifest;
  if (manifest == null) return false;
  final name = manifest.language.name;
  var result = await state.installPrivate(staging);
  if (!context.mounted) return result.installed;
  if (result.outcome == PrivateImportOutcome.needsDeactivation) {
    final names = <String, String>{};
    final sizes = <String, int>{};
    for (final package in result.active) {
      final other = await state.manifestOf(package.id);
      names[package.id] = other?.language.name ?? package.id;
      sizes[package.id] = package.size;
    }
    if (!context.mounted) return false;
    final off = await showPrivateCapSheet(
      context,
      newId: manifest.package,
      newName: name,
      active: result.active,
      names: names,
      sizes: sizes,
    );
    if (!context.mounted) return false;
    if (off == null) {
      result = await state.installPrivate(staging, active: false);
    } else if (await state.setPrivateActive(off, active: false) ==
        PrivateActivation.done) {
      result = await state.installPrivate(staging);
    }
  }
  if (!context.mounted) return result.installed;
  if (result.installed) {
    state.haptics.confirm();
    showAppSnackBar(
      context,
      update
          ? l10n.privateUpdatedToast(name, manifest.revision)
          : l10n.privateAddedToast(name),
    );
    return true;
  }
  state.haptics.error();
  showAppSnackBar(context, l10n.privateInstallFailed);
  return false;
}
