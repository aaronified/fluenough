import 'package:flutter/widgets.dart';

/// One row of pills or keys that scrolls sideways and fades out at both
/// edges: the app's one arrangement for such a row (owner, 2026-11-06: "all
/// such pills will be scrollable and edgemasked"). The row runs the width it
/// is given, and [padding] says where its first item starts, so a row in a
/// list that already pads its sides is placed with that list's padding set
/// to none and a 16 dp start here.
///
/// The children must not be [Flexible]: the row is as wide as they are.
class FadedScrollRow extends StatelessWidget {
  const FadedScrollRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 16),
    this.gap = 0,
  });

  final List<Widget> children;

  /// Around the items, inside the scroll: the start the first item has.
  final EdgeInsetsGeometry padding;

  /// Between two items.
  final double gap;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => const LinearGradient(
      colors: <Color>[
        Color(0x00000000),
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0x00000000),
      ],
      stops: <double>[0, 0.04, 0.96, 1],
    ).createShader(rect),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: <Widget>[
          for (final (i, child) in children.indexed) ...<Widget>[
            if (i > 0 && gap > 0) SizedBox(width: gap),
            child,
          ],
        ],
      ),
    ),
  );
}
