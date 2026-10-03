import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Holds the whole app, so that a report can take a picture of the screen it
/// was raised on (ADR-0021). Put around the navigator by `MaterialApp`'s
/// `builder`: [ReportCapture.wrap].
class ReportCapture extends StatefulWidget {
  const ReportCapture({super.key, required this.child});

  final Widget child;

  /// For `MaterialApp.builder`.
  static Widget wrap(BuildContext context, Widget? child) =>
      ReportCapture(child: child ?? const SizedBox.shrink());

  /// The screen as it is now, as PNG, or null where nothing holds the app,
  /// or the picture could not be taken.
  static Future<Uint8List?> capture(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_ReportCaptureScope>();
    if (scope == null) return Future<Uint8List?>.value();
    return scope.state._capture(View.of(context).devicePixelRatio);
  }

  @override
  State<ReportCapture> createState() => _ReportCaptureState();
}

class _ReportCaptureState extends State<ReportCapture> {
  final GlobalKey _boundary = GlobalKey();

  /// Taken at no more than twice the screen's size in logical pixels: sharp
  /// enough to read, and a few hundred kilobytes rather than megabytes.
  Future<Uint8List?> _capture(double devicePixelRatio) async {
    final boundary = _boundary.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    try {
      final image = await boundary.toImage(
        pixelRatio: math.min(devicePixelRatio, 2),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => _ReportCaptureScope(
    state: this,
    child: RepaintBoundary(key: _boundary, child: widget.child),
  );
}

class _ReportCaptureScope extends InheritedWidget {
  const _ReportCaptureScope({required this.state, required super.child});

  final _ReportCaptureState state;

  @override
  bool updateShouldNotify(_ReportCaptureScope old) => state != old.state;
}
