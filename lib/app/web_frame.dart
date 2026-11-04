import 'package:flutter/material.dart';

import 'web_safe_insets.dart';

/// The widest the web build draws the app: a large phone's width.
const double webFrameMaxWidth = 430;

/// [MaterialApp.builder] for the web build: the app keeps a phone's shape in
/// a wide window, centred on the theme's background, rather than spreading
/// over the whole screen. Its width is the window's, up to 9:16 of the
/// window's height and [webFrameMaxWidth]; its height is the window's. The
/// screens under it read that size, not the window's, and the window's
/// safe-area insets (the notch, the home bar) as their padding.
Widget webPhoneFrame(BuildContext context, Widget? child) =>
    webPhoneFrameWith(context, child, webSafeInsets());

/// [webPhoneFrame] with the window's safe-area [insets] given, so a test can
/// say where the notch is. Top and bottom always apply; left and right only
/// when the frame is as wide as the window, as a phone turned sideways is.
Widget webPhoneFrameWith(
  BuildContext context,
  Widget? child,
  EdgeInsets insets,
) {
  final background = Theme.of(context).colorScheme.surfaceContainerLowest;
  return ColoredBox(
    color: background,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = <double>[
          constraints.maxWidth,
          constraints.maxHeight * 9 / 16,
          webFrameMaxWidth,
        ].reduce((a, b) => a < b ? a : b);
        final size = Size(width, constraints.maxHeight);
        final full = width >= constraints.maxWidth;
        final safe = EdgeInsets.fromLTRB(
          full ? insets.left : 0,
          insets.top,
          full ? insets.right : 0,
          insets.bottom,
        );
        final media = MediaQuery.of(context);
        final padding = EdgeInsets.fromLTRB(
          _larger(media.padding.left, safe.left),
          _larger(media.padding.top, safe.top),
          _larger(media.padding.right, safe.right),
          _larger(media.padding.bottom, safe.bottom),
        );
        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: MediaQuery(
              data: media.copyWith(
                size: size,
                padding: padding,
                viewPadding: padding,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    ),
  );
}

double _larger(double a, double b) => a > b ? a : b;
