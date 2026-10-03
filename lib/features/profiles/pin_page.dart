import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../app/shell_tab.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/profile_avatar.dart';
import '../../ui/widgets/report_button.dart';
import 'profile_text.dart';

/// A profile's PIN pad, with the wrong-PIN state and Forgot PIN?. Checks
/// with `AppState.checkPin`. Behind `Feature.pinLock`: the profiles screen
/// comes here only for a locked profile while that feature is on.
///
/// Design screens `pin` and `pin-error`. The fourth digit checks the PIN: a
/// right one selects the profile and goes to Today, a wrong one says so and
/// clears the dots.
class PinPage extends StatefulWidget {
  const PinPage({super.key, required this.profileId, this.wrongPin = false});

  /// The profile being opened.
  final String profileId;

  /// Starts as if a wrong PIN had just been entered: the gallery's
  /// `pin-error`.
  final bool wrongPin;

  /// How many digits a PIN has.
  static const int length = 4;

  @override
  State<PinPage> createState() => _PinPageState();
}

class _PinPageState extends State<PinPage> {
  String _entered = '';
  late bool _wrong = widget.wrongPin;

  void _digit(String digit) {
    if (_entered.length >= PinPage.length) return;
    final next = _entered + digit;
    if (next.length < PinPage.length) {
      setState(() {
        _entered = next;
        _wrong = false;
      });
      return;
    }
    final state = AppScope.read(context);
    final right = state.checkPin(widget.profileId, next);
    setState(() {
      _entered = '';
      _wrong = !right;
    });
    if (!right) return;
    state.selectProfile(widget.profileId);
    AppNavigator.backToShell(context, tab: ShellTab.today);
  }

  void _delete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _forgot() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pinForgot),
        content: Text(l10n.pinForgotBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonGotIt),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = AppScope.of(context).profileById(widget.profileId);
    final name = profile == null
        ? l10n.commonUnnamedProfile
        : profileName(l10n, profile);
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const BackButtonIcon(),
                tooltip: l10n.pinBackToProfiles,
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: const <Widget>[ReportButton()],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: <Widget>[
                    if (profile != null)
                      ProfileAvatar(profile: profile, size: 80),
                    const SizedBox(height: 20),
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.pinGreeting(name),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _wrong ? l10n.pinWrong : l10n.pinPrompt(PinPage.length),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: _wrong
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PinDots(
                      entered: _entered.length,
                      length: PinPage.length,
                      wrong: _wrong,
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 40,
                    ),
                    child: PinKeypad(onDigit: _digit, onDelete: _delete),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      24,
                      16,
                      24,
                      24,
                    ),
                    child: TextButton(
                      onPressed: _forgot,
                      child: Text(l10n.pinForgot),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How many digits are in, as four dots: filled in `primary`, or ringed in
/// `error` after a wrong PIN. Colour is never the only signal: screen readers
/// hear "2 of 4 digits entered", and the prompt above says when it was
/// wrong.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.entered,
    required this.length,
    this.wrong = false,
  });

  final int entered;
  final int length;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: l10n.pinEntered(entered, length),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 20, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 20),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < entered
                      ? (wrong ? scheme.error : scheme.primary)
                      : Colors.transparent,
                  border: Border.all(
                    width: 2,
                    color: wrong
                        ? scheme.error
                        : i < entered
                        ? scheme.primary
                        : scheme.outline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The numeric keypad: 1–9, then a blank, 0 and backspace. Every key is a
/// real button, 72 px tall and at least 48 wide.
class PinKeypad extends StatelessWidget {
  const PinKeypad({super.key, required this.onDigit, required this.onDelete});

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  /// The keys, row by row: null is the blank, and `''` the backspace.
  static const List<String?> _keys = <String?>[
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    null,
    '0',
    '',
  ];

  static const double _keyHeight = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget key(String? k) {
      if (k == null) return const SizedBox.shrink();
      if (k.isEmpty) {
        return Center(
          child: IconButton(
            onPressed: onDelete,
            tooltip: l10n.pinDeleteDigit,
            iconSize: 28,
            color: scheme.onSurface,
            style: IconButton.styleFrom(
              minimumSize: const Size(_keyHeight, _keyHeight),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.backspace_outlined),
          ),
        );
      }
      return TextButton(
        onPressed: () => onDigit(k),
        style: TextButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(AppSizes.iconButton, _keyHeight),
          padding: EdgeInsets.zero,
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.headlineMedium!.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(k),
      );
    }

    return Column(
      children: <Widget>[
        for (var row = 0; row < _keys.length ~/ 3; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: 12),
          Row(
            children: <Widget>[
              for (var col = 0; col < 3; col++) ...<Widget>[
                if (col > 0) const SizedBox(width: 24),
                Expanded(child: key(_keys[row * 3 + col])),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
