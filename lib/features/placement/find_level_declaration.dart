import 'package:flutter/material.dart';

import '../../core/placement/assurance_model.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// The first question of Find my level (wiki/Plan-Placement-V2.md, section
/// 4.5): "How well do you know the language?", with only the answers the
/// course's built path supports ([options], from `declarationOptionsFor`).
///
/// The learner must answer: there is no Skip. Back leaves the screen with
/// nothing chosen, which cancels the whole Find my level and writes nothing.
/// An answer is handed to the caller with `Navigator.pop`; it is never stored
/// or shown afterwards (it only decides where the questions start).
class FindLevelDeclarationPage extends StatelessWidget {
  const FindLevelDeclarationPage({
    super.key,
    required this.language,
    required this.options,
  });

  /// The language's name.
  final String language;

  /// The answers on offer, in the order shown.
  final List<PlacementDeclaration> options;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.gutter),
          children: <Widget>[
            Text(
              l10n.findLevelDeclarationTitle(language),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            for (final option in options) ...<Widget>[
              Material(
                color: scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                // hint-ok: shows text
                child: InkWell(
                  key: ValueKey<String>('find-level-${option.name}'),
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                  onTap: () => Navigator.of(context).pop(option),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      14,
                      16,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _name(l10n, option),
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          _sub(l10n, option),
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  static String _name(AppLocalizations l10n, PlacementDeclaration d) =>
      switch (d) {
        PlacementDeclaration.expert => l10n.findLevelExpert,
        PlacementDeclaration.advanced => l10n.findLevelAdvanced,
        PlacementDeclaration.amateur => l10n.findLevelAmateur,
        PlacementDeclaration.beginner => l10n.findLevelBeginner,
      };

  static String _sub(AppLocalizations l10n, PlacementDeclaration d) =>
      switch (d) {
        PlacementDeclaration.expert => l10n.findLevelExpertSub,
        PlacementDeclaration.advanced => l10n.findLevelAdvancedSub,
        PlacementDeclaration.amateur => l10n.findLevelAmateurSub,
        PlacementDeclaration.beginner => l10n.findLevelBeginnerSub,
      };
}
