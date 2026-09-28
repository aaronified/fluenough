import 'package:flutter/material.dart';

import '../app/settings.dart';
import '../app/skill.dart';

/// The app's Material 3 themes, built from the repository's seed.
///
/// The design's "Forest" is the M3 tonal-spot scheme from seed `#3F6C51`, so
/// the schemes are generated with [ColorScheme.fromSeed] and never copied from
/// the design's hex tables. Component shapes and sizes follow the design:
/// 56 px stadium buttons, 10 px chips, 16 px SnackBars, an 80 px navigation
/// bar.
abstract final class AppTheme {
  static ThemeData light({
    ThemeSeed seed = ThemeSeed.forest,
    bool highContrast = false,
  }) => fromScheme(
    _scheme(seed, Brightness.light, highContrast),
    modes: ModeColors.light,
  );

  static ThemeData dark({
    ThemeSeed seed = ThemeSeed.forest,
    bool highContrast = false,
  }) => fromScheme(
    _scheme(seed, Brightness.dark, highContrast),
    modes: ModeColors.dark,
  );

  static ColorScheme _scheme(ThemeSeed seed, Brightness b, bool high) =>
      ColorScheme.fromSeed(
        seedColor: Color(seed.argb),
        brightness: b,
        contrastLevel: high ? 1.0 : 0.0,
      );

  /// A theme for [scheme], with the design's component shapes.
  static ThemeData fromScheme(ColorScheme scheme, {required ModeColors modes}) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = _textTheme(base.textTheme);
    const stadium = StadiumBorder();

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[modes],
      appBarTheme: AppBarTheme(
        toolbarHeight: 64,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge!.copyWith(color: scheme.onSurface),
        titleSpacing: 4,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, AppSizes.primaryButton),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.symmetric(horizontal: 24),
          ),
          shape: const WidgetStatePropertyAll(stadium),
          textStyle: WidgetStatePropertyAll(
            text.titleMedium!.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, AppSizes.primaryButton),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.symmetric(horizontal: 20),
          ),
          shape: const WidgetStatePropertyAll(stadium),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.38)
                : scheme.onSurface,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? scheme.onSurface.withValues(alpha: 0.12)
                  : scheme.outline,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            text.titleMedium!.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(48, AppSizes.compactButton),
          ),
          shape: const WidgetStatePropertyAll(stadium),
          textStyle: WidgetStatePropertyAll(
            text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(AppSizes.iconButton)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        labelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: scheme.secondaryContainer)
              : BorderSide(color: scheme.outline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium!.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        // Symmetric, so the start and end insets are the same in either direction.
        insetPadding: const EdgeInsets.symmetric(horizontal: 16)
            .copyWith(bottom: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleMedium!.copyWith(color: scheme.onSurface),
        subtitleTextStyle: text.bodyMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }

  /// M3's type scale with the design's heavier weights: headings at 600
  /// where M3 has 400, labels at 600 where M3 has 500.
  static TextTheme _textTheme(TextTheme t) {
    TextStyle w(TextStyle? s, FontWeight weight) =>
        s!.copyWith(fontWeight: weight);
    return t.copyWith(
      displaySmall: w(t.displaySmall, FontWeight.w600),
      headlineLarge: w(t.headlineLarge, FontWeight.w600),
      headlineMedium: w(t.headlineMedium, FontWeight.w600),
      headlineSmall: w(t.headlineSmall, FontWeight.w600),
      titleLarge: w(t.titleLarge, FontWeight.w600),
      titleMedium: w(t.titleMedium, FontWeight.w600),
      titleSmall: w(t.titleSmall, FontWeight.w600),
      labelLarge: w(t.labelLarge, FontWeight.w600),
      labelMedium: w(t.labelMedium, FontWeight.w600),
      labelSmall: w(t.labelSmall, FontWeight.w600),
    );
  }
}

/// The design's own text styles, beyond M3's scale. Read them as
/// `Theme.of(context).textTheme.hero` and so on; they take their colour from
/// the surrounding [DefaultTextStyle] like the rest of the text theme.
///
/// The rest of the design's type maps straight onto M3's scale:
///
/// | Design | Use |
/// | --- | --- |
/// | 36/44, "Who's practising?" | `displaySmall` |
/// | 32/40, a tab's title | `headlineLarge` |
/// | 28/36, a deck's name, "Hi, Aro" | `headlineMedium` |
/// | 24/32, Today's greeting | `headlineSmall` |
/// | 22/28, a back-button page's title | `titleLarge` |
/// | 16/24 semibold, a row's title | `titleMedium` |
/// | 16/24, body copy | `bodyLarge` |
/// | 14/20, secondary lines | `bodyMedium` |
/// | 12/16, navigation labels | `labelMedium` |
extension AppTextStyles on TextTheme {
  /// 72/72, extra bold, tight: the number of cards due on Today.
  TextStyle get hero => displayLarge!.copyWith(
    fontSize: 72,
    height: 1,
    fontWeight: FontWeight.w800,
    letterSpacing: -2,
  );

  /// 18/24 semibold: "Your decks", the streak line, a summary card's title.
  TextStyle get sectionTitle => titleMedium!.copyWith(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  /// 28/34 bold: the number on a stat tile.
  TextStyle get statValue => headlineMedium!.copyWith(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
  );

  /// 12/16 bold: badges such as "Feature incoming" and "9 due".
  TextStyle get badge =>
      labelMedium!.copyWith(fontWeight: FontWeight.w700, height: 16 / 12);

  /// 14/20 bold: the heading of a settings group, drawn in `primary`.
  TextStyle get groupLabel => labelLarge!.copyWith(fontWeight: FontWeight.w700);
}

/// Sizes the design uses again and again.
abstract final class AppSizes {
  /// A primary button: "Review all due", "Create profile".
  static const double primaryButton = 56;

  /// The main action of a screen: "Start review", "Show answer", "Continue".
  static const double tallButton = 64;

  /// A small button inside a row: "Set up", "Test", "Switch".
  static const double compactButton = 40;

  /// Icon buttons, and the minimum touch target.
  static const double iconButton = 48;

  /// Side padding of a screen's content.
  static const double gutter = 16;
}

/// Corner radii from the design.
abstract final class AppRadii {
  /// Inner corners of a row inside a group.
  static const double innerRow = 6;

  /// Chips.
  static const double chip = 10;

  /// Text fields, SnackBars, glyph tiles.
  static const double small = 16;

  /// Stat tiles, the answer field.
  static const double tile = 20;

  /// Cards and settings groups.
  static const double card = 24;

  /// Outer corners of a group of rows.
  static const double group = 28;

  /// Today's due card.
  static const double hero = 32;

  /// The card in a drill.
  static const double drillCard = 40;
}

/// Button styles for the design's other sizes, merged over the theme's:
/// `FilledButton(style: AppButtonStyles.tall(context), …)`. They take their
/// text from the theme's type scale, so they keep its font.
abstract final class AppButtonStyles {
  /// 64 px, 18 px bold: the main action of a screen.
  static ButtonStyle tall(BuildContext context) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(64, AppSizes.tallButton)),
    textStyle: WidgetStatePropertyAll(
      Theme.of(context).textTheme.titleLarge!
          .copyWith(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w700),
    ),
  );

  /// 40 px with 14 px side padding: a button inside a row.
  static ButtonStyle compact(BuildContext context) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, AppSizes.compactButton)),
    padding: const WidgetStatePropertyAll(
      EdgeInsetsDirectional.symmetric(horizontal: 14),
    ),
    textStyle: WidgetStatePropertyAll(
      Theme.of(context).textTheme.labelLarge!
          .copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

/// How large to draw a card's target text, from the design: 96 for one or two
/// characters, 64 up to five, 48 beyond, times the learner's card text scale.
abstract final class TargetSizes {
  static double forText(String text, {double scale = 1.0}) {
    final graphemes = text.characters.length;
    final base = graphemes <= 2
        ? 96.0
        : graphemes <= 5
        ? 64.0
        : 48.0;
    return base * scale;
  }

  /// Line height for left-to-right scripts.
  static const double ltrHeight = 1.25;

  /// Line height for right-to-left scripts. Nastaliq climbs and descends far
  /// more than Latin, so it needs the room.
  static const double rtlHeight = 1.9;
}

/// A mode's container colour and the text colour on it.
@immutable
class ModeColor {
  const ModeColor(this.container, this.onContainer);

  final Color container;
  final Color onContainer;

  static ModeColor lerp(ModeColor a, ModeColor b, double t) => ModeColor(
    Color.lerp(a.container, b.container, t)!,
    Color.lerp(a.onContainer, b.onContainer, t)!,
  );
}

/// A fixed colour per skill, the same whatever the seed (Main.dc.html's
/// MODE_COLORS): tone 90 on tone 10 in light, tone 30 on tone 90 in dark.
///
/// Text contrast is 7:1 or better in both. The containers are close to the
/// surface (1.2:1 light, 2.0:1 dark), which is why a mode is never shown by
/// colour alone: every pill carries an icon and a label.
class ModeColors extends ThemeExtension<ModeColors> {
  const ModeColors({
    required this.recognition,
    required this.production,
    required this.listening,
    required this.grammar,
    required this.pair,
  });

  static const ModeColors light = ModeColors(
    recognition: ModeColor(Color(0xFFD6E3FF), Color(0xFF001B3E)),
    production: ModeColor(Color(0xFFFFDCC2), Color(0xFF2E1500)),
    listening: ModeColor(Color(0xFFEADDFF), Color(0xFF21005D)),
    grammar: ModeColor(Color(0xFFB8F0E4), Color(0xFF00201B)),
    pair: ModeColor(Color(0xFFFFD8EC), Color(0xFF3A0028)),
  );

  static const ModeColors dark = ModeColors(
    recognition: ModeColor(Color(0xFF284777), Color(0xFFD6E3FF)),
    production: ModeColor(Color(0xFF6E3900), Color(0xFFFFDCC2)),
    listening: ModeColor(Color(0xFF4F378B), Color(0xFFEADDFF)),
    grammar: ModeColor(Color(0xFF00504A), Color(0xFFB8F0E4)),
    pair: ModeColor(Color(0xFF7A2963), Color(0xFFFFD8EC)),
  );

  final ModeColor recognition;
  final ModeColor production;
  final ModeColor listening;
  final ModeColor grammar;
  final ModeColor pair;

  /// The colours for [skill].
  ModeColor forSkill(Skill skill) => switch (skill) {
    Skill.recognition => recognition,
    Skill.production => production,
    Skill.listening => listening,
    Skill.grammar => grammar,
    Skill.pair => pair,
  };

  /// The theme's mode colours, or the light set if a theme has none.
  static ModeColors of(BuildContext context) =>
      Theme.of(context).extension<ModeColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  ModeColors copyWith({
    ModeColor? recognition,
    ModeColor? production,
    ModeColor? listening,
    ModeColor? grammar,
    ModeColor? pair,
  }) => ModeColors(
    recognition: recognition ?? this.recognition,
    production: production ?? this.production,
    listening: listening ?? this.listening,
    grammar: grammar ?? this.grammar,
    pair: pair ?? this.pair,
  );

  @override
  ModeColors lerp(ModeColors? other, double t) {
    if (other == null) return this;
    return ModeColors(
      recognition: ModeColor.lerp(recognition, other.recognition, t),
      production: ModeColor.lerp(production, other.production, t),
      listening: ModeColor.lerp(listening, other.listening, t),
      grammar: ModeColor.lerp(grammar, other.grammar, t),
      pair: ModeColor.lerp(pair, other.pair, t),
    );
  }
}
