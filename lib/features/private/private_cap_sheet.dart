import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/private_languages.dart';
import '../../core/private/private_package.dart';
import '../../l10n/app_localizations.dart';
import 'private_widgets.dart';

/// The sheet shown when a fourth private language is turned on or added
/// (Plan-Private-Languages, tasks 13 and 16; mockup `private-your-decks`
/// screen 2, owner 2026-11-13: a sheet at once, the least recently studied
/// preselected): it asks which of the [active] packages to turn off.
///
/// Returns the id of the package to turn off, or null to keep [newId] off.
/// [names] and [sizes] are by package id. Nothing is deleted either way.
Future<String?> showPrivateCapSheet(
  BuildContext context, {
  required String newId,
  required String newName,
  required List<PrivatePackage> active,
  required Map<String, String> names,
  required Map<String, int> sizes,
}) async {
  final state = AppScope.read(context);
  final ordered = await state.privateLeastRecentlyStudied(active);
  if (!context.mounted || ordered.isEmpty) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _CapSheet(
      newName: newName,
      ordered: ordered,
      names: names,
      sizes: sizes,
      lastStudied: <String, DateTime?>{
        for (final p in ordered) p.id: state.privateLastStudied(p.id),
      },
    ),
  );
}

class _CapSheet extends StatefulWidget {
  const _CapSheet({
    required this.newName,
    required this.ordered,
    required this.names,
    required this.sizes,
    required this.lastStudied,
  });

  final String newName;
  final List<PrivatePackage> ordered;
  final Map<String, String> names;
  final Map<String, int> sizes;
  final Map<String, DateTime?> lastStudied;

  @override
  State<_CapSheet> createState() => _CapSheetState();
}

class _CapSheetState extends State<_CapSheet> {
  late String _off = widget.ordered.first.id;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    String nameOf(String id) => widget.names[id] ?? id;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.privateCapTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            l10n.privateCapBody(widget.newName),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text(
              l10n.privateCapTurnOff,
              style: theme.textTheme.titleSmall!.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          RadioGroup<String>(
            groupValue: _off,
            onChanged: (id) {
              if (id != null) setState(() => _off = id);
            },
            child: Column(
              children: <Widget>[
                for (final package in widget.ordered)
                  RadioListTile<String>(
                    value: package.id,
                    contentPadding: EdgeInsets.zero,
                    title: Text(nameOf(package.id)),
                    subtitle: Text(
                      widget.lastStudied[package.id] == null
                          ? l10n.privateNeverStudied(
                              privateSizeText(widget.sizes[package.id] ?? 0),
                            )
                          : l10n.privateStudiedOn(
                              DateFormat.yMMMd(locale).format(
                                widget.lastStudied[package.id]!.toLocal(),
                              ),
                              privateSizeText(widget.sizes[package.id] ?? 0),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_off),
            child: Text(l10n.privateCapSwap(nameOf(_off), widget.newName)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.privateCapKeep(widget.newName)),
          ),
        ],
      ),
    );
  }
}
