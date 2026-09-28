import 'package:flutter/material.dart' hide Card;

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/deck_catalog.dart';
import '../../app/features.dart';
import '../../app/settings.dart';
import '../../core/models/card.dart';
import '../../core/models/deck.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/segmented.dart';
import '../../ui/widgets/target_text.dart';
import 'settings_controls.dart';

/// "System", "Light" or "Dark".
String themeModeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
  ThemeMode.system => l10n.appearanceThemeSystem,
  ThemeMode.light => l10n.appearanceThemeLight,
  ThemeMode.dark => l10n.appearanceThemeDark,
};

/// "Forest", "Ocean", "Clay" or "Iris".
String seedLabel(AppLocalizations l10n, ThemeSeed seed) => switch (seed) {
  ThemeSeed.forest => l10n.appearanceSeedForest,
  ThemeSeed.ocean => l10n.appearanceSeedOcean,
  ThemeSeed.clay => l10n.appearanceSeedClay,
  ThemeSeed.iris => l10n.appearanceSeedIris,
};

/// The line under Settings' Appearance row: "System · Forest", with
/// "· High contrast" when that is on.
String appearanceSummary(AppLocalizations l10n, SettingsNotifier settings) {
  final theme = themeModeLabel(l10n, settings.themeMode);
  final colour = settings.dynamicColour
      ? l10n.appearanceWallpaper
      : seedLabel(l10n, settings.seed);
  return settings.highContrast
      ? l10n.settingsAppearanceSummaryHigh(theme, colour)
      : l10n.settingsAppearanceSummary(theme, colour);
}

/// Theme, colour, contrast and card text size.
///
/// Design screen `appearance`. Built as designed, and every control is
/// disabled behind its feature until #15 and #26 land: the theme behind
/// `Feature.appearance`, the seeds behind `colourSeeds`, wallpaper colours
/// behind `dynamicColour` (which needs a dependency), contrast behind
/// `contrast` and the card size behind `cardSize`. Until then the app keeps
/// the repository's seed, #3F6C51, and follows the phone's dark theme. With
/// `FeatureRegistry.all()`, as the gallery shows it, every control changes
/// [SettingsNotifier], which `FluenoughApp` already reads.
///
/// The preview at the top draws a real card from the loaded decks in the
/// chosen theme, colour, contrast and card size.
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final settings = state.settings;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceTitle)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final features = state.features;
          final dynamicOn =
              features.isAvailable(Feature.dynamicColour) &&
              settings.dynamicColour;
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
            children: <Widget>[
              _Preview(sample: previewCard(state), settings: settings),
              const SizedBox(height: 24),
              SettingsSection(
                feature: Feature.appearance,
                heading: l10n.appearanceTheme,
                help: l10n.appearanceThemeHelp,
                child: Segmented<ThemeMode>(
                  semanticLabel: l10n.appearanceTheme,
                  height: 72,
                  selected: settings.themeMode,
                  onSelected: features.isAvailable(Feature.appearance)
                      ? (mode) => settings.themeMode = mode
                      : null,
                  options: <SegmentOption<ThemeMode>>[
                    for (final (mode, icon) in _themeIcons)
                      SegmentOption<ThemeMode>(
                        value: mode,
                        label: themeModeLabel(l10n, mode),
                        icon: icon,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _Block(
                child: GroupedTile.toggle(
                  title: l10n.appearanceWallpaper,
                  subtitle: l10n.appearanceWallpaperDesc,
                  feature: Feature.dynamicColour,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  value: dynamicOn,
                  onChanged: (on) => settings.dynamicColour = on,
                ),
              ),
              const SizedBox(height: 24),
              SettingsSection(
                feature: Feature.colourSeeds,
                heading: l10n.appearanceColour,
                // The seeds do not apply while wallpaper colours are on.
                dimmed: dynamicOn,
                child: _SeedPicker(
                  selected: dynamicOn ? null : settings.seed,
                  onSelected:
                      features.isAvailable(Feature.colourSeeds) && !dynamicOn
                      ? (seed) => settings.seed = seed
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              SettingsSection(
                feature: Feature.contrast,
                heading: l10n.appearanceContrast,
                child: Segmented<bool>(
                  semanticLabel: l10n.appearanceContrast,
                  height: 48,
                  selected: settings.highContrast,
                  onSelected: features.isAvailable(Feature.contrast)
                      ? (high) => settings.highContrast = high
                      : null,
                  options: <SegmentOption<bool>>[
                    SegmentOption<bool>(
                      value: false,
                      label: l10n.appearanceContrastStandard,
                    ),
                    SegmentOption<bool>(
                      value: true,
                      label: l10n.appearanceContrastHigh,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _Block(
                child: SettingsSlider(
                  feature: Feature.cardSize,
                  title: l10n.appearanceCardSize,
                  help: l10n.appearanceCardSizeHelp,
                  valueLabel: l10n.commonPercent(settings.cardTextScale),
                  value: settings.cardTextScale,
                  min: SettingsNotifier.minCardTextScale,
                  max: SettingsNotifier.maxCardTextScale,
                  divisions: 6,
                  semanticValue: (v) => l10n.commonPercent(_step(v)),
                  onChanged: (v) => settings.cardTextScale = _step(v),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static const List<(ThemeMode, IconData)> _themeIcons =
      <(ThemeMode, IconData)>[
        (ThemeMode.system, Icons.brightness_auto_outlined),
        (ThemeMode.light, Icons.light_mode_outlined),
        (ThemeMode.dark, Icons.dark_mode_outlined),
      ];

  /// Rounded to the slider's 0.1 step.
  static double _step(double v) => (v * 10).round() / 10;

  /// The card the preview shows: the first with a reading line in the
  /// profile's decks, then in any deck, so that the romanisation shows too;
  /// failing that, any card at all. Null with no cards loaded.
  static ({Card card, LanguageInfo language})? previewCard(AppState state) {
    final decks = <DeckEntry>[...state.profileDecks, ...state.decks];
    for (final deck in decks) {
      for (final card in deck.cards) {
        if (card.reading?.trim().isNotEmpty ?? false) {
          return (card: card, language: deck.language);
        }
      }
    }
    for (final deck in decks) {
      if (deck.cards.isNotEmpty) {
        return (card: deck.cards.first, language: deck.language);
      }
    }
    return null;
  }
}

/// A block on its own with the design's 24 px corners.
class _Block extends StatelessWidget {
  const _Block({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: child,
  );
}

/// A card and three rating buttons, drawn in the chosen theme, colour,
/// contrast and card size. Decorative, so hidden from screen readers, as the
/// design marks it.
class _Preview extends StatelessWidget {
  const _Preview({required this.sample, required this.settings});

  final ({Card card, LanguageInfo language})? sample;
  final SettingsNotifier settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brightness = switch (settings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => Theme.of(context).brightness,
    };
    final theme = brightness == Brightness.dark
        ? AppTheme.dark(
            seed: settings.seed,
            highContrast: settings.highContrast,
          )
        : AppTheme.light(
            seed: settings.seed,
            highContrast: settings.highContrast,
          );
    final scheme = theme.colorScheme;
    final s = sample;
    final reading = s?.card.reading;

    Widget pill(String label, Color bg, Color fg, FontWeight weight) =>
        Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge!.copyWith(
              color: fg,
              fontWeight: weight,
            ),
          ),
        );

    return ExcludeSemantics(
      child: Theme(
        data: theme,
        child: Container(
          padding: const EdgeInsetsDirectional.all(20),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.hero),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsetsDirectional.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (s != null)
                        TargetText(
                          s.card.target,
                          language: s.language,
                          fontSize: 40 * settings.cardTextScale,
                          color: scheme.onSurface,
                        ),
                      if (reading != null && settings.showRomanisation) ...[
                        const SizedBox(height: 4),
                        Text(
                          reading,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    pill(
                      l10n.rateGood,
                      scheme.primary,
                      scheme.onPrimary,
                      FontWeight.w700,
                    ),
                    const SizedBox(height: 8),
                    pill(
                      l10n.rateHard,
                      scheme.secondaryContainer,
                      scheme.onSecondaryContainer,
                      FontWeight.w600,
                    ),
                    const SizedBox(height: 8),
                    pill(
                      l10n.rateEasy,
                      scheme.tertiaryContainer,
                      scheme.onTertiaryContainer,
                      FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four colour seeds, each a circle of its primary over its secondary
/// and tertiary containers in the current brightness, with a check on the
/// chosen one. Two to a row when the text is large.
class _SeedPicker extends StatelessWidget {
  const _SeedPicker({required this.selected, required this.onSelected});

  /// Null while wallpaper colours are on: no seed applies.
  final ThemeSeed? selected;
  final ValueChanged<ThemeSeed>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final columns = MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 2 : 4;
    final seeds = ThemeSeed.values;

    Widget tile(ThemeSeed seed) {
      final scheme = ColorScheme.fromSeed(
        seedColor: Color(seed.argb),
        brightness: theme.brightness,
      );
      final isSelected = seed == selected;
      final pick = onSelected;
      return Semantics(
        inMutuallyExclusiveGroup: true,
        checked: isSelected,
        button: true,
        label: seedLabel(l10n, seed),
        excludeSemantics: true,
        onTap: pick == null ? null : () => pick(seed),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          onTap: pick == null ? null : () => pick(seed),
          child: Ink(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.surfaceContainerHigh : null,
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Column(
              children: <Widget>[
                _Swatch(scheme: scheme, selected: isSelected),
                const SizedBox(height: 6),
                Text(
                  seedLabel(l10n, seed),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.appearanceColour,
      child: Column(
        children: <Widget>[
          for (var start = 0; start < seeds.length; start += columns) ...[
            if (start > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var i = start; i < start + columns; i++) ...[
                  if (i > start) const SizedBox(width: 12),
                  Expanded(
                    child: i < seeds.length
                        ? tile(seeds[i])
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A 56 px circle: [scheme]'s primary on top, its secondary and tertiary
/// containers below, and a check in a primary square when [selected].
class _Swatch extends StatelessWidget {
  const _Swatch({required this.scheme, required this.selected});

  final ColorScheme scheme;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 56,
    child: ClipOval(
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(child: ColoredBox(color: scheme.primary)),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ColoredBox(color: scheme.secondaryContainer),
                    ),
                    Expanded(
                      child: ColoredBox(color: scheme.tertiaryContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (selected)
            Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.check, size: 18, color: scheme.onPrimary),
              ),
            ),
        ],
      ),
    ),
  );
}
