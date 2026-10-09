// Scratch: renders gallery entries to PNGs for a visual check. Not committed.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/features/gallery/gallery_page.dart';

import 'support/harness.dart';

const out = String.fromEnvironment('SHOTS', defaultValue: '/tmp/shots');
const ids = String.fromEnvironment('IDS', defaultValue: 'decks');
const scroll = int.fromEnvironment('SCROLL', defaultValue: 0);

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  testWidgets('shots', (tester) async {
    const fonts =
        '/tmp/claude-0/-home-user-fluenough/1d4a8948-fad4-57d2-8d2c-45dc32323311/scratchpad/flutter/bin/cache/artifacts/material_fonts';
    await tester.runAsync(() async {
      await loadFont('Roboto', [
        '$fonts/Roboto-Regular.ttf',
        '$fonts/Roboto-Medium.ttf',
        '$fonts/Roboto-Bold.ttf',
        '$fonts/Roboto-Black.ttf',
      ]);
      await loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    });
    usePhone(tester);
    final app = AppState.test();
    await app.load();
    Directory(out).createSync(recursive: true);
    for (final spec in ids.split(',')) {
      final dark = spec.endsWith(':dark');
      final id = spec.replaceAll(':dark', '');
      final entry = allGalleryEntries.firstWhere((e) => e.id == id);
      final key = GlobalKey();
      await pumpScreen(
        tester,
        RepaintBoundary(
          key: key,
          child: GalleryPreview(key: UniqueKey(), entry: entry, dark: dark),
        ),
        state: app,
      );
      await tester.pumpAndSettle();
      if (scroll != 0) {
        final list = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        await tester.drag(list.first, Offset(0, -scroll.toDouble()));
        await tester.pumpAndSettle();
      }
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/$id${dark ? '-dark' : ''}${scroll != 0 ? '-s$scroll' : ''}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
