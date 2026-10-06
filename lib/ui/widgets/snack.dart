import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';

/// Shows [message] as the app's toast, replacing any already showing.
///
/// It sits at the top, just under where an app bar ends, not at the bottom
/// as a SnackBar does: there it covered the buttons a learner presses next.
/// Taps go through it to whatever is under it, so it never stands in the way
/// of a button. It goes after [AppToast.showFor]. Screen readers announce
/// it.
void showAppSnackBar(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  hideAppSnackBar();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AppToast(
      message: message,
      onGone: () {
        if (identical(_toast, entry)) hideAppSnackBar();
      },
    ),
  );
  _toast = entry;
  _toastOverlay = overlay;
  overlay.insert(entry);
}

/// Hides the toast showing, if any, at once.
void hideAppSnackBar() {
  final entry = _toast;
  final overlay = _toastOverlay;
  _toast = null;
  _toastOverlay = null;
  // Only while its overlay is still there: a test's tree may be gone.
  if (entry != null && overlay != null && overlay.mounted) {
    entry
      ..remove()
      ..dispose();
  }
}

OverlayEntry? _toast;
OverlayState? _toastOverlay;

/// One toast: the theme's SnackBar colours, shape and text, at the top.
class AppToast extends StatefulWidget {
  const AppToast({super.key, required this.message, required this.onGone});

  /// How long a toast stays, as long as a SnackBar did.
  static const Duration showFor = Duration(seconds: 4);

  final String message;

  /// Called once it has slid away, to take it off the screen.
  final VoidCallback onGone;

  @override
  State<AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();
  late final Timer _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(AppToast.showFor, _leave);
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    _timer.cancel();
    _motion.reverse().whenComplete(widget.onGone);
  }

  @override
  void dispose() {
    _timer.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snack = theme.snackBarTheme;
    final scheme = theme.colorScheme;
    final fade = CurvedAnimation(parent: _motion, curve: Curves.easeOut);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.5),
                end: Offset.zero,
              ).animate(fade),
              child: Semantics(
                container: true,
                liveRegion: true,
                // Taps reach what is under it: a toast is something to read,
                // never something in the way.
                child: IgnorePointer(
                  child: Material(
                    color: snack.backgroundColor ?? scheme.inverseSurface,
                    shape: snack.shape,
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Text(
                        widget.message,
                        style:
                            snack.contentTextStyle ??
                            theme.textTheme.bodyMedium!.copyWith(
                              color: scheme.onInverseSurface,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [url] in the browser, or the app that handles it, through
/// `AppState.links`. When nothing can open it, copies it instead and says
/// [copied] in a toast, so that it can be pasted into a browser.
Future<void> openLink(
  BuildContext context,
  String url, {
  required String copied,
}) async {
  final opened = await AppScope.read(context).links.open(url);
  if (!opened && context.mounted) {
    await copyToClipboard(context, url, confirmation: copied);
  }
}

/// Copies [text] and says [confirmation] in a toast.
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  required String confirmation,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showAppSnackBar(context, confirmation);
}
