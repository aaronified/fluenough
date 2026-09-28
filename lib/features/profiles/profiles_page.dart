import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../app/profile.dart';
import '../../app/routes.dart';
import '../../app/shell_tab.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/profile_avatar.dart';
import 'profile_text.dart';

/// Who's practising: the profiles on this phone, and Add profile. Behind
/// `Feature.profiles`: its entry points (Today's avatar, Settings' Switch)
/// are disabled, so in this version it is reached only from the gallery.
///
/// Design screen `profiles`. A profile opens straight to the shell, or to its
/// PIN pad when it is locked and `Feature.pinLock` is on.
class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key});

  /// Opens [profile]: its PIN pad if it asks for one, otherwise selects it
  /// and goes to Today.
  static void open(BuildContext context, Profile profile) {
    final state = AppScope.read(context);
    if (opensWithPin(state, profile)) {
      AppNavigator.openPin(context, profile.id);
      return;
    }
    state.selectProfile(profile.id);
    AppNavigator.backToShell(context, tab: ShellTab.today);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 88, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: <Widget>[
                    Text(
                      l10n.appTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.profilesTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall!.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    _TwoColumns(
                      children: <Widget>[
                        for (final profile in state.profiles)
                          _ProfileTile(profile: profile),
                        const _AddProfileTile(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 48, 24, 32),
                child: Align(
                  alignment: AlignmentDirectional.bottomCenter,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.profilesPrivacy,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's two-column grid, as rows of two, so that a tile grows with
/// its text instead of being held to a grid's fixed aspect ratio.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < children.length; i += 2) ...<Widget>[
          if (i > 0) const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: children[i]),
              const SizedBox(width: 16),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One profile: its avatar, name, a lock when it asks for a PIN, and what it
/// learns. One button to a screen reader: "Aro, learning Spanish", then "PIN
/// locked" when it is.
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final name = profileName(l10n, profile);
    final languages = profileLanguages(l10n, state, profile);
    final locked = opensWithPin(state, profile);

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: l10n.profilesOpen(name, languages),
        child: InkWell(
          onTap: () => ProfilesPage.open(context, profile),
          borderRadius: BorderRadius.circular(AppRadii.group),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8,
              vertical: 16,
            ),
            child: Column(
              children: <Widget>[
                ProfileAvatar(profile: profile, size: 112),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: ExcludeSemantics(
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.sectionTitle,
                        ),
                      ),
                    ),
                    if (locked) ...<Widget>[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        semanticLabel: l10n.profilesLocked,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                ExcludeSemantics(
                  child: Text(
                    languages,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Add profile: a dashed circle with a person-plus, to the new-profile screen.
/// Incoming, with its badge under it, while `Feature.profiles` is off.
class _AddProfileTile extends StatelessWidget {
  const _AddProfileTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final incoming = isIncoming(context, Feature.profiles);

    final tile = InkWell(
      onTap: incoming ? null : () => AppNavigator.openNewProfile(context),
      borderRadius: BorderRadius.circular(AppRadii.group),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 16,
        ),
        child: Column(
          children: <Widget>[
            SizedBox.square(
              dimension: 112,
              child: Center(
                child: CustomPaint(
                  painter: _DashedCircle(scheme.outline),
                  child: SizedBox.square(
                    dimension: 108,
                    child: Icon(
                      Icons.person_add_alt,
                      size: 36,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.profilesAdd,
              textAlign: TextAlign.center,
              style: theme.textTheme.sectionTitle,
            ),
          ],
        ),
      ),
    );

    if (!incoming) {
      return MergeSemantics(child: Semantics(button: true, child: tile));
    }
    return Column(
      children: <Widget>[
        IncomingFeature(
          feature: Feature.profiles,
          label: l10n.profilesAdd,
          badge: IncomingBadgePlacement.none,
          child: tile,
        ),
        const ExcludeSemantics(child: IncomingBadge()),
      ],
    );
  }
}

/// The design's 2 px dashed ring around Add profile.
class _DashedCircle extends CustomPainter {
  const _DashedCircle(this.color);

  final Color color;

  static const int _dashes = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - 2) / 2,
    );
    const sweep = 2 * math.pi / _dashes;
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep / 2, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle oldDelegate) => oldDelegate.color != color;
}
