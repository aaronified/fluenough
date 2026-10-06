import 'package:flutter/material.dart';

import '../../core/updates/markdown_subset.dart';
import '../../ui/theme.dart';

/// [blocks], as `parseMarkdownSubset` read them, on screen: headings by
/// level, bullets with a dot, paragraphs, and bold runs. It sets no colours
/// beyond the surrounding text's, so it follows the theme.
///
/// A heading is a screen-reader heading. A bullet's dot is not read out, so
/// each line is heard as the text it is.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.blocks});

  final List<MdBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final body = text.bodyMedium!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsetsDirectional.only(
              top: i == 0
                  ? 0
                  : blocks[i].kind == MdKind.heading
                  ? 14
                  : 4,
            ),
            child: switch (blocks[i]) {
              MdBlock(kind: MdKind.heading, :final level) => Semantics(
                header: true,
                child: _runs(blocks[i], switch (level) {
                  1 => text.sectionTitle,
                  2 => text.titleMedium!,
                  _ => text.titleSmall!,
                }),
              ),
              MdBlock(kind: MdKind.bullet) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 18,
                    child: ExcludeSemantics(
                      child: Text(
                        '•', // ui-literal-ok: a bullet is not language
                        style: body,
                      ),
                    ),
                  ),
                  Expanded(child: _runs(blocks[i], body)),
                ],
              ),
              _ => _runs(blocks[i], body),
            },
          ),
      ],
    );
  }

  /// [block]'s runs in [style], the bold ones heavier.
  static Widget _runs(MdBlock block, TextStyle style) => Text.rich(
    TextSpan(
      children: <InlineSpan>[
        for (final span in block.spans)
          TextSpan(
            text: span.text,
            style: span.bold
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
      ],
    ),
    style: style,
  );
}
