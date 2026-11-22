import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/models/creator.dart' show CreatorImage;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/snack.dart';
import 'culture_image_size.dart';

/// The credit line under a picture: who made it and on what licence, such as
/// `Image: Unknown author · public domain`. Null when [image] is null or
/// names neither (approved mockup `culture-media`: no picture, no caption and
/// no apology).
String? cultureImageCredit(AppLocalizations l10n, CreatorImage? image) {
  if (image == null) return null;
  final licence = image.licence == 'public-domain'
      ? l10n.cultureImagePublicDomain
      : image.licence;
  final parts = <String>[
    ?image.credit,
    if (image.author != null && image.author != image.credit) image.author!,
    ?licence,
  ];
  return parts.isEmpty ? null : l10n.cultureImageCredit(parts.join(' · '));
}

/// Where a picture's "Licence and source" link goes: the licence page, else
/// the file's page on Wikimedia Commons; null when the credit names neither.
String? cultureImageLink(CreatorImage? image) =>
    image?.licenceUrl ?? image?.sourceUrl;

/// Fetches the picture of [image] when it is first shown, if the language's
/// "Show pictures" switch is on, and hands [builder] its bytes: null while it
/// comes, when it cannot be had (offline, not listed) and when the switch is
/// off, so that the caller draws the same placeholder icon for each, with no
/// spinner and no error (wiki/Plan-Culture-Media.md, section 5). Nothing is
/// fetched with the switch off.
class CulturePictureLoader extends StatefulWidget {
  const CulturePictureLoader({
    super.key,
    required this.image,
    required this.language,
    required this.builder,
  });

  final CreatorImage? image;

  /// The language whose "Show pictures" switch decides.
  final String language;

  final Widget Function(BuildContext context, Uint8List? bytes) builder;

  @override
  State<CulturePictureLoader> createState() => _CulturePictureLoaderState();
}

class _CulturePictureLoaderState extends State<CulturePictureLoader> {
  Future<Uint8List?>? _future;
  String? _loaded;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) {
        final path = widget.image?.file;
        final on = state.settings.cultureFor(widget.language).pictures;
        if (path == null || !on) {
          _future = null;
          _loaded = null;
          return widget.builder(context, null);
        }
        if (path != _loaded || _future == null) {
          _loaded = path;
          _future = state.deckDownloads?.creatorImage(path);
        }
        final future = _future;
        if (future == null) return widget.builder(context, null);
        return FutureBuilder<Uint8List?>(
          future: future,
          builder: (context, snapshot) =>
              widget.builder(context, snapshot.data),
        );
      },
    );
  }
}

/// [bytes] cropped to fill a [width] by [height] box, decoded at the size it
/// is shown and never at the file's (wiki/Plan-Culture-Media.md, work package
/// 4a); [placeholder] when the bytes cannot be drawn.
class CultureImageView extends StatelessWidget {
  const CultureImageView({
    super.key,
    required this.bytes,
    required this.width,
    required this.height,
    this.label,
    required this.placeholder,
  });

  final Uint8List bytes;
  final double width;
  final double height;
  final String? label;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) => Image.memory(
    bytes,
    width: width,
    height: height,
    cacheWidth: cultureDecodeWidthIn(context, width),
    fit: BoxFit.cover,
    semanticLabel: label,
    errorBuilder: (context, error, stack) => placeholder,
  );
}

/// The small round badge on a picture that opens full screen: a magnifier,
/// icon only, whatever the picture under it.
class ZoomBadge extends StatelessWidget {
  const ZoomBadge({super.key, this.size = 32, this.inset = 8});

  final double size;
  final double inset;

  @override
  Widget build(BuildContext context) => PositionedDirectional(
    end: inset,
    bottom: inset,
    child: ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0x9E000000),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.zoom_in, size: size * 0.62, color: Colors.white),
      ),
    ),
  );
}

/// A picture that opens the full-screen viewer when tapped, with the zoom
/// badge on it. [child] is the picture drawn at its size.
class ZoomablePicture extends StatelessWidget {
  const ZoomablePicture({
    super.key,
    required this.bytes,
    required this.image,
    required this.label,
    required this.child,
    this.badge = 32,
    this.badgeInset = 8,
  });

  final Uint8List bytes;
  final CreatorImage? image;
  final String label;
  final Widget child;
  final double badge;
  final double badgeInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: label,
      hint: l10n.cultureImageOpen,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey<String>('culture-picture-open'),
        onTap: () => showPictureViewer(
          context,
          bytes: bytes,
          image: image,
          label: label,
        ),
        child: Stack(
          children: <Widget>[
            child,
            ZoomBadge(size: badge, inset: badgeInset),
          ],
        ),
      ),
    );
  }
}

/// Opens [bytes] full screen: black in both themes, pinch to zoom, a close
/// button at the top and, when [image] has a credit, the same credit and
/// "Licence and source" link at the bottom. The picture is decoded at full
/// size here and nowhere else.
Future<void> showPictureViewer(
  BuildContext context, {
  required Uint8List bytes,
  required CreatorImage? image,
  required String label,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (context) =>
        PictureViewer(bytes: bytes, image: image, label: label),
  ),
);

/// The full-screen viewer ([showPictureViewer]).
class PictureViewer extends StatelessWidget {
  const PictureViewer({
    super.key,
    required this.bytes,
    required this.image,
    required this.label,
  });

  final Uint8List bytes;
  final CreatorImage? image;
  final String label;

  /// The caption and the link sit on a picture of any colour, over a dark
  /// gradient: these two are checked against a white picture (9.4:1, 8.2:1).
  static const Color captionColor = Color(0xFFE6E6E6);
  static const Color linkColor = Color(0xFFA9E5BF);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final credit = cultureImageCredit(l10n, image);
    final link = cultureImageLink(image);
    final linkStyle = AppButtonStyles.inline(context).copyWith(
      foregroundColor: const WidgetStatePropertyAll<Color>(linkColor),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          InteractiveViewer(
            maxScale: 6,
            child: Center(
              child: Image.memory(
                bytes,
                cacheWidth: cultureViewerDecodeWidth(context),
                fit: BoxFit.contain,
                semanticLabel: label,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            start: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  tooltip: l10n.commonClose,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0x73000000),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
          if (credit != null || link != null)
            Positioned.fill(
              top: null,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x00000000), Color(0xCC000000)],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      24,
                      16,
                      8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (credit != null)
                          Text(
                            credit,
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: captionColor,
                            ),
                          ),
                        if (link != null)
                          TextButton.icon(
                            style: linkStyle,
                            onPressed: () => openLink(
                              context,
                              link,
                              copied: l10n.cultureLinkCopied,
                            ),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(l10n.cultureImageLicenceLink),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
