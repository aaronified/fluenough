import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/deck_catalog.dart';
import '../../app/routes.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// The language menu at the top of Today, Decks, Progress and a deck's or a
/// unit's page (#461): which language the whole app shows, one of those the
/// learner learns, or "All languages". Not on Settings, whose choices are
/// not one language's.
///
/// A button with the shown language's glyph, or a globe for All, that opens
/// a menu of the languages by name. Its tooltip and screen-reader label say
/// which language is shown. Nothing shows while no language has a deck.
///
/// The choice is kept in Settings (`SettingsNotifier.languageChoice`) and
/// read through `AppState.shownLanguage`, which everything filtered reads.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key, this.pageLanguage});

  /// On a page of one language's content, such as a deck's: that
  /// language's code. Choosing to show another goes back to the tabs, which
  /// then show it, rather than leave a page the app no longer shows.
  final String? pageLanguage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final choices = state.languageChoices;
    if (choices.isEmpty) return const SizedBox.shrink();
    final shown = state.shownLanguage;
    final current = choices.where((l) => l.code == shown).firstOrNull;
    final label = l10n.languageMenuLabel(current?.name ?? l10n.languageMenuAll);

    void choose(String? code) {
      state.showLanguage(code);
      final page = pageLanguage;
      if (page != null && !state.showsLanguage(page)) {
        AppNavigator.backToShell(context);
      }
    }

    MenuItemButton item(String? code, Widget text) => MenuItemButton(
      leadingIcon: SizedBox.square(
        dimension: 24,
        child: code == shown ? const Icon(Icons.check) : null,
      ),
      onPressed: () => choose(code),
      child: text,
    );

    return MenuAnchor(
      menuChildren: <Widget>[
        item(null, Text(l10n.languageMenuAll)),
        for (final language in choices)
          item(
            language.code,
            Text(language.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(AppSizes.iconButton, AppSizes.iconButton),
            padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 2, 4),
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Semantics(
            label: label,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (current == null)
                    const Icon(Icons.language)
                  else
                    _Glyph(language: current, decks: state.decks),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [language]'s character on a small tile, as on its chips (ADR-0027): its
/// icon, or the glyph of its first deck.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.language, required this.decks});

  final LanguageInfo language;
  final List<DeckEntry> decks;

  String get _glyph {
    if (language.icon case final icon?) return icon;
    for (final entry in decks) {
      if (entry.language.code == language.code) {
        return entry.language.icon ?? entry.glyph;
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _glyph,
        locale: Locale(language.code),
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: 16,
          height: 24 / 16,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
