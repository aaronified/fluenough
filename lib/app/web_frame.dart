import 'package:flutter/material.dart';

/// The widest the web build draws the app: a large phone's width.
const double webFrameMaxWidth = 430;

/// [MaterialApp.builder] for the web build: the app keeps a phone's shape in
/// a wide window, centred on the theme's background, rather than spreading
/// over the whole screen. Its width is the window's, up to 9:16 of the
/// window's height and [webFrameMaxWidth]; its height is the window's. The
/// screens under it read that size, not the window's.
Widget webPhoneFrame(BuildContext context, Widget? child) {
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
        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: size),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    ),
  );
}
