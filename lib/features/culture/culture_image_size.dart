import 'dart:math';

import 'package:flutter/widgets.dart';

/// The widest a culture picture is decoded in a list, a thumbnail or a card:
/// 1024 px, so one decoded picture takes about 4 MB for a 4:3 picture whatever
/// the file's size; a tall one decodes more rows (a 1024 x 2048 picture, 8 MB
/// at the cap) and is still bounded. The size passed is the width only, and
/// `Image` never upscales it (wiki/Plan-Culture-Media.md, work package 4a,
/// ADR-0060).
const int cultureDecodeCap = 1024;

/// The widest any culture picture is ever decoded, in a full-screen viewer:
/// the file's own cap, 2048 px.
const int cultureViewerCap = 2048;

/// How much wider than the box a picture is decoded: a landscape picture
/// that covers a square box is cut at the sides, and needs its height to
/// fill the box, which a width of exactly the box's would leave short.
const double cultureDecodeHeadroom = 1.5;

/// The `cacheWidth` for a culture picture drawn [logical] logical pixels
/// wide at [pixelRatio]: the box in physical pixels with
/// [cultureDecodeHeadroom], at least 1 and at most [cap].
int cultureDecodeWidth(
  double logical,
  double pixelRatio, {
  int cap = cultureDecodeCap,
}) => max(1, min(cap, (logical * pixelRatio * cultureDecodeHeadroom).ceil()));

/// [cultureDecodeWidth] at [context]'s pixel ratio.
int cultureDecodeWidthIn(BuildContext context, double logical) =>
    cultureDecodeWidth(logical, MediaQuery.devicePixelRatioOf(context));

/// The `cacheWidth` for a full-screen viewer: the whole screen's width in
/// physical pixels, never above [cultureViewerCap].
int cultureViewerDecodeWidth(BuildContext context) {
  final view = MediaQuery.sizeOf(context);
  final ratio = MediaQuery.devicePixelRatioOf(context);
  return max(
    1,
    min(cultureViewerCap, (max(view.width, view.height) * ratio).ceil()),
  );
}
