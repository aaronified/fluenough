import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/private_languages.dart';
import '../../app/routes.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import 'private_widgets.dart';

/// The "Privately modified" tag (Plan-Private-Languages, task 15; mockup
/// `private-your-decks` 5a to 5c, the default variant A: a tag under the
/// title). It opens Your decks. Nothing is drawn unless the language's path
/// is a private package's, so a header can hold it unconditionally.
class PrivateModifiedTag extends StatelessWidget {
  const PrivateModifiedTag({super.key, required this.language});

  /// The language code, or null for none (nothing is drawn).
  final String? language;

  @override
  Widget build(BuildContext context) {
    final code = language;
    if (code == null) return const SizedBox.shrink();
    final state = AppScope.of(context);
    if (state.languagePathOf(code)?.privatelyModified != true) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.privateModifiedOpen,
      excludeSemantics: true,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        // hint-ok: shows text
        child: InkWell(
          key: const ValueKey<String>('private-modified-tag'),
          borderRadius: BorderRadius.circular(AppRadii.chip),
          onTap: () =>
              AppNavigator.openSettingsPage(context, AppRoutes.settingsDecks),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
              child: PrivateTag(
                label: l10n.privateModified,
                icon: Icons.edit_outlined,
                kind: PrivateTagKind.modified,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The no-voice notice (task 14; the owner's wording): shown for a private
/// language the phone has no voice for, with Why? which explains and lets the
/// learner ask the phone again. Nothing is drawn otherwise.
class PrivateNoVoiceNotice extends StatelessWidget {
  const PrivateNoVoiceNotice({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final language = _languageOf(state, code);
    if (language == null || !state.privateNoVoice(language)) {
      return const SizedBox.shrink();
    }
    return PrivateNoVoiceBlock(name: language.name);
  }
}

LanguageInfo? _languageOf(AppState state, String code) {
  for (final language in state.languages) {
    if (language.code == code) return language;
  }
  return null;
}

/// The notice itself, for a language whose name is [name].
class PrivateNoVoiceBlock extends StatelessWidget {
  const PrivateNoVoiceBlock({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return PrivateNotice(
      icon: Icons.volume_off_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '${l10n.privateNoVoiceTitle} ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: l10n.privateNoVoiceBody),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => showPrivateWhySheet(context, name: name),
              child: Text(l10n.privateWhy),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sheet behind Why?: what the notice means, and Check again, which asks
/// the phone for its voices once more.
Future<void> showPrivateWhySheet(BuildContext context, {required String name}) {
  final state = AppScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) {
      final l10n = AppLocalizations.of(sheet)!;
      final theme = Theme.of(sheet);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.privateWhyTitle(name),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.privateWhyBody, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                l10n.privateWhyHint(name),
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () async {
                  await state.refreshVoices();
                  if (sheet.mounted) Navigator.of(sheet).pop();
                },
                child: Text(l10n.privateCheckAgain),
              ),
              TextButton(
                onPressed: () => Navigator.of(sheet).pop(),
                child: Text(l10n.privateClose),
              ),
            ],
          ),
        ),
      );
    },
  );
}
