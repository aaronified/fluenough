import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/snack.dart';
import '../decks/import_page.dart' show saveDeckTemplate;
import '../private/private_decks_section.dart';
import '../../ui/theme.dart';
import 'settings_controls.dart';
import 'settings_section_page.dart';

/// Settings' Your decks page (#475, #495, #1017): the private language
/// packages first (Add a private language, a group for each package); then
/// Upload a deck, which opens the
/// page that checks a file and adds it; Get a template, which saves the
/// single-deck template; and the decks the learner added, grouped by the
/// language learned and then the language it is taught from, each with Open
/// and Remove, which asks first and is in the error colour. Sending a deck to
/// the project is retired (#1017): nothing leaves the phone.
class YourDecksPage extends StatefulWidget {
  const YourDecksPage({super.key});

  @override
  State<YourDecksPage> createState() => _YourDecksPageState();

  /// The decks the learner added, in the order they were found.
  static List<DeckEntry> ownDecks(Iterable<DeckEntry> decks) => <DeckEntry>[
    for (final entry in decks)
      if (!entry.bundled && !entry.private) entry,
  ];
}

class _YourDecksPageState extends State<YourDecksPage> {
  PrivatePackagesController? _private;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_private == null) {
      _private = PrivatePackagesController(AppScope.read(context));
      unawaited(_private!.load());
    }
  }

  @override
  void dispose() {
    _private?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final own = YourDecksPage.ownDecks(state.decks);
    // Grouped by "language › from native", in the order first met.
    final groups = <(String, String), List<DeckEntry>>{};
    for (final entry in own) {
      groups
          .putIfAbsent((
            entry.language.name,
            entry.deck.native.name,
          ), () => <DeckEntry>[])
          .add(entry);
    }
    return SettingsSectionPage(
      title: l10n.settingsRowDecks,
      listenable: _private,
      builder: (context) => <Widget>[
        // Private language packages (#1017): their own part of the page.
        ..._private!.rows(context),
        GroupedList.settings(
          children: <Widget>[
            GroupedTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: l10n.settingsDecksUpload,
              subtitle: l10n.settingsDecksUploadDesc,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => AppNavigator.openImport(context),
            ),
            GroupedTile(
              leading: const Icon(Icons.description_outlined),
              title: l10n.settingsDecksTemplate,
              subtitle: l10n.settingsDecksTemplateDesc,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => unawaited(saveDeckTemplate(context)),
            ),
          ],
        ),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSizes.textInset,
            ),
            child: Text(
              l10n.settingsDecksNone,
              style: settingsHelpStyle(Theme.of(context)),
            ),
          )
        else
          for (final MapEntry(key: (language, native), value: entries)
              in groups.entries)
            GroupedList.settings(
              header: l10n.settingsDecksGroup(language, native),
              children: <Widget>[
                for (final entry in entries) _OwnDeck(entry: entry),
              ],
            ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSizes.textInset,
          ),
          child: Text(
            l10n.settingsDecksAbout,
            style: settingsHelpStyle(Theme.of(context)),
          ),
        ),
      ],
    );
  }
}

/// A deck the learner added: its name and size, then Open and Remove.
class _OwnDeck extends StatelessWidget {
  const _OwnDeck({required this.entry});

  final DeckEntry entry;

  Future<void> _remove(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    final name = entry.deck.name;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deckRemoveTitle(name)),
        content: Text(l10n.deckRemoveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.deckRemoveConfirm,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (remove != true || !context.mounted) return;
    showAppSnackBar(context, l10n.deckRemoved(name));
    try {
      await state.removeDeck(entry.id);
    } on Object {
      state.haptics.error();
      rethrow;
    }
    state.haptics.danger();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(entry.deck.name, style: theme.textTheme.titleMedium),
          Text(
            l10n.settingsDecksCards(entry.itemCount),
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: <Widget>[
              TextButton(
                onPressed: () => AppNavigator.openDeck(context, entry.id),
                child: Text(l10n.settingsDecksOpen),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: () => _remove(context),
                child: Text(l10n.settingsDecksRemove),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
